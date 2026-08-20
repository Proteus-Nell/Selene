// The accessibility guidelines, machine-checked (docs/PLAN.md 2.4.4).
//
// The plan's own argument for this file: the no-network guarantee is not a
// value statement, it is an automated check that fails the build, and
// accessibility gets the same treatment because Flutter ships the matchers to
// do it. AND-18 lifts these into a dedicated CI gate; running them now is what
// makes that a formality rather than a retrofit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/onboarding/onboarding_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// Every screen, with enough history that the populated states are covered.
  final screens = <String, Widget>{
    'onboarding': OnboardingScreen(onFinished: () {}),
    'log': const LogScreen(),
    'calendar': const CalendarScreen(),
    'insights': const InsightsScreen(),
    'settings': const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    group(entry.key, () {
      for (final brightness in Brightness.values) {
        testWidgets('meets the guidelines in ${brightness.name}', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await seedHistory(db, const <int>[28, 29, 28, 30, 28, 29, 28]);
          await tester.pumpWidget(
            harness(entry.value, database: db, brightness: brightness),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
          );
          handle.dispose();
        });
      }
    });
  }
}
