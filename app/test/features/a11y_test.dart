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
import 'package:period_tracker/features/common/formatting.dart';
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

  // The day sheet is not in the map above because it is not a screen: it is a
  // modal route, reachable only by tapping a date on the Today tab, so pumping
  // it needs that tap. It was outside this gate when it was written, which is
  // exactly the state the gate exists to prevent (ADR-0027).
  group('the day sheet', () {
    for (final brightness in Brightness.values) {
      /// Opens the sheet for the day [back] days before the test clock's
      /// today, from the date row on the Today tab.
      Future<void> openDay(WidgetTester tester, int back) async {
        final date = testClock.today().addDays(-back);
        await tester.pumpWidget(
          harness(const LogScreen(), database: db, brightness: brightness),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(LogScreen));
        await tester.tap(
          find
              .bySemanticsLabel(
                RegExp(RegExp.escape(date.weekdayDayAndMonth(context))),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }

      Future<void> check(WidgetTester tester) async {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }

      testWidgets('meets the guidelines locked in ${brightness.name}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await seedHistory(db, const <int>[28, 29, 28, 30, 28, 29, 28]);
        // Yesterday: a past day, so the lock bar and the summary are both up.
        await openDay(tester, 1);
        expect(find.text(l10nOf(tester).logDayLockedTitle), findsOneWidget);
        await check(tester);
        handle.dispose();
      });

      testWidgets('meets the guidelines unlocked in ${brightness.name}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await seedHistory(db, const <int>[28, 29, 28, 30, 28, 29, 28]);
        await openDay(tester, 1);
        await tester.tap(find.text(l10nOf(tester).logDayUnlock));
        await tester.pumpAndSettle();
        await check(tester);
        handle.dispose();
      });
    }
  });
}
