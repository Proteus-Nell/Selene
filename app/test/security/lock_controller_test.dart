// When the app locks, and — more importantly — when it does not (AND-29).
//
// Most of these tests are about staying unlocked. A lock that re-prompts every
// time Android sends a lifecycle event would fire on a notification shade pull,
// an incoming call banner, an app-switcher glance and the system file picker
// used by export — which would lock the app in the middle of taking a backup.
// A lock people turn off protects nobody, so the cases that must *not* lock are
// the ones that decide whether the feature survives contact with a real phone.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/security/app_lock.dart';
import 'package:period_tracker/security/lock_controller.dart';

/// A clock the test moves by hand.
final class _MovableClock implements Clock {
  _MovableClock(this._instant);

  DateTime _instant;

  void advance(Duration by) => _instant = _instant.add(by);

  @override
  CivilDate today() => CivilDate.fromDateTime(_instant);

  @override
  DateTime nowUtc() => _instant;
}

/// A device that answers however the test needs it to.
final class _FakeLock implements AppLockService {
  // Both fields are set after construction rather than through the
  // constructor: a test reads better as "granted by default, and this one
  // refuses" than as a parameter list at every call site.
  UnlockOutcome outcome = UnlockOutcome.granted;
  LockUnavailableReason? reason;
  int prompts = 0;

  @override
  Future<LockUnavailableReason?> unavailableReason() async => reason;

  @override
  Future<UnlockOutcome> unlock(String reason) async {
    prompts++;
    return outcome;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MovableClock clock;
  late _FakeLock service;

  setUp(() {
    clock = _MovableClock(DateTime.utc(2026, 6, 30, 12));
    service = _FakeLock();
  });

  LockController controllerWith({required bool enabled}) {
    final controller = LockController(
      service: service,
      clock: clock,
      isEnabled: () async => enabled,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('when the lock is off', () {
    test('the app opens without a prompt', () async {
      // The default. An app whose lock is disabled must not flash a lock
      // screen, and must not ask the platform for anything.
      final controller = controllerWith(enabled: false);
      await controller.start();

      expect(controller.isOpen, isTrue);
      expect(service.prompts, 0);
    });

    test('backgrounding it for an hour changes nothing', () async {
      final controller = controllerWith(enabled: false);
      await controller.start();

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(hours: 1));
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isOpen, isTrue);
      expect(service.prompts, 0);
    });
  });

  group('on a cold start with the lock on', () {
    test('it asks, and opens when the user proves who they are', () async {
      final controller = controllerWith(enabled: true);
      await controller.start();

      expect(service.prompts, 1);
      expect(controller.isOpen, isTrue);
    });

    test('it stays shut when the user does not', () async {
      service.outcome = UnlockOutcome.refused;
      final controller = controllerWith(enabled: true);
      await controller.start();

      expect(controller.state, AppLockState.locked);
      expect(controller.isOpen, isFalse);
    });

    test('a refusal can be retried', () async {
      service.outcome = UnlockOutcome.refused;
      final controller = controllerWith(enabled: true);
      await controller.start();
      expect(controller.isOpen, isFalse);

      service.outcome = UnlockOutcome.granted;
      await controller.unlock();
      expect(controller.isOpen, isTrue);
    });

    test('two overlapping unlock calls only prompt once', () async {
      // Two BiometricPrompts at once is a platform error on Android, and both
      // paths that race here are ordinary: a lifecycle event arriving while a
      // prompt is open, and the user tapping Unlock again.
      final controller = controllerWith(enabled: true);
      final first = controller.unlock();
      final second = controller.unlock();
      await Future.wait(<Future<void>>[first, second]);

      expect(service.prompts, 1);
    });
  });

  group('when the device credential has been removed', () {
    test('the user is let in rather than sealed out', () async {
      // The alternative is a diary nobody can open, with the data still sitting
      // unencrypted on disk — the lock would have cost them everything and
      // protected nothing.
      service.outcome = UnlockOutcome.unavailable;
      final controller = controllerWith(enabled: true);
      await controller.start();

      expect(controller.isOpen, isTrue);
    });
  });

  group('coming back from the background', () {
    Future<LockController> unlockedController() async {
      final controller = controllerWith(enabled: true);
      await controller.start();
      expect(controller.isOpen, isTrue);
      return controller;
    }

    Future<void> backgroundFor(
      LockController controller,
      Duration duration, {
      AppLifecycleState leaving = AppLifecycleState.paused,
    }) async {
      controller.didChangeAppLifecycleState(leaving);
      clock.advance(duration);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    }

    test('a glance at another app does not lock it', () async {
      // Checking a message, copying a code, picking a folder in the system
      // file picker. Locking here is what makes people turn the feature off.
      final controller = await unlockedController();
      await backgroundFor(controller, const Duration(seconds: 30));

      expect(controller.isOpen, isTrue);
      expect(service.prompts, 1, reason: 'it re-prompted inside the grace');
    });

    test('a minute away does lock it', () async {
      final controller = await unlockedController();
      await backgroundFor(
        controller,
        LockController.backgroundGrace + const Duration(seconds: 1),
      );

      expect(service.prompts, 2);
    });

    test('the boundary itself locks', () async {
      // Pinned on the boundary rather than either side of it. "Unlock again
      // after 60 seconds" leaves exactly 60 ambiguous, and the ambiguity is
      // resolved towards locking: for a privacy feature the conservative
      // reading is the right one, and a second either way is not something a
      // user will notice. What they would notice is a flaky boundary, so it is
      // decided here rather than left to whoever reads the comparison next.
      final controller = await unlockedController();
      await backgroundFor(controller, LockController.backgroundGrace);

      expect(service.prompts, 2);
    });

    test('a second under the boundary does not', () async {
      final controller = await unlockedController();
      await backgroundFor(
        controller,
        LockController.backgroundGrace - const Duration(seconds: 1),
      );

      expect(service.prompts, 1);
    });

    test('and it stays shut if the unlock is refused', () async {
      final controller = await unlockedController();
      service.outcome = UnlockOutcome.refused;
      await backgroundFor(
        controller,
        LockController.backgroundGrace + const Duration(seconds: 1),
      );

      expect(controller.isOpen, isFalse);
    });

    test('an inactive event alone never locks it', () async {
      // inactive arrives for a notification shade pull, an incoming call
      // banner and the app switcher preview. None of those mean the phone left
      // the user's hand, and none of them are followed by a resume that should
      // cost a prompt.
      final controller = await unlockedController();
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      clock.advance(const Duration(hours: 2));
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isOpen, isTrue);
      expect(service.prompts, 1);
    });

    test('the clock starts at the first pause, not the last', () async {
      // paused, hidden and detached can all arrive for one backgrounding.
      // Resetting the timestamp on each would restart the grace period every
      // time the platform said something, and the app would never lock.
      final controller = await unlockedController();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(seconds: 40));
      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      clock.advance(const Duration(seconds: 40));
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(
        service.prompts,
        2,
        reason: 'the grace period restarted on the second lifecycle event',
      );
    });

    test('a resume with no preceding pause is ignored', () async {
      final controller = await unlockedController();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(service.prompts, 1);
    });
  });

  group('turning the lock on from settings', () {
    test('locks immediately rather than at the next launch', () async {
      // So the user sees what they just switched on, and can check it works
      // while they are still holding the phone.
      final controller = controllerWith(enabled: false);
      await controller.start();
      expect(controller.isOpen, isTrue);

      controller.lock();
      expect(controller.isOpen, isFalse);
    });
  });
}
