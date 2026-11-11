// Selene's own Reduce animations switch, and nothing of Android's (ADR-0029).
//
// Two things have to hold for the app's movement to be the app's decision.
// The flag Motion reads has to be the switch, whatever the phone reports: that
// half is pinned here, on the real app, with the platform's flag set the other
// way each time. The other half is the framework's own shortening, which
// answers from the binding and cannot be seen from a widget test;
// app_binding_test.dart holds it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/main.dart';
import 'package:period_tracker/notifications/scheduler.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// Start the real app over [db], on a phone whose own setting is
  /// [phoneAnimationsOff].
  Future<void> launch(
    WidgetTester tester, {
    required bool phoneAnimationsOff,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: phoneAnimationsOff);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      await buildAppScope(
        database: db,
        clock: testClock,
        logger: RingLogger(clock: testClock),
        notificationGateway: const NoopNotificationGateway(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What a screen inside the app is told about animations.
  bool toldToReduce(WidgetTester tester) => MediaQuery.disableAnimationsOf(
    tester.element(find.byType(Scaffold).first),
  );

  /// Unmount inside the test, so drift's stream timers drain under the fake
  /// clock rather than being left pending at teardown. See widget_test.dart.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  group('the app', () {
    testWidgets('keeps its movement on a phone that has turned its own off', (
      tester,
    ) async {
      // The case this was built for: Android says no animations, Selene's
      // switch has never been touched, and the app is told to move.
      await launch(tester, phoneAnimationsOff: true);
      expect(toldToReduce(tester), isFalse);
      await close(tester);
    });

    testWidgets('stops moving when its own switch is on, on a phone that '
        'allows animations', (tester) async {
      await db.settingsDao.writeBool(SettingKey.reduceAnimations, value: true);
      await launch(tester, phoneAnimationsOff: false);
      expect(toldToReduce(tester), isTrue);
      await close(tester);
    });

    testWidgets('follows the switch while it is open, both ways', (
      tester,
    ) async {
      await launch(tester, phoneAnimationsOff: true);
      expect(toldToReduce(tester), isFalse);

      await db.settingsDao.writeBool(SettingKey.reduceAnimations, value: true);
      await tester.pumpAndSettle();
      expect(toldToReduce(tester), isTrue);

      await db.settingsDao.writeBool(SettingKey.reduceAnimations, value: false);
      await tester.pumpAndSettle();
      expect(toldToReduce(tester), isFalse);
      await close(tester);
    });
  });

  group('the switch in Settings', () {
    testWidgets('is off until it is turned on, stores what it is set to, and '
        'says the phone is not followed', (tester) async {
      await tester.pumpWidget(harness(const SettingsScreen(), database: db));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      final tile = find.widgetWithText(
        SwitchListTile,
        l10n.settingsReduceAnimations,
      );
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      // Someone who turned animations off on their phone will look there for
      // the reason Selene still moves, unless the switch says otherwise.
      expect(find.text(l10n.settingsReduceAnimationsSubtitle), findsOneWidget);
      expect(l10n.settingsReduceAnimationsSubtitle, contains('phone'));

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(
        await db.settingsDao.readBool(
          SettingKey.reduceAnimations,
          orElse: false,
        ),
        isTrue,
      );
    });
  });
}
