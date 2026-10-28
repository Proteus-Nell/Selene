import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

void main() {
  late AppDatabase db;
  late CycleRepository cycles;
  late PredictionRepository predictions;
  late FixedClock clock;

  /// Logs a history whose observed cycle lengths are [lengths], with the last
  /// bleeding day landing [endingDaysAgo] before today. Returns the most recent
  /// period start, which is the anchor every predicted date is measured from.
  ///
  /// Bleeding days are placed so none of them lands in the future: the
  /// repository refuses future-dated writes, so a helper that ignored that
  /// would quietly log one period fewer than the test asked for.
  Future<CivilDate> logHistory(
    List<int> lengths, {
    int endingDaysAgo = 0,
    int bleedingDays = 4,
  }) async {
    final total = lengths.fold<int>(0, (sum, length) => sum + length);
    final lastStart = clock.today().addDays(
      -endingDaysAgo - (bleedingDays - 1),
    );
    var start = lastStart.addDays(-total);
    for (final length in lengths) {
      await cycles.logPeriod(
        CivilDateRange(start, start.addDays(bleedingDays - 1)),
      );
      start = start.addDays(length);
    }
    await cycles.logPeriod(
      CivilDateRange(lastStart, lastStart.addDays(bleedingDays - 1)),
    );
    return lastStart;
  }

  /// A regular history of [completedCycles] observations, 28 days apart.
  Future<CivilDate> logRegularHistory({
    required int completedCycles,
    int endingDaysAgo = 0,
  }) => logHistory(
    List<int>.filled(completedCycles, 28),
    endingDaysAgo: endingDaysAgo,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock.iso('2026-06-30');
    cycles = CycleRepository(database: db, clock: clock);
    predictions = PredictionRepository(database: db, cycles: cycles);
  });

  tearDown(() => db.close());

  group('with nothing logged', () {
    test('returns noData rather than inventing an anchor', () async {
      // The model predicts a cycle length. Turning that into a date needs a
      // logged start; anchoring on today would assert the period started today.
      expect(await predictions.current(), isA<NoData>());
    });
  });

  group('with a short history', () {
    test(
      'returns the population prior, labelled as not personalised',
      () async {
        await logRegularHistory(completedCycles: 2);
        final result = await predictions.current();
        expect(result, isA<InsufficientData>());
        final insufficient = result as InsufficientData;
        expect(insufficient.cyclesLogged, 2);
        expect(insufficient.populationPrior.basis.usedPopulationPrior, isTrue);
        expect(
          insufficient.populationPrior.basis.personalizedHyperparameters,
          isFalse,
        );
      },
    );

    test('dates the window from the most recent period start', () async {
      final lastStart = await logRegularHistory(completedCycles: 2);
      final result = await predictions.current() as InsufficientData;
      final prediction = result.populationPrior;
      // The model predicts a start-to-start length, so the predicted date is
      // the anchor plus that length. Measuring from anything else would be
      // measuring from a day the user never told the app about.
      expect(lastStart.daysBetween(prediction.medianStart), closeTo(28, 2));
      expect(prediction.isCoherent, isTrue);
      expect(
        prediction.window80.lengthInDays,
        greaterThanOrEqualTo(prediction.window50.lengthInDays),
      );
    });
  });

  group('with a settled history', () {
    test('returns a personalised prediction', () async {
      final lastStart = await logRegularHistory(completedCycles: 7);
      final result = await predictions.current();
      expect(result, isA<Predicted>());
      final predicted = result as Predicted;
      expect(predicted.prediction.basis.personalizedHyperparameters, isTrue);
      expect(predicted.prediction.confidence, Confidence.high);
      expect(predicted.statistics.completedCycles, 7);
      expect(predicted.statistics.medianLengthDays, 28);
      expect(lastStart.daysBetween(predicted.prediction.medianStart), 28);
    });
  });

  group('with a very variable history', () {
    test('refuses a window and hands back the statistics instead', () async {
      // Alternating 26/34, the case that must not be narrowed to look
      // confident (risk R17).
      await logHistory(const <int>[26, 34, 26, 34, 26, 34], endingDaysAgo: 3);

      final result = await predictions.current();
      expect(result, isA<TooIrregular>());
      // Never a dead end: the user still gets their own numbers back.
      final irregular = result as TooIrregular;
      expect(irregular.statistics.completedCycles, 6);
      expect(irregular.statistics.observedSpreadDays, 8);
    });
  });

  group('once the window has opened with no period logged', () {
    /// The prediction as it stood [daysEarlier] days ago, before the window
    /// opened, for comparing against. The logs end well before then, so the
    /// earlier clock is not one that went backwards.
    Future<Prediction> asFirstPredicted({required int daysEarlier}) async {
      final earlier = PredictionRepository(
        database: db,
        cycles: CycleRepository(
          database: db,
          clock: FixedClock(clock.today().addDays(-daysEarlier)),
        ),
      );
      return (await earlier.current() as Predicted).prediction;
    }

    test('moves the windows forward past the days already gone', () async {
      // Day 29 of a 28-day history: inside the window, and past its first day.
      final lastStart = await logRegularHistory(
        completedCycles: 7,
        endingDaysAgo: 25,
      );
      expect(lastStart.daysBetween(clock.today()), 28);
      final original = await asFirstPredicted(daysEarlier: 20);
      final moved = (await predictions.current() as Predicted).prediction;

      expect(moved.window80.start, greaterThanOrEqualTo(clock.today()));
      expect(moved.window50.start, greaterThanOrEqualTo(clock.today()));
      expect(moved.medianStart, greaterThanOrEqualTo(clock.today()));
      expect(moved.isCoherent, isTrue);
      expect(moved.originalWindow80, original.window80);
      expect(moved.expectedWindow80, original.window80);
      // Inside the window first predicted, so not late yet.
      expect(moved.isLate, isFalse);
      expect(original.originalWindow80, isNull);
    });

    test(
      'says how late once past the window, and keeps the range ahead',
      () async {
        await logRegularHistory(completedCycles: 7, endingDaysAgo: 30);
        final moved = (await predictions.current() as Predicted).prediction;
        final expectedEnd = moved.expectedWindow80.end;
        expect(clock.today(), greaterThan(expectedEnd));
        expect(moved.daysLate, expectedEnd.daysBetween(clock.today()));
        expect(moved.isLate, isTrue);
        expect(moved.window80.start, greaterThanOrEqualTo(clock.today()));
        // Wider than the window it moved from: lateness is uncertainty.
        expect(
          moved.window80.lengthInDays,
          greaterThan(moved.expectedWindow80.lengthInDays),
        );
      },
    );

    test('gives no range once a moved one would be too wide to help', () async {
      // Day 51 of a 28-day history. The range moved forward this far is wider
      // than the app will draw for an irregular history, so it is not drawn
      // for a late period either; the window it was expected in still is.
      await logRegularHistory(completedCycles: 7, endingDaysAgo: 47);
      final original = await asFirstPredicted(daysEarlier: 40);
      final result = await predictions.current();
      expect(result, isA<LaterThanExpected>());
      final late = result as LaterThanExpected;
      expect(late.expectedWindow80, original.window80);
      expect(
        late.daysLate,
        original.window80.end.daysBetween(clock.today()),
      );
      expect(late.statistics.completedCycles, 7);
    });

    test('moves a cached fit to the same days as a fresh one', () async {
      // The move depends on the day, so it is applied on top of the cache
      // rather than stored in it. A hit rebuilds the forecast from the stored
      // posterior; this pins that the rebuilt one is the one the miss used.
      await logRegularHistory(completedCycles: 7, endingDaysAgo: 27);
      final miss = await predictions.current();
      expect(await predictions.cachedPosterior(), isNotNull);
      final hit = await predictions.current();
      expect(hit, miss);
      expect((hit as Predicted).prediction.originalWindow80, isNotNull);
    });

    test('moves a population prior forward too', () async {
      await logRegularHistory(completedCycles: 2, endingDaysAgo: 28);
      final result = await predictions.current();
      expect(result, isA<InsufficientData>());
      final prior = (result as InsufficientData).populationPrior;
      expect(prior.originalWindow80, isNotNull);
      expect(prior.window80.start, greaterThanOrEqualTo(clock.today()));
    });

    test('leaves the windows alone before the window opens', () async {
      await logRegularHistory(completedCycles: 7, endingDaysAgo: 10);
      final prediction = (await predictions.current() as Predicted).prediction;
      expect(prediction.originalWindow80, isNull);
      expect(prediction.daysLate, 0);
    });
  });

  group('after a long time without a period', () {
    test('admits it lost track instead of extrapolating', () async {
      final lastStart = await logRegularHistory(
        completedCycles: 3,
        endingDaysAgo: CycleRules.lostTrackAfterDays + 5,
      );
      final result = await predictions.current();
      expect(result, isA<LostTrack>());
      final lost = result as LostTrack;
      expect(lost.daysSinceLastPeriod, lastStart.daysBetween(clock.today()));
      // Losing track must not lose the user their history.
      expect(lost.statistics.completedCycles, 3);
    });

    test(
      'counts from the last period, not from the last log of any kind',
      () async {
        // Someone who logs a symptom every day but has not logged a period in
        // ten weeks. Counting from any log, this was "any day now" for as long
        // as the logging went on.
        final lastStart = await logRegularHistory(
          completedCycles: 6,
          endingDaysAgo: 67,
        );
        for (
          var day = lastStart.addDays(4);
          day <= clock.today();
          day = day.addDays(1)
        ) {
          await cycles.add(
            DayLog(
              date: day,
              symptoms: const <Symptom, SymptomSeverity>{
                Symptom.headache: SymptomSeverity.mild,
              },
            ),
          );
        }
        expect(await cycles.daysSinceLastLog(), 0);
        final result = await predictions.current();
        expect(result, isA<LostTrack>());
        expect(
          (result as LostTrack).daysSinceLastPeriod,
          lastStart.daysBetween(clock.today()),
        );
      },
    );

    test('does not mistake a long cycle for a lost one', () async {
      // Cycles of about nine weeks. Day 62 is past the count but inside the
      // window this history predicts, so the window still stands.
      final lastStart = await logHistory(
        const <int>[60, 61, 59, 60, 61, 60, 59],
        endingDaysAgo: 58,
      );
      expect(
        lastStart.daysBetween(clock.today()) + 1,
        greaterThan(CycleRules.lostTrackAfterDays),
      );
      final result = await predictions.current();
      expect(result, isA<Predicted>());
      final prediction = (result as Predicted).prediction;
      expect(prediction.expectedWindow80.end, greaterThan(clock.today()));
      expect(prediction.isLate, isFalse);
    });

    test('still predicts on the last day of the count', () async {
      // Day 60 of the cycle predicts, day 61 does not: the same day the ring
      // stops counting, pinned so the two cannot drift a day apart.
      await logRegularHistory(
        completedCycles: 3,
        endingDaysAgo: CycleRules.lostTrackAfterDays - 4,
      );
      expect(await predictions.current(), isNot(isA<LostTrack>()));

      await db.dayLogDao.deleteEverything();
      await logRegularHistory(
        completedCycles: 3,
        endingDaysAgo: CycleRules.lostTrackAfterDays - 3,
      );
      expect(await predictions.current(), isA<LostTrack>());
    });
  });

  group('when the device clock moves backwards', () {
    test('reports inconsistent data rather than a negative cycle', () async {
      await logRegularHistory(completedCycles: 2);
      final rewound = PredictionRepository(
        database: db,
        cycles: CycleRepository(
          database: db,
          clock: FixedClock(clock.today().addDays(-40)),
        ),
      );
      final result = await rewound.current();
      expect(result, isA<DataInconsistent>());
      expect(
        (result as DataInconsistent).reason,
        DataInconsistency.clockWentBackwards,
      );
    });
  });

  group('the cache', () {
    test('is reused when nothing changed', () async {
      await logRegularHistory(completedCycles: 7);
      final first = await predictions.current();
      expect(await predictions.cachedPosterior(), isNotNull);
      expect(await predictions.current(), first);
    });

    test('is invalidated by a backdated edit to any past day', () async {
      // The bug this whole class exists to prevent: a user corrects last
      // month's start date and still sees the old window.
      final lastStart = await logRegularHistory(completedCycles: 7);
      final before = await predictions.current() as Predicted;
      final signatureBefore =
          (await db.modelStateDao.current())!.inputSignature;

      // Move one old period start two days earlier. Note that the median cycle
      // length does not move: the edit shortens one cycle and lengthens the
      // next. A cache keyed on a summary statistic would sail straight past
      // this, which is why it is keyed on the whole input.
      final oldStart = lastStart.addDays(-28 * 3);
      await cycles.deleteDay(oldStart);
      await cycles.add(
        DayLog(date: oldStart.addDays(-2), flow: FlowIntensity.medium),
      );

      final after = await predictions.current();
      expect(after, isNot(before));
      expect(
        (await db.modelStateDao.current())!.inputSignature,
        isNot(signatureBefore),
      );
    });

    test('is invalidated when the anchor moves', () async {
      // End the history far enough back that today opens a new cycle rather
      // than extending the last bleeding episode: a bleeding day logged a few
      // days after a period start belongs to that same period, and correctly
      // moves nothing.
      final lastStart = await logRegularHistory(
        completedCycles: 7,
        endingDaysAgo: 24,
      );
      final before = await predictions.current() as Predicted;

      await cycles.add(DayLog(date: clock.today(), flow: FlowIntensity.medium));

      final after = await predictions.current() as Predicted;
      expect(clock.today().daysBetween(lastStart), lessThan(0));
      expect(after.statistics.completedCycles, 8);
      // A new anchor moves every predicted date, even though the observed
      // lengths barely changed.
      expect(
        after.prediction.medianStart,
        isNot(before.prediction.medianStart),
      );
      expect(clock.today().daysBetween(after.prediction.medianStart), 28);
    });

    test('is invalidated when the shipped priors change', () async {
      // An app update that ships new priors makes every cached prediction wrong
      // even though the user's history has not moved by a day.
      await logRegularHistory(completedCycles: 7);
      await predictions.current();
      final row = await db.modelStateDao.current();
      expect(await db.modelStateDao.matching(row!.inputSignature), isNotNull);

      final withNewPriors = PredictionRepository(
        database: db,
        cycles: cycles,
        priorsVersion: 'a-different-priors-artifact',
      );
      await withNewPriors.current();
      expect(
        (await db.modelStateDao.current())!.inputSignature,
        isNot(row.inputSignature),
      );
    });

    test('can be dropped explicitly', () async {
      await logRegularHistory(completedCycles: 7);
      await predictions.current();
      expect(await predictions.cachedPosterior(), isNotNull);
      await predictions.invalidate();
      expect(await predictions.cachedPosterior(), isNull);
      // And recomputing still works.
      expect(await predictions.current(), isA<Predicted>());
    });

    test('holds the posterior, not just the windows', () async {
      await logRegularHistory(completedCycles: 7);
      await predictions.current();
      final posterior = await predictions.cachedPosterior();
      expect(posterior!.nObs, 7);
      // log(28) is about 3.33: the posterior really is on the log scale.
      expect(posterior.mean, closeTo(3.33, 0.05));
      expect(posterior.variance, greaterThan(0));
    });
  });

  group('riverpod wiring', () {
    test('repositories are overridable in tests', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);

      await logRegularHistory(completedCycles: 7);
      expect(
        await container.read(predictionProvider.future),
        isA<Predicted>(),
      );
    });

    test('the database provider refuses to guess', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(appDatabaseProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
