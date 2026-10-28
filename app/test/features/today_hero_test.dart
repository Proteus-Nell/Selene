// The home screen's hero: the ring, the countdown and the legend (AND-39).
//
// Two rules run through all of it and neither is a matter of taste.
//
// `docs/PLAN.md` 6.2 forbids a bare date. The countdown in the middle of the
// ring is the shortest thing on the screen and therefore the likeliest place
// for that rule to erode into "your period starts in 3 days", so it is pinned
// here: it is derived from the 80% window and it is always a range.
//
// ADR-0007 keeps ovulation estimation behind an explicit opt-in. The ring has a
// band for it, which means the ring is now a way that estimate could reach
// someone who never asked. It must not, and the default must be the safe one
// even for the frame before the preference has loaded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/today/cycle_ring.dart';

import 'harness.dart';

/// Six cycles of 28 days: a window first predicted on days 28 to 30.
const List<int> _sixRegular = <int>[28, 28, 28, 28, 28, 28];

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(const LogScreen(), database: db, textScaler: textScaler),
    );
    await tester.pumpAndSettle();
  }

  /// The bands the ring was actually asked to draw.
  List<RingBand> bandsOf(WidgetTester tester) =>
      tester.widget<CycleRing>(find.byType(CycleRing)).bands;

  group('the countdown', () {
    testWidgets('is a range, never a single day', (tester) async {
      await seedHistory(db, const <int>[28, 28, 28, 28, 28, 28]);
      await pump(tester);
      final l10n = l10nOf(tester);

      // Whatever the numbers, it renders through the range string. A future
      // author reaching for "in 3 days" has to delete this to do it.
      final ranged = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        final data = widget.data;
        return data != null && data.contains('–');
      });
      expect(
        ranged,
        findsWidgets,
        reason: 'the countdown collapsed to one number',
      );
      expect(find.text(l10n.logCountdownCaption), findsOneWidget);
    });

    testWidgets('says so plainly when there is nothing to count from', (
      tester,
    ) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownNothingYet), findsOneWidget);
      expect(find.text(l10n.logCountdownNothingYetCaption), findsOneWidget);
    });

    // Six cycles of 28 days put the window first predicted on days 28 to 30 of
    // the cycle, the 27th to the 29th day after it started (the golden case
    // regular_six_identical). Each test below moves the last start back to
    // land today somewhere against that window.

    testWidgets('is "any day now" inside the window, moved or not', (
      tester,
    ) async {
      // Day 29: past the window's first day, so the range has moved forward.
      // The countdown still reads the window first predicted.
      await seedHistory(db, _sixRegular, endingDaysAgo: 25);
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownNow), findsOneWidget);
      expect(find.text(l10n.logCountdownNowCaption), findsOneWidget);
    });

    testWidgets('says it is later than expected once past the window', (
      tester,
    ) async {
      // Day 34, four days past the window's last day.
      await seedHistory(db, _sixRegular, endingDaysAgo: 30);
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownLater), findsOneWidget);
      expect(find.text(l10n.logCountdownLaterCaption(4)), findsOneWidget);
      expect(find.text(l10n.logCountdownNow), findsNothing);
      // The panel under it gives the moved range as a rough guide, and does
      // not claim four in five for it.
      expect(find.text(l10n.insightsLateRange), findsOneWidget);
      expect(find.text(l10n.insightsFourInFive), findsNothing);
    });

    testWidgets('still says how late once no range is left to give', (
      tester,
    ) async {
      // Day 51. A range moved this far would be too wide to draw.
      await seedHistory(db, _sixRegular, endingDaysAgo: 47);
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownLater), findsOneWidget);
      expect(find.text(l10n.logCountdownLaterCaption(21)), findsOneWidget);
      expect(find.text(l10n.insightsLaterTitle), findsOneWidget);
    });

    testWidgets('admits it lost track, even with something logged every day', (
      tester,
    ) async {
      // The case that used to read "any day now" for as long as it went on: a
      // symptom logged every day, and no period logged in ten weeks.
      final lastStart = await seedHistory(db, _sixRegular, endingDaysAgo: 67);
      final today = testClock.today();
      await db.dayLogDao.saveAll(<DayLog>[
        for (var day = lastStart.addDays(4); day <= today; day = day.addDays(1))
          DayLog(
            date: day,
            symptoms: const <Symptom, SymptomSeverity>{
              Symptom.headache: SymptomSeverity.mild,
            },
          ),
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownLostTrack), findsOneWidget);
      expect(find.text(l10n.logCountdownLostTrackCaption), findsOneWidget);
      expect(find.text(l10n.logCountdownNow), findsNothing);
      expect(find.text(l10n.insightsLostTrackTitle), findsOneWidget);
    });

    testWidgets('does not ask for a first period from someone who has logged '
        'many', (tester) async {
      // Too irregular for a range is not the same as nothing logged.
      await seedHistory(
        db,
        const <int>[26, 34, 26, 34, 26, 34],
        endingDaysAgo: 3,
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logCountdownNoRange), findsOneWidget);
      expect(find.text(l10n.logCountdownNothingYetCaption), findsNothing);
    });
  });

  group('the ovulation band', () {
    testWidgets('is absent by default', (tester) async {
      // The default is a safety property rather than a taste: an estimate
      // nobody opted into is the thing 6.2 exists to prevent.
      await seedHistory(db, const <int>[28, 28, 28]);
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logLegendOvulation), findsNothing);
      expect(
        bandsOf(tester)
            .where((band) => band.label == l10n.logLegendOvulation)
            .single
            .days,
        0,
        reason: 'the band was drawn without the opt-in',
      );
    });

    testWidgets('appears only once the user has opted in', (tester) async {
      await seedHistory(db, const <int>[28, 28, 28]);
      await db.settingsDao.writeBool(
        SettingKey.showOvulationWindow,
        value: true,
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logLegendOvulation), findsOneWidget);
      expect(
        bandsOf(tester)
            .where((band) => band.label == l10n.logLegendOvulation)
            .single
            .days,
        greaterThan(0),
      );
    });

    testWidgets('is taken out of the follicular phase, not added on', (
      tester,
    ) async {
      // Otherwise turning it on would make the ring add up to more than a
      // cycle, and the phases either side would shrink to make room for an
      // estimate rather than the estimate sitting inside the days it covers.
      //
      // Both a roomy cycle and one with no room at all. The short case is the
      // one that caught a real bug: the band was a fixed five days, so on a
      // 21-day cycle with a 7-day period — where a 14-day luteal phase leaves
      // nothing between — the follicular phase clamped to zero while the band
      // stayed five, and the total grew by five days that cycle did not have.
      for (final history in const <(String, List<int>, int)>[
        ('a roomy cycle', <int>[28, 28, 28], 4),
        ('no room at all', <int>[21, 21, 21], 7),
      ]) {
        await db.dayLogDao.deleteEverything();
        await db.settingsDao.writeBool(
          SettingKey.showOvulationWindow,
          value: false,
        );
        await seedHistory(db, history.$2, bleedingDays: history.$3);
        await pump(tester);
        final without = bandsOf(
          tester,
        ).fold<double>(0, (sum, band) => sum + band.days);

        await db.settingsDao.writeBool(
          SettingKey.showOvulationWindow,
          value: true,
        );
        await tester.pumpAndSettle();
        final with_ = bandsOf(
          tester,
        ).fold<double>(0, (sum, band) => sum + band.days);

        expect(with_, closeTo(without, 0.001), reason: history.$1);
      }
    });
  });

  group('the phase note', () {
    testWidgets('names the phase and explains it on tap', (tester) async {
      // The sentence is the same on every visit and the screen under it is
      // what somebody opened the app to use, so it sits behind a tap. What
      // must not happen is the name appearing with no way to find out what it
      // means: "luteal" is a word most people have not been given a
      // definition for.
      await seedHistory(db, const <int>[28, 28, 28]);
      await pump(tester);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.calendarPhasePeriod), findsWidgets);
      expect(
        find.text(l10n.calendarPhasePeriodExplained),
        findsNothing,
        reason: 'the explanation is printed rather than offered',
      );

      await tester.ensureVisible(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.calendarPhasePeriodExplained), findsOneWidget);

      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.calendarPhasePeriodExplained), findsNothing);
    });

    testWidgets('is absent when the app will not name a phase', (tester) async {
      // Nothing logged means no phase, and a row offering to explain one that
      // was never named would be a dead end.
      await pump(tester);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('the ring', () {
    testWidgets('names every band it draws, and draws every band it names', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28, 28]);
      await db.settingsDao.writeBool(
        SettingKey.showOvulationWindow,
        value: true,
      );
      await pump(tester);
      // One list feeds both, so a legend cannot name a band the ring does not
      // have. This checks that they are literally the same objects.
      final drawn = bandsOf(tester).where((band) => band.days > 0).toList();
      final legend = tester.widget<RingLegend>(find.byType(RingLegend)).bands;
      expect(
        legend.where((band) => band.days > 0).toList(),
        drawn,
      );
      for (final band in drawn) {
        await tester.ensureVisible(find.text(band.label).first);
        expect(find.text(band.label), findsWidgets, reason: band.label);
      }
    });

    testWidgets('gives way to its own text at a large scale', (tester) async {
      // A circle is a fixed box and text inside one is not. Above the
      // threshold the ring goes and the words stay, which is the right way
      // round: the ring never carried anything the words did not.
      //
      // Scoped to the ring's own painter. `find.byType(CustomPaint)` over the
      // whole tree is not an assertion about anything — Flutter paints half a
      // screen through CustomPaint, so it answers findsWidgets either way.
      final ringPainter = find.descendant(
        of: find.byType(CycleRing),
        matching: find.byType(CustomPaint),
      );

      await seedHistory(db, const <int>[28, 28, 28]);
      await pump(tester);
      expect(ringPainter, findsOneWidget, reason: 'no ring at 100%');

      await pump(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
      expect(ringPainter, findsNothing, reason: 'the ring outstayed its box');
      // What it gave way to is still there.
      expect(find.byType(CycleRing), findsOneWidget);
      expect(find.byType(RingLegend), findsOneWidget);
      expect(
        find.text(l10nOf(tester).logCountdownCaption),
        findsOneWidget,
      );
    });

    testWidgets('paints in the scheme the app is wearing', (tester) async {
      await seedHistory(db, const <int>[28, 28, 28]);
      await pump(tester);
      // The harness renders the default scheme, so this is the check that the
      // colours come off the theme rather than out of a constant somewhere.
      expect(
        bandsOf(tester).first.color,
        AppScheme.fallback.light.menstrual,
      );
    });
  });
}
