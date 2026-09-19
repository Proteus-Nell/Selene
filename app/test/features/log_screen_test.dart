// The friction budget (AND-13, docs/PLAN.md 2.4.2).
//
// Every budget in that table is a number, and these tests count taps against
// it. They matter for a reason that is not usability polish: sparse logs
// degrade prediction quality directly. A missed start becomes a merged
// pseudo-cycle, which the filter correctly reads as an outlier and answers by
// widening the interval, and enough of those return TooIrregular. Low friction
// is a data-quality requirement.
//
// The case being optimised is "I am two days late noticing", not the same-day
// happy path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/log/log_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpLog(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(const LogScreen(), database: db, textScaler: textScaler),
    );
    await tester.pumpAndSettle();
  }

  /// Brings [finder] into view and taps it, the way a person would.
  ///
  /// Scrolling is not a tap. The budgets in 2.4.2 count taps, and a screen that
  /// needs a scroll at 200% text scale has not spent one — a user at that scale
  /// scrolls on every screen they own. What would blow the budget is a scroll
  /// that cannot reach the control at all, and that fails here as a failed tap
  /// rather than passing quietly.
  Future<void> tapReachable(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // The three scales docs/PLAN.md 2.4.4 names. AND-23 tripled the number of
  // symptom chips, and chips reflow at scale, so a budget that holds at 100%
  // says nothing about 200% — which is the scale at which the layout was most
  // likely to have pushed something out of reach.
  const scales = <String, TextScaler>{
    '100%': TextScaler.noScaling,
    '150%': TextScaler.linear(1.5),
    '200%': TextScaler.linear(2),
  };

  for (final scale in scales.entries) {
    group('the tap budgets at ${scale.key} text scale', () {
      testWidgets('"period started today" costs one tap from the home screen', (
        tester,
      ) async {
        // Budget: 2 taps from cold start. The app opens straight onto today's
        // state, so the primary action is the only one needed.
        await pumpLog(tester, textScaler: scale.value);
        var taps = 0;

        await tapReachable(
          tester,
          find.text(l10nOf(tester).logPeriodStartedToday),
        );
        taps++;

        expect(taps, lessThanOrEqualTo(2));
        final logs = await db.dayLogDao.allLogs();
        expect(logs, hasLength(1));
        expect(logs.single.date, testClock.today());
        expect(logs.single.isBleedingDay, isTrue);
      });

      testWidgets('backdating one to three days costs two taps', (
        tester,
      ) async {
        // Budget: 3 taps. A stepper would cost one tap per day and blow it at
        // three, which is why the selector offers the days directly.
        for (final daysBack in <int>[1, 2, 3]) {
          await db.dayLogDao.deleteEverything();
          await pumpLog(tester, textScaler: scale.value);
          final l10n = l10nOf(tester);
          var taps = 0;

          final label = switch (daysBack) {
            1 => l10n.logDayYesterday,
            _ => l10n.logDaysAgo(daysBack),
          };
          await tapReachable(tester, find.text(label));
          taps++;
          await tapReachable(tester, find.textContaining(label).last);
          taps++;

          expect(taps, lessThanOrEqualTo(3), reason: '$daysBack days back');
          final logs = await db.dayLogDao.allLogs();
          expect(logs, hasLength(1), reason: '$daysBack days back');
          expect(
            logs.single.date,
            testClock.today().addDays(-daysBack),
            reason: '$daysBack days back',
          );
        }
      });

      testWidgets('logging a symptom for today costs one tap', (tester) async {
        // Budget: 4 taps. One tap records it at a moderate severity; the exact
        // level is a long-press away rather than on the critical path.
        //
        // Cramps is the first chip of the first section, so the sectioning
        // added in AND-23 cannot have put the most common symptom behind a
        // heading tap. That is the regression the task warned about: a section
        // that costs a tap to open is a section that costs a log.
        await pumpLog(tester, textScaler: scale.value);
        final l10n = l10nOf(tester);
        var taps = 0;

        await tapReachable(tester, find.text(l10n.logSymptomCramps));
        taps++;

        expect(taps, lessThanOrEqualTo(4));
        final logs = await db.dayLogDao.allLogs();
        expect(
          logs.single.severityOf(Symptom.cramps),
          SymptomSeverity.moderate,
        );
      });

      testWidgets('a symptom in the last section costs one tap too', (
        tester,
      ) async {
        // The worst case the sectioning creates: the final chip of the final
        // group, furthest from the top of the screen. Still one tap, because
        // the sections are headings rather than expanders.
        await pumpLog(tester, textScaler: scale.value);
        final l10n = l10nOf(tester);
        var taps = 0;

        await tapReachable(tester, find.text(l10n.logSymptomLowMood));
        taps++;

        expect(taps, lessThanOrEqualTo(4));
        final logs = await db.dayLogDao.allLogs();
        expect(
          logs.single.severityOf(Symptom.lowMood),
          SymptomSeverity.moderate,
        );
      });

      testWidgets('correcting a wrong entry costs two taps', (tester) async {
        // Budget: 3 taps. Here the entry is already open on today's screen, so
        // the correction is the flow chip plus nothing else.
        await db.dayLogDao.save(
          DayLog(date: testClock.today(), flow: FlowIntensity.heavy),
        );
        await pumpLog(tester, textScaler: scale.value);
        final l10n = l10nOf(tester);
        var taps = 0;

        await tapReachable(tester, find.text(l10n.logFlowLight));
        taps++;

        expect(taps, lessThanOrEqualTo(3));
        expect((await db.dayLogDao.allLogs()).single.flow, FlowIntensity.light);
      });
    });
  }

  group('the primary action', () {
    testWidgets('offers an undo rather than a confirmation', (tester) async {
      // A confirmation would cost every user a tap on every log to protect
      // against a mistake most of them will never make. Undo costs nothing
      // unless it is needed.
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      await tapReachable(tester, find.text(l10n.logPeriodStartedToday));
      expect(find.text(l10n.commonUndo), findsOneWidget);

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(await db.dayLogDao.allLogs(), isEmpty);
    });

    testWidgets('changes its label to name the day it will write', (
      tester,
    ) async {
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logPeriodStartedToday), findsOneWidget);
      await tapReachable(tester, find.text(l10n.logDayYesterday));
      expect(find.text(l10n.logPeriodStartedToday), findsNothing);
      expect(
        find.text(l10n.logPeriodStartedOnDay(l10n.logDayYesterday)),
        findsOneWidget,
      );
    });
  });

  group('the state line', () {
    testWidgets('says nothing is logged for a new user', (tester) async {
      await pumpLog(tester);
      expect(find.text(l10nOf(tester).logNothingLoggedYet), findsOneWidget);
    });

    testWidgets('counts the day of the cycle in progress', (tester) async {
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 2);
      await pumpLog(tester);
      // The run ends two days before today and started three days before
      // that, so today is day 6.
      expect(find.textContaining('6'), findsWidgets);
    });

    testWidgets('welcomes a returning user back without a word of guilt', (
      tester,
    ) async {
      // No streaks, no loss aversion, no "you missed 74 days" (2.4.1). A gap
      // may mean pregnancy, loss, illness, or simply not wanting to think
      // about it.
      await seedHistory(db, const <int>[28, 28], endingDaysAgo: 90);
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logWelcomeBack), findsOneWidget);
      final copy = l10n.logWelcomeBack.toLowerCase();
      for (final word in <String>[
        'streak',
        'missed',
        'forgot',
        'should',
        'lost',
      ]) {
        expect(copy, isNot(contains(word)), reason: 'copy said "$word"');
      }
    });
  });

  group('layout', () {
    testWidgets('survives a 200% text scale without overflowing', (
      tester,
    ) async {
      // Most Flutter layouts break here. An overflow throws during paint, so
      // pumping is the assertion.
      await pumpLog(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
    });
  });
}
