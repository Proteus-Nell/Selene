// Nothing the companion says survives the lock (AND-37, AND-29).
//
// The companion is the one thing in this app that is on every screen and that
// speaks in sentences, which makes it the obvious way for the lock to spring a
// leak. Three things are asserted rather than reviewed:
//
//   * with the lock on and the credential refused, the companion is not in the
//     tree at all — not the control, not the drawing, and none of the thirteen
//     sentences;
//   * a suggestion already open is torn down when the app locks again, because
//     it is a route under the gate rather than an overlay beside it;
//   * unlocked, it still says nothing until it is asked. A line about somebody's
//     cramps painted permanently into the bottom bar would be readable over
//     their shoulder without anyone touching the phone, which is the situation
//     the lock exists for and which the lock would not help with.
//
// This file adds to `lock_gate_test.dart` and `discreet_title_test.dart`. It
// does not replace or relax anything in either.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/companion/companion_dock.dart';
import 'package:period_tracker/features/companion/companion_providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/security/app_lock.dart';
import 'package:period_tracker/security/lock_gate.dart';

import '../features/companion_lines_test.dart' show everythingItCanSay;
import '../features/harness.dart';

final class _FakeLock implements AppLockService {
  UnlockOutcome outcome = UnlockOutcome.granted;

  @override
  Future<LockUnavailableReason?> unavailableReason() async => null;

  @override
  Future<UnlockOutcome> unlock(String reason) async => outcome;
}

/// The bar the companion lives in, with something behind it to hide.
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: const Text('diary'),
    bottomNavigationBar: CompanionDock(
      navigationBar: NavigationBar(
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: AppLocalizations.of(context).navLog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: AppLocalizations.of(context).navSettings,
          ),
        ],
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _FakeLock service;
  late WidgetRef ref;

  setUp(() {
    db = memoryDatabase();
    service = _FakeLock();
  });
  tearDown(() => db.close());

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        const _Shell(),
        database: db,
        disableAnimations: true,
        // The arrangement `app.dart` ships: the gate wraps the router's output
        // rather than the screen, so every route pushed on top of it — the
        // companion's own suggestion included — is inside the gate.
        wrap: (context, child) => Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return LockGate(child: child);
          },
        ),
        overrides: <Override>[
          appLockServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('with the lock on', () {
    setUp(
      () => db.settingsDao.writeBool(SettingKey.appLockEnabled, value: true),
    );

    testWidgets('the companion is not on the lock screen at all', (
      tester,
    ) async {
      service.outcome = UnlockOutcome.refused;
      await pumpGate(tester);

      expect(find.text('diary'), findsNothing);
      expect(
        find.byType(CompanionButton),
        findsNothing,
        reason:
            'The companion is reachable before the credential has been '
            'offered. It is inside the gate for exactly this reason and must '
            'stay there.',
      );
      expect(find.byType(CompanionMark), findsNothing);
    });

    testWidgets('and none of the thirteen lines is anywhere on screen', (
      tester,
    ) async {
      service.outcome = UnlockOutcome.refused;
      await pumpGate(tester);

      for (final sentence in everythingItCanSay.values) {
        expect(
          find.text(sentence),
          findsNothing,
          reason: 'the lock screen is showing "$sentence"',
        );
      }
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      for (final aside in <String>[
        l10n.companionLabel,
        l10n.companionSourcesNote,
      ]) {
        expect(find.text(aside), findsNothing);
      }
    });

    testWidgets('an open suggestion does not survive the app locking again', (
      tester,
    ) async {
      // The suggestion is a route under the gate rather than an overlay beside
      // it, so re-locking takes it down with everything else. If it were ever
      // moved into its own overlay this is the test that would notice.
      await pumpGate(tester);
      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();

      final line = ref.read(companionLineProvider);
      expect(find.text(everythingItCanSay[line]!), findsOneWidget);

      ref.read(lockControllerProvider).lock();
      await tester.pumpAndSettle();

      expect(find.text(everythingItCanSay[line]!), findsNothing);
      expect(find.byType(CompanionButton), findsNothing);
      expect(find.text('diary'), findsNothing);
    });

    testWidgets('a granted unlock brings it back', (tester) async {
      await pumpGate(tester);
      expect(find.text('diary'), findsOneWidget);
      expect(find.byType(CompanionButton), findsOneWidget);
    });
  });

  group('the arrangement this file assumes', () {
    test('is the one the shipped app actually uses', () {
      // The tests above wrap the gate around the navigator because that is what
      // `app.dart` does. If it ever wrapped the screen instead, every route —
      // the companion's suggestion, every dialog, every bottom sheet — would go
      // on rendering over the lock screen, and these tests would carry on
      // passing while the app leaked. So the arrangement itself is pinned.
      final source = File('lib/app.dart').readAsStringSync();
      expect(
        RegExp(r'builder:\s*\(context,\s*child\)\s*=>\s*LockGate\(')
            .hasMatch(source),
        isTrue,
        reason:
            'app.dart no longer wraps the router output in LockGate from '
            'MaterialApp.builder. Anything pushed as a route is now outside '
            'the gate.',
      );
    });
  });

  group('with the lock off', () {
    testWidgets('it is present, and still says nothing until asked', (
      tester,
    ) async {
      // The lock is off by default, and most people will leave it off. What
      // protects them from a sentence about their cycle being readable over
      // their shoulder is that there is no sentence on display — only a
      // crescent, which says nothing about anything.
      await pumpGate(tester);
      expect(find.byType(CompanionButton), findsOneWidget);
      for (final sentence in everythingItCanSay.values) {
        expect(find.text(sentence), findsNothing);
      }
    });
  });
}
