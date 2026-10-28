/// Prediction repository and cache.
///
/// Runs the prediction model over the stored logs and caches the result, keyed
/// by a signature covering every input. A backdated correction changes that
/// signature and so misses the cache, which is the whole point: there is no
/// invalidation call to forget.
///
/// Pipeline:
///     1. Refuse outright if the device clock has gone backwards.
///     2. Derive the usable cycle lengths and the anchor day.
///     3. Build the signature and look for a cache row matching it.
///     4. On a miss, run the filter and store the new row.
///     5. Once the window has opened with no period logged, move it forward
///        past the days already gone (ADR-0016). That step depends on the
///        day, so it is applied to the cached fit rather than cached itself.
///
/// Includes:
///     - PredictionRepository: The pipeline, the cache and its signature.
library;

import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/model_state_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

/// One fit of the model: the windows as first predicted, and what they came
/// from.
typedef _Fit = ({
  PredictionWindows windows,
  ConfidenceClass confidence,
  bool personalised,
  Forecast forecast,
});

/// Prediction repository: runs the model and caches the result.
///
/// The cache is the only interesting thing here, and it is interesting for one
/// reason: **a stale prediction after a backdated correction is the subtle bug
/// this class exists to prevent** (`docs/ANDROID_TASKS.md`, AND-09). A user
/// who realises last month's start date was wrong, fixes it, and still sees
/// the old window has been told a falsehood by an app that had the right
/// answer.
///
/// So the cache is keyed by a signature covering everything the computation
/// depends on, not by a timestamp or a cycle count. Editing any past day
/// changes the derived cycle lengths, which changes the signature, which
/// misses the cache. There is no invalidation call to forget, because nothing
/// has to be invalidated: a key that no longer matches is a key that no longer
/// matches.
///
/// Attributes:
///     _db (AppDatabase): Where the cache row lives.
///     _cycles (CycleRepository): Supplies the logs, the cycles and "now".
///     _priors (ModelPriors): The priors the filter runs with.
///     _priorsVersion (String): Checksum of those priors, part of the key.
///     _logger (RingLogger?): Records cache hits, misses and refusals.
class PredictionRepository {
  /// Creates a repository over a database and a [CycleRepository].
  ///
  /// There is deliberately no clock here: everything date-relative goes
  /// through the cycle repository, so "now" has exactly one owner in the data
  /// layer.
  ///
  /// Args:
  ///     database (AppDatabase): Where the cache row lives.
  ///     cycles (CycleRepository): Supplies the logs, cycles and "now".
  ///     priors (ModelPriors, optional): Defaults to [bundledPriors].
  ///     priorsVersion (String, optional): Checksum of those priors.
  ///         Defaults to [priorsArtifactSha256].
  ///     logger (RingLogger?, optional): Defaults to null.
  PredictionRepository({
    required AppDatabase database,
    required CycleRepository cycles,
    ModelPriors priors = bundledPriors,
    String priorsVersion = priorsArtifactSha256,
    RingLogger? logger,
  }) : _db = database,
       // An initializing formal would have to be `this._cycles` and the rest,
       // and Dart does not allow a named parameter to start with an underscore.
       // ignore: prefer_initializing_formals
       _cycles = cycles,
       // ignore: prefer_initializing_formals, same reason as above
       _priors = priors,
       // ignore: prefer_initializing_formals, same reason as above
       _priorsVersion = priorsVersion,
       // ignore: prefer_initializing_formals, same reason as above
       _logger = logger;

  /// Where the cache row lives.
  final AppDatabase _db;

  /// Supplies the logs, the cycles and "now".
  final CycleRepository _cycles;

  /// The priors the filter runs with.
  final ModelPriors _priors;

  /// Checksum of those priors. Part of the cache key.
  final String _priorsVersion;

  /// Records cache hits, misses and refusals. Never what was logged.
  final RingLogger? _logger;

  /// Version of the cache row format.
  ///
  /// Part of the signature, so a build that changes what the cache stores can
  /// never read a row written by the old shape.
  static const int cacheFormatVersion = 1; // part of the signature

  /// Return the current prediction, from cache when the inputs are unchanged.
  ///
  /// Returns:
  ///     `Future<PredictionResult>`: One of the union's cases. Never throws
  ///     for an unpredictable history: every such state is a case.
  Future<PredictionResult> current() async {
    if (await _cycles.clockWentBackwards()) {
      _logger?.warn(LogEvent.clockWentBackwards);
      return const PredictionResult.dataInconsistent(
        reason: DataInconsistency.clockWentBackwards,
      );
    }

    final segmented = await _cycles.cycles();
    if (segmented.isErr) {
      return PredictionResult.dataInconsistent(reason: segmented.errorOrNull!);
    }
    final records = segmented.valueOrNull!;
    if (records.isEmpty) return const PredictionResult.noData();

    final statistics = CycleFeatures.summarise(records);

    // Checked before the cache and before the filter, and the order matters.
    //
    // This is not a state the model failed to reach. The model would reach a
    // perfectly good answer, and showing it would be wrong. Predicting a period
    // for someone who has told the app they are pregnant is a confident,
    // specific claim contradicting something they entered themselves. So the
    // question is asked first, and the filter is simply not run.
    //
    // Only pregnancy. Hormonal contraception often removes true cycles entirely
    // and is the obvious next candidate; it was considered and not chosen
    // (ADR-0010). The rule lives in Condition.suppressesPrediction and nowhere
    // else, so adding a second suppressing condition is one edit in one place
    // rather than a search through the repository.
    final suppressing = (await _cycles.activeConditionsOn(_cycles.today()))
        .where((record) => record.condition.suppressesPrediction)
        .firstOrNull;
    if (suppressing != null) {
      return PredictionResult.suppressedByCondition(
        condition: suppressing.condition,
        // The user's own history travels with the refusal. A pregnancy ends,
        // and the cycles logged before it are still theirs to see.
        statistics: statistics,
      );
    }

    // The cycle in progress is the anchor: the model predicts a start-to-start
    // length, so the next start is this cycle's start plus that length.
    final anchor = records.last.startDate;
    final lengths = CycleFeatures.usableLengths(records);
    final fit = await _fit(lengths: lengths, anchor: anchor);

    final today = _cycles.today();
    final elapsed = anchor.daysBetween(today);
    final expected = CivilDateRange(
      anchor.addDays(fit.windows.lo80),
      anchor.addDays(fit.windows.hi80),
    );

    // Counted from the start of the last logged period rather than from the
    // last log of any kind, so that logging symptoms every day cannot hold a
    // window open for a period that was never logged. And only once the
    // window first predicted has passed as well, so that someone whose cycles
    // run long is not told the app has lost track of a cycle it expected to
    // be long (ADR-0016). Extrapolating past this point produces a confident
    // wrong answer, which is worse than admitting the gap (`docs/PLAN.md`
    // 5.5). The day count is the one the ring stops showing at, so the two
    // cannot disagree.
    if (elapsed + 1 > CycleRules.lostTrackAfterDays && today > expected.end) {
      return PredictionResult.lostTrack(
        statistics: statistics,
        daysSinceLastPeriod: elapsed,
      );
    }

    if (fit.confidence == ConfidenceClass.tooIrregular) {
      // No window at all rather than a wide one presented as a prediction. The
      // statistics still go back, so this is never a dead end (risk R17).
      return PredictionResult.tooIrregular(statistics: statistics);
    }

    final daysLate = today > expected.end ? expected.end.daysBetween(today) : 0;
    if (elapsed <= fit.windows.lo80) {
      return _resultFrom(
        windows: fit.windows,
        confidence: fit.confidence,
        personalised: fit.personalised,
        anchor: anchor,
        statistics: statistics,
        lengths: lengths,
      );
    }

    // The window has opened and no period has been logged, so part of it is
    // already in the past. The days gone by are evidence that this cycle is
    // at least that long, and the windows are moved forward on it rather than
    // left reaching back into days that are known not to have been the start.
    final moved = Intervals.conditionedWindows(
      fit.forecast,
      elapsed,
      _priors.filterPriors.studentTDf,
    );
    final movedConfidence = moved == null
        ? ConfidenceClass.tooIrregular
        : Intervals.confidenceClass(
            moved.width80,
            _priors.confidenceThresholds,
          );
    if (movedConfidence == ConfidenceClass.tooIrregular) {
      // Too wide to be a useful range. Inside the window that was first
      // predicted, that window still stands and is shown unmoved. Past it, the
      // app says how late the period is instead of drawing a range it would
      // refuse to draw for an irregular history.
      if (daysLate == 0) {
        return _resultFrom(
          windows: fit.windows,
          confidence: fit.confidence,
          personalised: fit.personalised,
          anchor: anchor,
          statistics: statistics,
          lengths: lengths,
        );
      }
      return PredictionResult.laterThanExpected(
        expectedWindow80: expected,
        daysLate: daysLate,
        statistics: statistics,
      );
    }
    return _resultFrom(
      windows: moved!,
      confidence: movedConfidence,
      personalised: fit.personalised,
      anchor: anchor,
      statistics: statistics,
      lengths: lengths,
      originalWindow80: expected,
      daysLate: daysLate,
    );
  }

  /// Fit the model to a history, or read the fit from the cache.
  ///
  /// Args:
  ///     lengths (`List<int>`): The usable cycle lengths, oldest first.
  ///     anchor (CivilDate): The start of the cycle in progress.
  ///
  /// Returns:
  ///     `Future<_Fit>`: The windows as first predicted, their confidence,
  ///     whether the refit ran, and the forecast they were read from.
  Future<_Fit> _fit({
    required List<int> lengths,
    required CivilDate anchor,
  }) async {
    final signature = _signatureOf(lengths: lengths, anchor: anchor);

    final cached = await _db.modelStateDao.matching(signature);
    if (cached != null) {
      _logger?.info(LogEvent.predictionCacheHit);
      // The forecast is rebuilt from the stored posterior and variances
      // exactly as the refit built it, squares and all, so a cache hit moves
      // a late window to the same days as a miss would.
      final priors = cached.personalised
          ? _priors.filterPriors.withVariances(
              obsVar: cached.obsSd * cached.obsSd,
              driftVar: cached.driftSd * cached.driftSd,
            )
          : _priors.filterPriors;
      return (
        windows: PredictionWindows(
          medianDays: cached.medianDays,
          lo50: cached.lo50,
          hi50: cached.hi50,
          lo80: cached.lo80,
          hi80: cached.hi80,
        ),
        confidence: ConfidenceClass.values.firstWhere(
          (c) => c.wireName == cached.confidence,
        ),
        personalised: cached.personalised,
        forecast: BayesFilter.forecast(
          FilterState(
            mean: cached.stateMean,
            variance: cached.stateVariance,
            nObs: cached.stateObservations,
          ),
          priors,
        ),
      );
    }

    final prediction = Intervals.forHistory(lengths, _priors);
    await _db.modelStateDao.store(
      ModelStateRow(
        id: ModelStateDao.singletonId,
        inputSignature: signature,
        stateMean: prediction.state.mean,
        stateVariance: prediction.state.variance,
        stateObservations: prediction.state.nObs,
        obsSd: prediction.refit.obsSd,
        driftSd: prediction.refit.driftSd,
        personalised: prediction.refit.personalised,
        medianDays: prediction.windows.medianDays,
        lo50: prediction.windows.lo50,
        hi50: prediction.windows.hi50,
        lo80: prediction.windows.lo80,
        hi80: prediction.windows.hi80,
        confidence: prediction.confidence.wireName,
      ),
    );
    _logger?.info(
      LogEvent.predictionComputed,
      fields: <String, LogField>{
        'n_cycles': LogField.count(lengths.length),
        'confidence': LogField.state(prediction.confidence),
        'personalised': LogField.flag(prediction.refit.personalised),
      },
    );
    return (
      windows: prediction.windows,
      confidence: prediction.confidence,
      personalised: prediction.refit.personalised,
      forecast: prediction.forecast,
    );
  }

  /// Read the cached posterior.
  ///
  /// Exposed for the Tier B gate and for tests. Callers that just want a
  /// prediction should use [current], which recomputes when this is stale.
  ///
  /// Returns:
  ///     `Future<FilterState?>`: The stored posterior, or null when nothing
  ///     is cached. Does not check the signature, so it may be stale.
  Future<FilterState?> cachedPosterior() async {
    final row = await _db.modelStateDao.current();
    if (row == null) return null;
    return FilterState(
      mean: row.stateMean,
      variance: row.stateVariance,
      nObs: row.stateObservations,
    );
  }

  /// Drop the cache.
  ///
  /// Not needed for correctness: a changed input already misses the signature.
  /// It exists for the cases where correctness is not the question, such as
  /// the user deleting everything and not wanting a stale row left behind.
  Future<void> invalidate() async {
    await _db.modelStateDao.clear();
    _logger?.info(LogEvent.predictionInvalidated);
  }

  /// Build the cache key: everything the prediction depends on.
  ///
  /// Deliberately the full input rather than a digest of it. A digest would be
  /// shorter and would introduce a collision risk whose only symptom is the
  /// exact bug this signature exists to prevent, and the string is a few
  /// hundred bytes even for a decade of cycles.
  ///
  /// The priors version is in here because a shipped priors change makes every
  /// cached prediction wrong even when the user's history has not moved by a
  /// day. Without it, upgrading the app would leave old predictions in place
  /// until the next edit.
  ///
  /// Args:
  ///     lengths (`List<int>`): The usable cycle lengths, oldest first.
  ///     anchor (CivilDate): The day the prediction is measured from.
  ///
  /// Returns:
  ///     String: The signature, pipe-separated and stable across runs.
  String _signatureOf({
    required List<int> lengths,
    required CivilDate anchor,
  }) => <String>[
    'v$cacheFormatVersion',
    _priorsVersion,
    'anchor=${anchor.epochDay}',
    'lengths=${lengths.join(",")}',
  ].join('|');

  /// Turn a computed window set into the union case the UI renders.
  ///
  /// Args:
  ///     windows (PredictionWindows): The day figures to show.
  ///     confidence (ConfidenceClass): How tight the 80% window is. Never
  ///         [ConfidenceClass.tooIrregular], which the caller has already
  ///         turned into a state with no window.
  ///     personalised (bool): Whether the refit ran for this user.
  ///     anchor (CivilDate): The day the windows are measured from.
  ///     statistics (CycleStatistics): The user's own summary figures.
  ///     lengths (`List<int>`): The usable lengths the model saw.
  ///     originalWindow80 (CivilDateRange?, optional): The 80% window as
  ///         first predicted, when [windows] have moved forward from it.
  ///         Defaults to null.
  ///     daysLate (int, optional): Days past the end of that window.
  ///         Defaults to 0.
  ///
  /// Returns:
  ///     PredictionResult: A prediction anchored to a date.
  PredictionResult _resultFrom({
    required PredictionWindows windows,
    required ConfidenceClass confidence,
    required bool personalised,
    required CivilDate anchor,
    required CycleStatistics statistics,
    required List<int> lengths,
    CivilDateRange? originalWindow80,
    int daysLate = 0,
  }) {
    final prediction = Prediction(
      medianStart: anchor.addDays(windows.medianDays),
      window50: CivilDateRange(
        anchor.addDays(windows.lo50),
        anchor.addDays(windows.hi50),
      ),
      window80: CivilDateRange(
        anchor.addDays(windows.lo80),
        anchor.addDays(windows.hi80),
      ),
      confidence: confidence.toConfidence()!,
      basis: PredictionBasis(
        cyclesUsed: lengths.length,
        medianLengthDays:
            statistics.medianLengthDays ?? windows.medianDays.toDouble(),
        variabilityDays: statistics.medianAbsoluteDeviationDays ?? 0,
        usedPopulationPrior: !personalised,
        personalizedHyperparameters: personalised,
      ),
      originalWindow80: originalWindow80,
      daysLate: daysLate,
    );

    // Personalisation is the dividing line, not a cycle count: below the refit
    // threshold the interval width is the population's rather than this user's,
    // and the UI has to say so rather than passing it off as personal.
    return personalised
        ? PredictionResult.predicted(
            prediction: prediction,
            statistics: statistics,
          )
        : PredictionResult.insufficientData(
            populationPrior: prediction,
            cyclesLogged: lengths.length,
          );
  }
}
