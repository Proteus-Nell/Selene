// The calendar (AND-14).
//
// The app's primary surface and the one most likely to be unusable. Three of
// these tests are the accessibility requirements from docs/PLAN.md 2.4.4 turned
// into assertions, and one is the overclaiming rule from 6.2.
//
// The goldens are regression capture, not the accessibility check: a PNG cannot
// tell anyone whether two states are distinguishable. The structural tests
// above them are what actually hold the line. Goldens are generated on
// linux-x64 with the pinned Flutter version, which is what CI runs; a mismatch
// on another platform means regenerate, not debug.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';

import 'harness.dart';

/// Renders [child] with all colour removed, to check the never-colour-alone
/// rule the way a person with monochrome vision would see it.
Widget greyscale(Widget child) => ColorFiltered(
  colorFilter: const ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]),
  child: child,
);

/// Restricts a finder to the month grid, excluding the legend.
///
/// The legend deliberately shows one of every marker, so an unscoped
/// `find.byType(PredictedMarker)` always matches and would make the
/// "no window is drawn" assertions pass for the wrong reason.
Finder inGrid(Finder matching) =>
    find.descendant(of: find.byType(DayCell), matching: matching);

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpCalendar(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    TextScaler textScaler = TextScaler.noScaling,
    Widget Function(Widget)? wrap,
  }) async {
    final screen = harness(
      const CalendarScreen(),
      database: db,
      brightness: brightness,
      textScaler: textScaler,
    );
    await tester.pumpWidget(wrap == null ? screen : wrap(screen));
    await tester.pumpAndSettle();
  }

  group('every day cell', () {
    testWidgets('announces its date and its state', (tester) async {
      // A grid of coloured squares announces nothing. This is the assertion
      // that stops the app's primary surface being unusable with a screen
      // reader.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);

      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(DayCell),
          matching: find.byType(Semantics),
        ),
      );
      final labels = semantics
          .map((s) => s.properties.label)
          .whereType<String>()
          .toList();

      expect(labels, isNotEmpty);
      // Every cell carries a date.
      expect(
        labels.where((l) => RegExp(r'\d').hasMatch(l)).length,
        labels.length,
      );
      // At least one carries a period-day state, in the shape the plan asks
      // for: "14 March, period day 2".
      expect(
        labels.any((l) => l.contains('period day')),
        isTrue,
        reason: 'no cell announced a period day: $labels',
      );
      expect(labels.any((l) => l.contains('today')), isTrue);
    });

    testWidgets('is reachable as a button, not just a painted box', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final cell = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(DayCell),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(cell.properties.button, isTrue);
      // And the long-press that opens the editor is exposed as an action,
      // not left as a gesture only a sighted user can discover.
      expect(cell.properties.onLongPress, isNotNull);
    });

    testWidgets('can be activated the way a screen reader activates a button', (
      tester,
    ) async {
      // Asserted on the rendered semantics tree rather than on the widget's
      // properties, because the bug this catches lives in the gap between the
      // two: the cell sets `excludeSemantics`, so an action the InkWell handles
      // does not reach the node unless it is re-declared. A node marked
      // `button: true` with no tap action reads as a button to TalkBack and
      // then does nothing when double-tapped.
      // Disposed here rather than in a tear-down: flutter_test checks for a
      // leaked SemanticsHandle before tear-downs run, so addTearDown fails the
      // test it is meant to clean up after.
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);

      final data = tester
          .getSemantics(find.byType(DayCell).first)
          .getSemanticsData();
      handle.dispose();

      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'the day cell announces itself as a button but cannot be '
            'activated by one',
      );
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
    });
  });

  group('state is never carried by colour alone', () {
    testWidgets('a period day and a predicted day differ in shape', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);

      // Filled marker for logged bleeding, hollow marker for the predicted
      // window. The two read apart with no colour at all.
      expect(inGrid(find.byType(PeriodMarker)), findsWidgets);

      // The legend shows one of each too, which is the point of a legend. It
      // sits below the next-period panel added in AND-25, so with history
      // seeded it is off-screen until scrolled to — and a ListView does not
      // build what it is not showing. Finding nothing here would otherwise read
      // as a missing marker rather than a longer page.
      final legendMarker = find.byType(PredictedMarker);
      await tester.scrollUntilVisible(legendMarker, 200);
      await tester.pumpAndSettle();
      expect(legendMarker, findsWidgets);
    });

    testWidgets('the legend names every state in words', (tester) async {
      await pumpCalendar(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.calendarLegendPeriod), findsOneWidget);
      expect(find.text(l10n.calendarLegendPredicted), findsOneWidget);
      expect(find.text(l10n.calendarLegendToday), findsOneWidget);
    });

    testWidgets('renders in greyscale without error', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester, wrap: greyscale);
      expect(tester.takeException(), isNull);
      expect(inGrid(find.byType(PeriodMarker)), findsWidgets);
    });
  });

  group('the predicted window', () {
    testWidgets('is drawn as a range of days, never one day', (tester) async {
      // The everyday form of overclaiming is a single highlighted date. There
      // is no code path here that produces one.
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28, 28]);
      await pumpCalendar(tester);
      // The next window falls past the end of the current month, so step
      // forward. Doing it this way also exercises month navigation.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final predicted = inGrid(find.byType(PredictedMarker)).evaluate().length;
      expect(
        predicted,
        greaterThan(1),
        reason: 'a one-day predicted window would be a bare date',
      );
    });

    testWidgets('is absent, with a reason, when nothing is logged', (
      tester,
    ) async {
      await pumpCalendar(tester);
      expect(inGrid(find.byType(PredictedMarker)), findsNothing);
      expect(
        find.text(l10nOf(tester).calendarNoPredictedWindow),
        findsOneWidget,
      );
    });

    testWidgets('is absent when the cycles are too variable to support one', (
      tester,
    ) async {
      // TooIrregular must not quietly fall back to drawing a narrow window.
      await seedHistory(db, const <int>[
        26,
        34,
        26,
        34,
        26,
        34,
      ], endingDaysAgo: 3);
      await pumpCalendar(tester);
      expect(inGrid(find.byType(PredictedMarker)), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(inGrid(find.byType(PredictedMarker)), findsNothing);
    });
  });

  group('layout', () {
    for (final scale in <double>[1, 1.5, 2]) {
      testWidgets('survives a text scale of $scale', (tester) async {
        await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
        await pumpCalendar(tester, textScaler: TextScaler.linear(scale));
        // A RenderFlex overflow throws during paint, so pumping is the check.
        expect(tester.takeException(), isNull);
        expect(find.byType(DayCell), findsWidgets);
      });
    }
  });

  group('editing', () {
    testWidgets('long-pressing a day opens the editor for that day', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final target = find.byType(DayCell).at(14);
      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).logFlowHeavy), findsOneWidget);
    });

    testWidgets('an edit made in the sheet is stored', (tester) async {
      await pumpCalendar(tester);
      await tester.longPress(find.byType(DayCell).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nOf(tester).logFlowMedium));
      await tester.pumpAndSettle();
      expect(await db.dayLogDao.allLogs(), hasLength(1));
    });
  });

  group('goldens', () {
    test('the greyscale golden really is greyscale', () {
      // Guards the mistake above: if the filter stops reaching the capture,
      // the two files become identical again and this fails immediately.
      final light = File('test/features/goldens/calendar_light.png');
      final grey = File('test/features/goldens/calendar_greyscale.png');
      expect(light.existsSync() && grey.existsSync(), isTrue);
      expect(
        grey.readAsBytesSync(),
        isNot(light.readAsBytesSync()),
        reason: 'the greyscale golden is a copy of the light one',
      );
    });

    testWidgets('light', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester);
      await expectLater(
        find.byType(CalendarScreen),
        matchesGoldenFile('goldens/calendar_light.png'),
      );
    });

    testWidgets('dark', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester, brightness: Brightness.dark);
      await expectLater(
        find.byType(CalendarScreen),
        matchesGoldenFile('goldens/calendar_dark.png'),
      );
    });

    testWidgets('greyscale', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpCalendar(tester, wrap: greyscale);
      // Captured at the ColorFiltered node, not at the screen inside it. A
      // golden taken from a descendant is rendered from that descendant's own
      // layer, so the ancestor's filter never reaches the image: the first
      // version of this test produced a file byte-identical to the light
      // golden and would have "passed" forever.
      await expectLater(
        find.byType(ColorFiltered),
        matchesGoldenFile('goldens/calendar_greyscale.png'),
      );
    });
  });
}
