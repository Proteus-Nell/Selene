// The lock gate and its settings toggle (AND-29).
//
// Two claims are load-bearing here and both are asserted rather than reviewed:
//
//   * the lock is OFF by default, so no existing user meets a lock screen they
//     did not ask for after updating;
//   * it says, on the screen and in PRIVACY.md, that it only hides the screen
//     and does not itself encrypt anything. The database is encrypted either
//     way (ADR-0018), and a lock a user mistakes for that encryption is worse
//     than no lock — it buys a false sense of safety for the price of a few
//     taps.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/security/app_lock.dart';
import 'package:period_tracker/security/lock_gate.dart';

import '../features/harness.dart';

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
  late AppDatabase db;
  late _FakeLock service;

  setUp(() {
    db = memoryDatabase();
    service = _FakeLock();
  });
  tearDown(() => db.close());

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        const LockGate(child: Scaffold(body: Text('diary'))),
        database: db,
        overrides: <Override>[
          appLockServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('with the lock off', () {
    testWidgets('the app is shown and nothing is asked for', (tester) async {
      // The default, and the reason every other test in this suite still
      // passes: an app whose lock is disabled must never flash a lock screen.
      await pumpGate(tester);
      expect(find.text('diary'), findsOneWidget);
      expect(service.prompts, 0);
    });
  });

  group('with the lock on', () {
    setUp(
      () => db.settingsDao.writeBool(SettingKey.appLockEnabled, value: true),
    );

    testWidgets('the diary is hidden until the credential is offered', (
      tester,
    ) async {
      service.outcome = UnlockOutcome.refused;
      await pumpGate(tester);

      expect(find.text('diary'), findsNothing);
      expect(find.text(l10nOf(tester).lockTitle), findsOneWidget);
    });

    testWidgets('the lock screen gives nothing away about the app', (
      tester,
    ) async {
      // This is what someone looking over a shoulder sees. A lock screen
      // reading "Period Tracker — unlock to see your cycle" would leak the one
      // fact the lock exists to keep.
      service.outcome = UnlockOutcome.refused;
      await pumpGate(tester);

      final l10n = l10nOf(tester);
      for (final leak in <String>['period', 'cycle', 'diary']) {
        expect(
          l10n.lockTitle.toLowerCase(),
          isNot(contains(leak)),
          reason: 'the lock screen title says "$leak"',
        );
      }
      expect(l10n.lockPromptReason.toLowerCase(), isNot(contains('period')));
    });

    testWidgets('a granted unlock reveals it', (tester) async {
      await pumpGate(tester);
      expect(find.text('diary'), findsOneWidget);
      expect(service.prompts, 1);
    });

    testWidgets('a refusal leaves a way to try again', (tester) async {
      // A dismissed system prompt leaves the app locked with nothing to tap,
      // which reads as a frozen app rather than a locked one.
      service.outcome = UnlockOutcome.refused;
      await pumpGate(tester);
      expect(find.text(l10nOf(tester).lockAction), findsOneWidget);

      service.outcome = UnlockOutcome.granted;
      await tester.tap(find.text(l10nOf(tester).lockAction));
      await tester.pumpAndSettle();
      expect(find.text('diary'), findsOneWidget);
    });
  });

  group('the settings toggle', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SettingsScreen(),
          database: db,
          overrides: <Override>[
            appLockServiceProvider.overrideWithValue(service),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is off to begin with', (tester) async {
      await pumpSettings(tester);
      final label = find.text(l10nOf(tester).settingsAppLock);
      await tester.scrollUntilVisible(label, 120);
      await tester.pumpAndSettle();

      final tile = find.ancestor(
        of: label,
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    });

    testWidgets('says it only hides the screen, on the screen', (
      tester,
    ) async {
      // Under the switch whether it is on or off, not behind a link. A lock
      // taken for the encryption would be trusted for something it does not
      // do, so the note says what it does and that the encryption is separate.
      await pumpSettings(tester);
      final note = find.text(l10nOf(tester).settingsAppLockNotEncrypted);
      await tester.scrollUntilVisible(note, 120);
      await tester.pumpAndSettle();
      expect(note, findsOneWidget);

      final copy = l10nOf(tester).settingsAppLockNotEncrypted.toLowerCase();
      expect(copy, contains('only hides the screen'));
      expect(copy, contains('whether the lock is on or off'));
    });

    testWidgets('turning it on writes the preference', (tester) async {
      await pumpSettings(tester);
      final label = find.text(l10nOf(tester).settingsAppLock);
      await tester.scrollUntilVisible(label, 120);
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(of: label, matching: find.byType(SwitchListTile)),
      );
      await tester.pumpAndSettle();

      expect(await db.settingsDao.readAppLockEnabled(), isTrue);
    });

    testWidgets('a device with no credential is told why, not shown a dead '
        'switch', (tester) async {
      // The lock delegates entirely to the device's own credential, so with
      // none enrolled there is nothing to ask for. The fix is in the system
      // settings, and a greyed-out toggle would leave the user concluding the
      // app is broken instead of going there.
      service.reason = LockUnavailableReason.noCredentialEnrolled;
      await pumpSettings(tester);

      final explanation = find.text(l10nOf(tester).settingsAppLockUnavailable);
      await tester.scrollUntilVisible(explanation, 120);
      await tester.pumpAndSettle();
      expect(explanation, findsOneWidget);

      // And there is no switch to tap at all, rather than one that fails.
      expect(
        find.ancestor(
          of: find.text(l10nOf(tester).settingsAppLock),
          matching: find.byType(SwitchListTile),
        ),
        findsNothing,
      );

      final copy = l10nOf(tester).settingsAppLockUnavailable.toLowerCase();
      expect(
        copy.contains('device settings') || copy.contains('screen lock'),
        isTrue,
        reason: 'the explanation does not name where the fix is',
      );
    });
  });

  group('PRIVACY.md', () {
    File privacyDoc() {
      var directory = Directory.current.absolute;
      for (var depth = 0; depth < 5; depth++) {
        final candidate = File('${directory.path}/docs/PRIVACY.md');
        if (candidate.existsSync()) return candidate;
        directory = directory.parent;
      }
      throw StateError('could not find docs/PRIVACY.md');
    }

    test('says the lock does not encrypt anything', () {
      // AND-29 requires this in these words. It is the claim a user is most
      // likely to get wrong on their own, and getting it wrong is the failure
      // mode that matters: they would rely on it against a threat it does not
      // address.
      final text = privacyDoc().readAsStringSync().toLowerCase();
      expect(
        text,
        contains('does not encrypt'),
        reason: 'PRIVACY.md no longer says the app lock does not encrypt',
      );
      expect(
        text,
        contains('app lock'),
        reason: 'PRIVACY.md does not mention the app lock at all',
      );
    });

    test('lists the biometric permission', () {
      // The permission list is what a careful user reads before installing.
      // A new permission missing from it is the app being quietly less honest
      // than it was — the same defect a review caught on this file at AND-19.
      final text = privacyDoc().readAsStringSync();
      expect(
        text,
        contains('USE_BIOMETRIC'),
        reason:
            'local_auth adds USE_BIOMETRIC to the merged manifest and '
            'PRIVACY.md does not mention it',
      );
    });
  });
}
