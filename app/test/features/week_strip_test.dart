// The Today tab's date row: swiping it, and opening a day from it (ADR-0027),
// and what it does under a finger and marks under a date (ADR-0028).
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
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
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

  group('the summary says things the way the editor would', () {
    // Two display preferences decide how the same stored values are said, and
    // the editor one tap away honours both. A summary that said them its own
    // way would read as the app having changed its mind about what it
    // recorded, which is the reason day_editor.dart gives for not letting the
    // flow chips change shape under the user.

    testWidgets('a temperature is shown in the unit the user reads', (
      tester,
    ) async {
      await db.settingsDao.writeBool(
        SettingKey.temperatureFahrenheit,
        value: true,
      );
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(date: today.addDays(-1), basalTemperatureCelsius: 36.5),
      ]);
      await pump(tester);
      await tester.tap(cellFor(tester, today.addDays(-1)));
      await tester.pumpAndSettle();

      // 36.5 C is 97.7 F. Celsius must not reach the screen.
      expect(find.textContaining('97.7'), findsOneWidget);
      expect(find.textContaining('36.5'), findsNothing);
    });

    testWidgets('flow is not named by an intensity the user put away', (
      tester,
    ) async {
      await db.settingsDao.writeBool(SettingKey.flowSimplified, value: true);
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(date: today.addDays(-1), flow: FlowIntensity.medium),
      ]);
      await pump(tester);
      await tester.tap(cellFor(tester, today.addDays(-1)));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.logBleedingYes),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.logFlowMedium), findsNothing);
    });
  });

  group('the row under a finger', () {
    // ADR-0028. The week arriving is still the switcher's work. What is pinned
    // here is the part between the finger going down and lifting, which a
    // fling that is then left to settle never looks at.

    /// Where the row is drawn, by its first cell. It moves with the row.
    double rowLeft(WidgetTester tester) =>
        tester.getTopLeft(cellFor(tester, sunday)).dx;

    /// Put a finger on the middle of the row and drag it [dx], in two moves.
    ///
    /// The first move is the touch slop that tells a drag from a tap. It is
    /// not reported as travel, so it is spent before the move that counts.
    Future<TestGesture> dragRow(WidgetTester tester, double dx) async {
      final gesture = await tester.startGesture(
        tester.getCenter(cellFor(tester, sunday.addDays(3))),
      );
      await gesture.moveBy(Offset(dx.sign * 30, 0));
      await gesture.moveBy(Offset(dx, 0));
      await tester.pump();
      return gesture;
    }

    testWidgets('follows the drag, by less than the finger moved', (
      tester,
    ) async {
      await pump(tester);
      final rest = rowLeft(tester);
      final gesture = await dragRow(tester, -30);

      final moved = rest - rowLeft(tester);
      expect(moved, greaterThan(0), reason: 'the row should follow');
      expect(moved, lessThan(30), reason: 'but not as far as the finger');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('stops short of its limit however far it is dragged', (
      tester,
    ) async {
      // The week arriving is not on screen until the finger lifts, so a row
      // that kept up with the finger would uncover the space it left.
      await pump(tester);
      final rest = rowLeft(tester);
      final gesture = await dragRow(tester, -600);

      // 28 is _pullLimit @ today_hero.dart.
      expect(rest - rowLeft(tester), lessThan(28));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('settles back where it was when the drag was not a swipe', (
      tester,
    ) async {
      await pump(tester);
      final rest = rowLeft(tester);
      final gesture = await dragRow(tester, -20);
      expect(rowLeft(tester), isNot(rest));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(rowLeft(tester), rest);
      expect(cellFor(tester, sunday), findsOneWidget);
      expect(find.text(l10nOf(tester).logWeekBackToToday), findsNothing);
    });

    testWidgets('a slow drag far enough turns the week without a flick', (
      tester,
    ) async {
      // It followed the finger, so springing back from a deliberate drag
      // would read as the app refusing it.
      await pump(tester);
      final gesture = await dragRow(tester, -60);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(cellFor(tester, sunday.addDays(7)), findsOneWidget);
    });

    testWidgets('a flick back the other way wins over how far it was dragged', (
      tester,
    ) async {
      // The flick is the later intent: a row dragged towards next week and
      // flicked back was being put back. The drag alone is far enough to have
      // turned the week forward.
      await pump(tester);
      final gesture = await dragRow(tester, -120);
      for (final ms in const <int>[500, 510, 520, 530]) {
        await gesture.moveBy(
          const Offset(15, 0),
          timeStamp: Duration(milliseconds: ms),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 530));
      await tester.pumpAndSettle();

      expect(cellFor(tester, sunday.addDays(-7)), findsOneWidget);
    });

    testWidgets('with animations off the row stays put, and the swipe still '
        'turns the week', (tester) async {
      // AND-34: turning motion off drops the movement, never the state change.
      await tester.pumpWidget(
        harness(const LogScreen(), database: db, disableAnimations: true),
      );
      await tester.pumpAndSettle();
      final rest = rowLeft(tester);
      final gesture = await dragRow(tester, -60);
      expect(rowLeft(tester), rest);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(cellFor(tester, sunday.addDays(7)), findsOneWidget);
    });
  });

  group('the heart under a date', () {
    // ADR-0028: the calendar's marker, under the same days, saying as little.

    /// The marker under [date], if it has one.
    Finder heartUnder(WidgetTester tester, CivilDate date) => find.descendant(
      of: cellFor(tester, date),
      matching: find.byType(IntercourseMarker),
    );

    testWidgets('is drawn for a day intercourse was recorded on, and for no '
        'other', (tester) async {
      await db.dayLogDao.save(
        DayLog(date: today.addDays(-1), intercourse: Intercourse.protected),
      );
      await pump(tester);

      expect(heartUnder(tester, today.addDays(-1)), findsOneWidget);
      expect(find.byType(IntercourseMarker), findsOneWidget);
    });

    testWidgets('says that something was recorded, never which answer', (
      tester,
    ) async {
      // The screen the app opens on is read over a shoulder, and a screen
      // reader is audible to the room. One mark and one phrase for both
      // answers, so neither can be told from the other.
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(date: today.addDays(-1), intercourse: Intercourse.protected),
        DayLog(date: today.addDays(-2), intercourse: Intercourse.unprotected),
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      final context = tester.element(find.byType(LogScreen));

      for (final date in <CivilDate>[today.addDays(-1), today.addDays(-2)]) {
        expect(heartUnder(tester, date), findsOneWidget);
        expect(
          tester.getSemantics(cellFor(tester, date)).label,
          l10n.calendarCellIntercourseSuffix(date.weekdayDayAndMonth(context)),
        );
      }
    });

    testWidgets('reaches back to a day recorded long before, once its week is '
        'on screen', (tester) async {
      // Nothing is migrated or stored for this: the row reads the same days
      // the calendar does, so a day ticked before the row drew hearts has one.
      final longAgo = today.addDays(-23);
      await db.dayLogDao.save(
        DayLog(date: longAgo, intercourse: Intercourse.unprotected),
      );
      await pump(tester);
      expect(find.byType(IntercourseMarker), findsNothing);

      await swipeWeeks(tester, -3);
      expect(heartUnder(tester, longAgo), findsOneWidget);
    });

    testWidgets('appears the moment the day is ticked', (tester) async {
      await pump(tester);
      final ticked = find.descendant(
        of: editorInSheet(),
        matching: find.text(l10nOf(tester).logIntercourseProtected),
      );
      expect(find.byType(IntercourseMarker), findsNothing);

      await tester.tap(cellFor(tester, today));
      await tester.pumpAndSettle();
      await tester.ensureVisible(ticked);
      await tester.pumpAndSettle();
      await tester.tap(ticked);
      await tester.pumpAndSettle();

      expect(heartUnder(tester, today), findsOneWidget);
    });

    testWidgets('shares the space under the date with the dot, and adds no '
        'height', (tester) async {
      // The row sits above everything else on the screen the app opens on. A
      // mark that made its day taller would move all of it.
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(
          date: today.addDays(-1),
          flow: FlowIntensity.medium,
          intercourse: Intercourse.protected,
        ),
        DayLog(date: today.addDays(-2), flow: FlowIntensity.medium),
      ]);
      await pump(tester);

      // Tomorrow has nothing under it, which is the row at its plainest.
      final plain = tester.getSize(cellFor(tester, today.addDays(1))).height;
      expect(tester.getSize(cellFor(tester, today.addDays(-1))).height, plain);
      expect(tester.getSize(cellFor(tester, today.addDays(-2))).height, plain);
    });
  });

  group('the week in transition', () {
    testWidgets('does not leave the outgoing week tappable', (tester) async {
      // Both weeks are mounted while the switcher runs, and a fade does not
      // stop a cell being hit: without the IgnorePointer there are fourteen
      // tappable dates in seven columns, and a tap can open a day a week away
      // from the one under the finger. Asserted on the guard itself, because
      // a tap mid-transition lands wherever the two sliding rows happen to be.
      await pump(tester);
      await tester.fling(cellFor(tester, sunday), const Offset(200, 0), 600);
      await tester.pump(const Duration(milliseconds: 60));

      final guards = tester.widgetList<IgnorePointer>(
        find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(guards.length, 2, reason: 'both weeks should be mounted');
      expect(guards.where((guard) => guard.ignoring).length, 1);
      expect(guards.where((guard) => !guard.ignoring).length, 1);

      await tester.pumpAndSettle();
    });
  });

  group('at a large text scale', () {
    // An overflow throws during paint, so this catches it without a golden.
    // The goldens cover the three screens and are generated on linux-x64, so
    // a golden for a modal sheet would be both new artwork and unverifiable
    // here; what is worth asserting is the thing that actually went wrong in
    // this change, which is a fixed height meeting scaled text. The strip's
    // first version overflowed by 14 pixels at 200%.
    for (final scale in const <String, double>{'150': 1.5, '200': 2}.entries) {
      testWidgets('the date row does not overflow at ${scale.key}%', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            const LogScreen(),
            database: db,
            textScaler: TextScaler.linear(scale.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('the date row with both marks under a date does not '
          'overflow at ${scale.key}%', (tester) async {
        await db.dayLogDao.save(
          DayLog(
            date: today.addDays(-1),
            flow: FlowIntensity.medium,
            intercourse: Intercourse.protected,
          ),
        );
        await tester.pumpWidget(
          harness(
            const LogScreen(),
            database: db,
            textScaler: TextScaler.linear(scale.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(IntercourseMarker), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a locked day does not overflow at ${scale.key}%', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            const LogScreen(),
            database: db,
            textScaler: TextScaler.linear(scale.value),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(cellFor(tester, today.addDays(-1)));
        await tester.pumpAndSettle();
        expect(find.text(l10nOf(tester).logDayLockedTitle), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l10nOf(tester).logDayUnlock));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
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
