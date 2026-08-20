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

/// Runs the prediction model over stored logs and caches the result.
///
/// The cache is the only interesting thing here, and it is interesting for one
/// reason: **a stale prediction after a backdated correction is the subtle bug
/// this class exists to prevent** (`docs/ANDROID_TASKS.md`, AND-09). A user who
/// realises last month's start date was wrong, fixes it, and still sees the old
/// window has been told a falsehood by an app that had the right answer.
///
/// So the cache is keyed by a signature covering everything the computation
/// depends on, not by a timestamp or a cycle count. Editing any past day changes
/// the derived cycle lengths, which changes the signature, which misses the
/// cache. There is no invalidation call to forget, because nothing has to be
/// invalidated: a key that no longer matches is a key that no longer matches.
class PredictionRepository {
  /// Creates a repository over a database and a [CycleRepository].
  ///
  /// There is deliberately no clock here: everything date-relative goes through
  /// the cycle repository, so "now" has exactly one owner in the data layer.
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

  final AppDatabase _db;
  final CycleRepository _cycles;
  final ModelPriors _priors;
  final String _priorsVersion;
  final RingLogger? _logger;

  /// Version of the cache row format.
  ///
  /// Part of the signature, so a build that changes what the cache stores can
  /// never read a row written by the old shape.
  static const int cacheFormatVersion = 1;

  /// The current prediction, from cache when the inputs are unchanged.
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

    final sinceLastLog = await _cycles.daysSinceLastLog();
    if (sinceLastLog != null && sinceLastLog > CycleRules.lostTrackAfterDays) {
      // Extrapolating past this point produces a confident wrong answer, which
      // is worse than admitting the gap (`docs/PLAN.md` 5.5).
      return PredictionResult.lostTrack(
        statistics: statistics,
        daysSinceLastLog: sinceLastLog,
      );
    }

    // The cycle in progress is the anchor: the model predicts a start-to-start
    // length, so the next start is this cycle's start plus that length.
    final anchor = records.last.startDate;
    final lengths = CycleFeatures.usableLengths(records);
    final signature = _signatureOf(lengths: lengths, anchor: anchor);

    final cached = await _db.modelStateDao.matching(signature);
    if (cached != null) {
      _logger?.info(LogEvent.predictionCacheHit);
      return _resultFrom(
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
        anchor: anchor,
        statistics: statistics,
        lengths: lengths,
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
    return _resultFrom(
      windows: prediction.windows,
      confidence: prediction.confidence,
      personalised: prediction.refit.personalised,
      anchor: anchor,
      statistics: statistics,
      lengths: lengths,
    );
  }

  /// The cached posterior, or null when nothing usable is cached.
  ///
  /// Exposed for the Tier B gate and for tests. Callers that just want a
  /// prediction should use [current], which recomputes when this is stale.
  Future<FilterState?> cachedPosterior() async {
    final row = await _db.modelStateDao.current();
    if (row == null) return null;
    return FilterState(
      mean: row.stateMean,
      variance: row.stateVariance,
      nObs: row.stateObservations,
    );
  }

  /// Drops the cache.
  ///
  /// Not needed for correctness: a changed input already misses the signature.
  /// It exists for the cases where correctness is not the question, such as the
  /// user deleting everything and not wanting a stale row left behind.
  Future<void> invalidate() async {
    await _db.modelStateDao.clear();
    _logger?.info(LogEvent.predictionInvalidated);
  }

  /// Everything the prediction depends on, in one canonical string.
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
  String _signatureOf({
    required List<int> lengths,
    required CivilDate anchor,
  }) => <String>[
    'v$cacheFormatVersion',
    _priorsVersion,
    'anchor=${anchor.epochDay}',
    'lengths=${lengths.join(",")}',
  ].join('|');

  PredictionResult _resultFrom({
    required PredictionWindows windows,
    required ConfidenceClass confidence,
    required bool personalised,
    required CivilDate anchor,
    required CycleStatistics statistics,
    required List<int> lengths,
  }) {
    if (confidence == ConfidenceClass.tooIrregular) {
      // No window at all rather than a wide one presented as a prediction. The
      // statistics still go back, so this is never a dead end (risk R17).
      return PredictionResult.tooIrregular(statistics: statistics);
    }

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
