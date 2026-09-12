// Insights (AND-15).
//
// The screen where overclaiming would do the most damage. Two rules are pinned
// here: no state is a dead end (risk R17), and the range is always the
// headline rather than the single most likely day (docs/PLAN.md 6.2).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/features/insights/cycle_length_chart.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';

import 'harness.dart';

/// Scrolls the screen to the end.
///
/// The self-metrics sit below the fold in the default test viewport, which is
/// where they belong: the prediction and the user's own figures come first.
Future<void> scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpInsights(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(const InsightsScreen(), database: db, textScaler: textScaler),
    );
    await tester.pumpAndSettle();
  }

  group('the disclaimer', () {
    testWidgets('is permanently on the screen, not behind a link', (
      tester,
    ) async {
      await pumpInsights(tester);
      expect(find.byType(PermanentDisclaimer), findsOneWidget);
      // Checked as two claims rather than as one phrasing. This used to pin
      // the exact words "not contraception" and "not medical advice", and the
      // disclaimer was reworded to "does not serve as a contraceptive aid or
      // medical advice", which says the same thing. A test that fails on a
      // rewrite meaning the same thing teaches the next person to edit the
      // test instead of thinking about the claim.
      //
      // Both exclusions still have to be there, and both still have to be
      // denials: dropping either, or stating one as a permission, fails here.
      final text = l10nOf(tester).insightsDisclaimer.toLowerCase();
      expect(text, contains('contracept'));
      expect(text, contains('medical advice'));
      expect(
        RegExp(r'\b(not|never|no)\b').hasMatch(text),
        isTrue,
        reason: 'the disclaimer names the exclusions but does not deny them',
      );
    });

    testWidgets('stays put once there is a real prediction', (tester) async {
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28, 28]);
      await pumpInsights(tester);
      expect(find.byType(PermanentDisclaimer), findsOneWidget);
    });
  });

  group('every prediction state renders', () {
    testWidgets('nothing logged', (tester) async {
      await pumpInsights(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.insightsNoDataTitle), findsOneWidget);
      // Not a dead end even here: it says what to do next.
      expect(find.text(l10n.insightsNoDataBody), findsOneWidget);
    });

    testWidgets('a short history, labelled as not yet personalised', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28]);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.insightsNextPeriodTitle), findsOneWidget);
      expect(find.text(l10n.insightsNotPersonalisedYet), findsOneWidget);
    });

    testWidgets('a settled history', (tester) async {
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28, 28]);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.insightsNextPeriodTitle), findsOneWidget);
      expect(find.text(l10n.insightsBasedOnCycles(7)), findsOneWidget);
      expect(find.text(l10n.insightsConfidenceHigh), findsOneWidget);
    });

    testWidgets('too irregular, which must never be a dead end', (
      tester,
    ) async {
      // Risk R17: a user with PCOS or in perimenopause who is told only "we
      // cannot predict this" stops logging, which degrades the data and makes
      // the state permanent.
      await seedHistory(db, const <int>[
        26,
        34,
        26,
        34,
        26,
        34,
      ], endingDaysAgo: 3);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.insightsTooIrregularTitle), findsOneWidget);
      // Their own numbers are still on the screen.
      expect(find.text(l10n.insightsCyclesRecorded(6)), findsOneWidget);
      expect(find.text(l10n.insightsRange(26, 34)), findsOneWidget);
      expect(find.byType(CycleLengthChart), findsOneWidget);
      // And the framing is about the data, never about the person.
      final copy =
          '${l10n.insightsTooIrregularTitle} ${l10n.insightsTooIrregularBody}'
              .toLowerCase();
      expect(copy, isNot(contains('you are irregular')));
      expect(copy, isNot(contains('abnormal')));
      expect(copy, isNot(contains('problem')));
    });

    testWidgets('lost track after a long silence', (tester) async {
      await seedHistory(
        db,
        const <int>[28, 28, 28],
        endingDaysAgo: CycleRules.lostTrackAfterDays + 5,
      );
      await pumpInsights(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.insightsLostTrackTitle), findsOneWidget);
      // Losing track must not lose the user their history.
      expect(find.text(l10n.insightsCyclesRecorded(3)), findsOneWidget);
    });

    testWidgets('a device clock that moved backwards', (tester) async {
      await seedHistory(db, const <int>[28, 28]);
      await tester.pumpWidget(
        harness(
          const InsightsScreen(),
          database: db,
          clock: testClock.advanced(-40),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10nOf(tester).insightsInconsistentTitle),
        findsOneWidget,
      );
    });
  });

  group('the window', () {
    testWidgets('leads with the range, not the single likely day', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28, 28]);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);

      final rangeFinder = find.textContaining(
        l10n.insightsFourInFive.substring(0, 12),
      );
      expect(rangeFinder, findsOneWidget);

      // The range is rendered larger than the most-likely line. Reversing
      // that emphasis is the everyday form of overclaiming.
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      final rangeStyle = texts
          .firstWhere((t) => t.data?.startsWith('Between') ?? false)
          .style;
      final likelyStyle = texts
          .firstWhere((t) => t.data?.startsWith('Most likely') ?? false)
          .style;
      expect(
        rangeStyle?.fontSize ?? 0,
        greaterThan(likelyStyle?.fontSize ?? 0),
      );
    });
  });

  group('the chart', () {
    testWidgets('carries a text summary, because a canvas announces nothing', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 30, 27, 29, 28, 31, 28]);
      await pumpInsights(tester);

      final semantics = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(CycleLengthChart),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => (s.properties.label ?? '').isNotEmpty)
          .toList();
      expect(semantics, isNotEmpty, reason: 'the chart has no label');
      expect(semantics.first.properties.label, contains('cycle lengths'));
    });

    testWidgets('offers the same numbers as a table', (tester) async {
      await seedHistory(db, const <int>[28, 30, 27, 29, 28, 31, 28]);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.insightsChartShowTable));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text(l10n.insightsChartColumnLength), findsOneWidget);
      expect(find.text(l10n.insightsChartLengthDays(30)), findsOneWidget);
    });

    testWidgets('says so plainly when there is not enough to chart', (
      tester,
    ) async {
      await pumpInsights(tester);
      expect(
        find.text(l10nOf(tester).insightsNotEnoughForStats),
        findsWidgets,
      );
    });
  });

  group('self-metrics', () {
    testWidgets('report the app own track record once there is one', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28, 28]);
      await pumpInsights(tester);
      final l10n = l10nOf(tester);
      await scrollToBottom(tester);
      expect(find.text(l10n.insightsTrackRecordTitle), findsOneWidget);
      // A model that reports its own error rate cannot quietly oversell
      // itself (2.4.5).
      expect(find.textContaining('within'), findsWidgets);
      expect(find.text(l10n.insightsTrackRecordExplain), findsOneWidget);
    });

    testWidgets('say nothing rather than inventing a score early on', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28]);
      await pumpInsights(tester);
      await scrollToBottom(tester);
      expect(
        find.text(l10nOf(tester).insightsTrackRecordNotYet),
        findsOneWidget,
      );
    });

    testWidgets('count logged days without a streak or a target', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28, 28], endingDaysAgo: 3);
      await pumpInsights(tester);
      await scrollToBottom(tester);
      expect(find.textContaining('You logged'), findsOneWidget);
      final copy = l10nOf(tester)
          .insightsLoggingCompleteness(20, 28)
          .toLowerCase();
      for (final word in <String>['streak', 'goal', 'target', 'keep it up']) {
        expect(copy, isNot(contains(word)));
      }
    });
  });

  group('layout', () {
    testWidgets('survives a 200% text scale', (tester) async {
      await seedHistory(db, const <int>[28, 30, 27, 29, 28, 31, 28]);
      await pumpInsights(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
    });
  });
}
