// The Today tab's date row: swiping it, and opening a day from it (ADR-0027).
//
// The row used to be a read-only Row of seven cells. It now steps a week per
// swipe in either direction without limit, and each cell opens that day. What
// is worth pinning here is the part that is easy to get wrong in a way no
// screenshot shows: a past day opens with no editor in the sheet at all,
// rather than an editor behind something that merely looks disabled. A control
// that is on screen and inert is still reachable by a screen reader, so
// "locked" has to mean "not built".
//
// Everything here looks for the editor *inside the sheet*. The log screen has
// a DayEditor of its own, for the day its chips select, so a bare
// `find.byType(DayEditor)` is always satisfied and would prove nothing.
//
// The timing rules live in past_edit_guard_test.dart, which can step through
// half an hour in a line.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/log/day_editor.dart';
import 'package:period_tracker/features/log/log_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  final today = testClock.today();
  final sunday = _sundayOf(today);

  // Which week the strip is on, so swipeWeeks knows what is on screen to
  // fling. The test clock's today is a Tuesday, so this week holds only two
  // past days: the tests that need more swipe back to a week that is wholly
  // in the past.
  var offset = 0;

  setUp(() {
    db = memoryDatabase();
    offset = 0;
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LogScreen(), database: db));
    await tester.pumpAndSettle();
  }

  /// The cell for [date], found by the label the strip gives it.
  Finder cellFor(WidgetTester tester, CivilDate date) {
    final context = tester.element(find.byType(LogScreen));
    return find
        .bySemanticsLabel(
          RegExp(RegExp.escape(date.weekdayDayAndMonth(context))),
        )
        .first;
  }

  /// The editor inside the open sheet, if there is one.
  Finder editorInSheet() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(DayEditor),
  );

  /// Swipe the strip [by] weeks, forward for positive.
  ///
  /// Flings the cell of the week currently showing, because the cell swiped a
  /// moment ago is gone by the next step.
  Future<void> swipeWeeks(WidgetTester tester, int by) async {
    for (var step = 0; step < by.abs(); step++) {
      await tester.fling(
        cellFor(tester, sunday.addDays(offset * 7)),
        Offset(by > 0 ? -200 : 200, 0),
        600,
      );
      await tester.pumpAndSettle();
      offset += by.sign;
    }
  }

  /// Open [date], lift its lock, and close the sheet.
  Future<void> unlockDay(WidgetTester tester, CivilDate date) async {
    final l10n = l10nOf(tester);
    await tester.tap(cellFor(tester, date));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.logDayUnlock));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonClose));
    await tester.pumpAndSettle();
  }

  group('the date row', () {
    testWidgets('shows the week today is in', (tester) async {
      await pump(tester);
      for (var i = 0; i < 7; i++) {
        expect(cellFor(tester, sunday.addDays(i)), findsOneWidget);
      }
    });

    testWidgets('steps a whole week back, and a whole week forward', (
      tester,
    ) async {
      await pump(tester);
      await swipeWeeks(tester, -1);
      expect(cellFor(tester, sunday.addDays(-7)), findsOneWidget);
      expect(
        find
            .bySemanticsLabel(
              RegExp(
                RegExp.escape(
                  sunday.weekdayDayAndMonth(
                    tester.element(find.byType(LogScreen)),
                  ),
                ),
              ),
            )
            .evaluate(),
        isEmpty,
      );

      await swipeWeeks(tester, 1);
      expect(cellFor(tester, sunday), findsOneWidget);
    });

    testWidgets('pages into weeks that have no logs in them at all', (
      tester,
    ) async {
      // Unbounded on purpose: the weeks before the first logged day are empty
      // rather than absent.
      await pump(tester);
      await swipeWeeks(tester, -5);
      expect(cellFor(tester, sunday.addDays(-35)), findsOneWidget);
    });

    testWidgets('offers the way back only once it has left this week', (
      tester,
    ) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logWeekBackToToday), findsNothing);

      await swipeWeeks(tester, -2);
      expect(find.text(l10n.logWeekBackToToday), findsOneWidget);

      await tester.tap(find.text(l10n.logWeekBackToToday));
      await tester.pumpAndSettle();
      expect(cellFor(tester, sunday), findsOneWidget);
      expect(find.text(l10n.logWeekBackToToday), findsNothing);
    });
  });

  group('opening a day', () {
    testWidgets('today goes straight to the editor, with no lock', (
      tester,
    ) async {
      // The Today tab is where today is logged. Asking about the day the
      // screen is named after would be noise.
      await pump(tester);
      await tester.tap(cellFor(tester, today));
      await tester.pumpAndSettle();

      expect(editorInSheet(), findsOneWidget);
      expect(find.text(l10nOf(tester).logDayUnlock), findsNothing);
    });

    testWidgets('a past day opens locked, showing what was recorded and no '
        'editor', (tester) async {
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(
          date: today.addDays(-2),
          flow: FlowIntensity.medium,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.mild,
          },
        ),
      ]);
      await pump(tester);
      await tester.tap(cellFor(tester, today.addDays(-2)));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);

      expect(find.text(l10n.logDayLockedTitle), findsOneWidget);
      // Absent, not disabled.
      expect(editorInSheet(), findsNothing);
      // And what was recorded is readable.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.logFlowMedium),
        ),
        findsOneWidget,
      );
    });

    testWidgets('unlocking a past day replaces the summary with the editor', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(cellFor(tester, today.addDays(-2)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nOf(tester).logDayUnlock));
      await tester.pumpAndSettle();

      expect(editorInSheet(), findsOneWidget);
      expect(find.text(l10nOf(tester).logDayLockedTitle), findsNothing);
    });

    testWidgets('a day with nothing recorded says so rather than showing an '
        'empty summary', (tester) async {
      await pump(tester);
      await tester.tap(cellFor(tester, today.addDays(-1)));
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).logDayNothingRecorded), findsOneWidget);
    });

    testWidgets('a future day offers no editor and says why', (tester) async {
      // CycleRepository refuses a future-dated write, so an editor here would
      // be a control whose every use fails.
      await pump(tester);
      await swipeWeeks(tester, 1);
      await tester.tap(cellFor(tester, today.addDays(7)));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);

      expect(find.text(l10n.logDayFutureUnrecordable), findsOneWidget);
      expect(editorInSheet(), findsNothing);
      expect(find.text(l10n.logDayUnlock), findsNothing);
    });
  });

  group('the offer to stop asking', () {
    testWidgets('is absent at three days and appears once a fourth has been '
        'unlocked', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      // Last week, every day of which is in the past.
      final lastWeek = sunday.addDays(-7);
      await swipeWeeks(tester, -1);

      for (var i = 0; i < 3; i++) {
        await unlockDay(tester, lastWeek.addDays(i));
      }
      // Three is a correction, so the fourth day is still only offered the
      // lock itself.
      await tester.tap(cellFor(tester, lastWeek.addDays(3)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logDayStandDown), findsNothing);
      await tester.tap(find.text(l10n.logDayUnlock));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();

      // Four days in, which is a sitting.
      await tester.tap(cellFor(tester, lastWeek.addDays(4)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logDayStandDown), findsOneWidget);
    });

    testWidgets('taking it opens the next past day unlocked', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      final lastWeek = sunday.addDays(-7);
      await swipeWeeks(tester, -1);
      for (var i = 0; i < 4; i++) {
        await unlockDay(tester, lastWeek.addDays(i));
      }

      await tester.tap(cellFor(tester, lastWeek.addDays(4)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.logDayStandDown));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();

      // No lock on the next one, and it was not asked for.
      await tester.tap(cellFor(tester, lastWeek.addDays(5)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logDayLockedTitle), findsNothing);
      expect(editorInSheet(), findsOneWidget);
    });
  });
}

/// The Sunday that starts [date]'s week.
CivilDate _sundayOf(CivilDate date) =>
    date.addDays(-(date.toLocalMidnight().weekday % 7));
