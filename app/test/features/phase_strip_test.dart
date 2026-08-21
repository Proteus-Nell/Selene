// The phase strip on the calendar (AND-25, ADR-0007).
//
// copy_test.dart proves the app never *says* the forbidden things.
// cycle_phase_test.dart proves the arithmetic is right. This file covers the
// join between them: that the screen shows what the domain computed, and — the
// part that actually matters — that the ovulation estimate cannot reach the
// screen unless the user has switched it on.
//
// Asserted through the calendar rather than the widget alone, because the
// failure mode worth guarding is a screen wiring `withOvulationEstimate: true`
// unconditionally, which a widget test given a ready-made CyclePosition would
// never see.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/calendar/phase_strip.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(harness(const CalendarScreen(), database: db));
    await tester.pumpAndSettle();
  }

  Future<void> set(SettingKey key, {required bool value}) =>
      db.settingsDao.writeBool(key, value: value);

  group('by default', () {
    testWidgets('the strip is shown', (tester) async {
      // On without being asked for. A phase name restates dates the user
      // logged, which is the whole distinction ADR-0007 drew.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      expect(find.byType(PhaseStrip), findsOneWidget);
    });

    testWidgets('it names the day of the cycle', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      // The run ended two days ago and started three days before that, so
      // today is day 6 — the same arithmetic the log screen shows.
      expect(find.text(l10nOf(tester).calendarPhaseDay(6)), findsOneWidget);
    });

    testWidgets('no ovulation estimate appears anywhere', (tester) async {
      // The assertion this file exists for. Not "the widget hides it" — the
      // estimate must never be computed, so there is nothing to leak.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      expect(find.text(l10nOf(tester).calendarOvulationTitle), findsNothing);
    });
  });

  group('with the estimate switched on', () {
    testWidgets('it appears, as a range, with its caveat beside it', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await set(SettingKey.showOvulationWindow, value: true);
      await pumpCalendar(tester);

      final l10n = l10nOf(tester);
      final title = find.text(l10n.calendarOvulationTitle);
      await tester.scrollUntilVisible(title, 120);
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      // On screen, under the number it qualifies, not behind a link.
      expect(find.text(l10n.calendarOvulationCaveat), findsOneWidget);
    });

    testWidgets('turning it back off removes it again', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await set(SettingKey.showOvulationWindow, value: true);
      await pumpCalendar(tester);
      await set(SettingKey.showOvulationWindow, value: false);
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).calendarOvulationTitle), findsNothing);
    });
  });

  group('with phases switched off', () {
    testWidgets('the strip goes, and the estimate goes with it', (
      tester,
    ) async {
      // Turning off the milder claim must not leave the stronger one on screen
      // by itself, which is what a second independent `if` would have done.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await set(SettingKey.showCyclePhases, value: false);
      await set(SettingKey.showOvulationWindow, value: true);
      await pumpCalendar(tester);

      expect(find.byType(PhaseStrip), findsNothing);
      expect(find.text(l10nOf(tester).calendarOvulationTitle), findsNothing);
    });
  });

  group('when the app cannot say', () {
    testWidgets('it says so rather than rendering an empty strip', (
      tester,
    ) async {
      await pumpCalendar(tester);
      expect(find.text(l10nOf(tester).calendarPhaseUnknown), findsOneWidget);
    });
  });

  group('the phase name', () {
    testWidgets('explains itself on tap', (tester) async {
      // "Luteal" is a word most people have not been given a definition for,
      // and printing it without one is how a clinical name becomes noise.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      final l10n = l10nOf(tester);

      // Whichever phase today happens to fall in — the point is that the name
      // shown is the one explained, not that today is any particular phase.
      final chip = find.descendant(
        of: find.byType(PhaseStrip),
        matching: find.byType(ActionChip),
      );
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final explanations = <String>[
        l10n.calendarPhasePeriodExplained,
        l10n.calendarPhaseFollicularExplained,
        l10n.calendarPhaseLutealExplained,
      ];
      expect(
        explanations.where((text) => find.text(text).evaluate().isNotEmpty),
        hasLength(1),
        reason: 'the dialog did not carry exactly one phase explanation',
      );

      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('at 200% text scale', () {
    testWidgets('the strip reflows instead of overflowing', (tester) async {
      // "Day 24 of your cycle" and a phase chip do not fit side by side on a
      // phone at this scale. A Row would clip; the strip uses a Wrap, and an
      // overflow throws during paint, so pumping is the assertion.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await db.settingsDao.writeBool(
        SettingKey.showOvulationWindow,
        value: true,
      );
      await tester.pumpWidget(
        harness(
          const CalendarScreen(),
          database: db,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PhaseStrip), findsOneWidget);
    });
  });

  group('the next-period panel', () {
    testWidgets('is the same one the insights screen uses', (tester) async {
      // One widget, so one shape. docs/PLAN.md 6.2 requires the range to be the
      // headline, and the everyday way that erodes is a second screen rendering
      // the same thing a little more confidently.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      expect(find.text(l10nOf(tester).insightsFourInFive), findsOneWidget);
    });
  });
}
