/// Predictive intervals.
///
/// Turns a predictive distribution into the whole-day windows the app shows,
/// and classifies how tight those windows are. Lengths, not dates: anchoring
/// them to a calendar belongs to the repository.
///
/// Pipeline:
///     1. Refit the variances to this user, unless told not to.
///     2. Run the filter over the history with those variances.
///     3. Read five quantiles off the resulting forecast, in whole days.
///     4. Classify the 80% width into a confidence class.
///
/// Includes:
///     - ConfidenceClass: How tight the 80% window is, including the band
///       where no window may be shown.
///     - PredictionWindows: The five day figures.
///     - HistoryPrediction: One whole run of the pipeline.
///     - Intervals: The pipeline itself.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/personalize.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// Confidence class: how tightly the model can pin the next cycle length.
///
/// Distinct from [Confidence] in `domain/models/prediction.dart`, which has no
/// `tooIrregular` member on purpose: at that width the app must not show a
/// window at all, so the state is a separate [PredictionResult] variant rather
/// than a confidence label on a prediction. [toConfidence] is the bridge, and
/// it returns null exactly when the caller must build a
/// [PredictionResult.tooIrregular] instead.
///
/// Attributes:
///     wireName (String): The name this class carries in the golden
///         vectors.
enum ConfidenceClass {
  /// 80% window narrower than [ConfidenceThresholds.highBelowDays].
  high('high'),

  /// 80% window narrower than [ConfidenceThresholds.mediumBelowDays].
  medium('medium'),

  /// 80% window narrower than [ConfidenceThresholds.lowBelowDays].
  low('low'),

  /// 80% window at or beyond [ConfidenceThresholds.lowBelowDays].
  ///
  /// Not an error. It is the state where the app shows the user their own
  /// statistics instead of a window, and it must never be a dead end (risk
  /// R17).
  tooIrregular('too_irregular');

  const ConfidenceClass(this.wireName);

  /// The name this class carries in the golden vectors.
  ///
  /// Spelled out rather than derived from [name], because the artifact uses
  /// `too_irregular` and a Dart identifier cannot.
  final String wireName;

  /// Convert to the [Confidence] the UI carries.
  ///
  /// Returns:
  ///     Confidence?: The equivalent, or null for
  ///     [ConfidenceClass.tooIrregular], which is exactly when the caller
  ///     must build a [PredictionResult.tooIrregular] instead.
  Confidence? toConfidence() => switch (this) {
    ConfidenceClass.high => Confidence.high,
    ConfidenceClass.medium => Confidence.medium,
    ConfidenceClass.low => Confidence.low,
    ConfidenceClass.tooIrregular => null,
  };
}

/// Prediction windows: a predicted cycle length and its windows, in whole
/// days.
///
/// Lengths, not dates. Anchoring them to a calendar needs the user's last
/// period start, which lives in the data layer; that conversion belongs to the
/// repository (AND-09), so this file stays pure model output.
///
/// Attributes:
///     medianDays (int): Cycle length at the predictive median.
///     lo50 (int): Lower bound of the 50% window.
///     hi50 (int): Upper bound of the 50% window.
///     lo80 (int): Lower bound of the 80% window.
///     hi80 (int): Upper bound of the 80% window.
@immutable
final class PredictionWindows {
  /// Creates a window set.
  ///
  /// Args:
  ///     medianDays (int): Cycle length at the predictive median.
  ///     lo50 (int): Lower bound of the 50% window.
  ///     hi50 (int): Upper bound of the 50% window.
  ///     lo80 (int): Lower bound of the 80% window.
  ///     hi80 (int): Upper bound of the 80% window.
  const PredictionWindows({
    required this.medianDays,
    required this.lo50,
    required this.hi50,
    required this.lo80,
    required this.hi80,
  });

  /// Cycle length at the predictive median.
  final int medianDays;

  /// Lower bound of the 50% window.
  final int lo50;

  /// Upper bound of the 50% window.
  final int hi50;

  /// Lower bound of the 80% window.
  final int lo80;

  /// Upper bound of the 80% window.
  final int hi80;

  /// Width of the 80% window in days, counted inclusively.
  ///
  /// This is the headline uncertainty figure and the input to
  /// [Intervals.confidenceClass].
  int get width80 => hi80 - lo80 + 1;

  /// Width of the 50% window in days, counted inclusively.
  int get width50 => hi50 - lo50 + 1;

  /// Whether the windows nest correctly around the median.
  ///
  /// Always true for a correct filter, and asserted in tests rather than
  /// assumed: a sign error in a quantile would show up here first.
  bool get isCoherent =>
      lo80 <= lo50 && lo50 <= medianDays && medianDays <= hi50 && hi50 <= hi80;

  @override
  bool operator ==(Object other) =>
      other is PredictionWindows &&
      other.medianDays == medianDays &&
      other.lo50 == lo50 &&
      other.hi50 == hi50 &&
      other.lo80 == lo80 &&
      other.hi80 == hi80;

  @override
  int get hashCode => Object.hash(medianDays, lo50, hi50, lo80, hi80);

  @override
  String toString() =>
      'PredictionWindows(median: $medianDays, 50%: $lo50..$hi50, '
      '80%: $lo80..$hi80)';
}

/// History prediction: everything one run of the pipeline produces.
///
/// Carries the intermediate results, not just the windows, because the callers
/// need them: [refit] tells the UI whether the model is tuned to this user,
/// [state] is what the prediction cache persists (AND-09), and [forecast] is
/// what `explain.dart` reasons over.
///
/// Attributes:
///     refit (RefitResult): The refit that chose the variances.
///     state (FilterState): Posterior after the last observation.
///     forecast (Forecast): One-step-ahead distribution, on the log scale.
///     windows (PredictionWindows): The day windows shown to the user.
///     confidence (ConfidenceClass): Implied by the 80% width.
@immutable
final class HistoryPrediction {
  /// Creates a pipeline result.
  ///
  /// Args:
  ///     refit (RefitResult): The refit that chose the variances.
  ///     state (FilterState): Posterior after the last observation.
  ///     forecast (Forecast): One-step-ahead distribution, on the log scale.
  ///     windows (PredictionWindows): The day windows shown to the user.
  ///     confidence (ConfidenceClass): Implied by the 80% width.
  const HistoryPrediction({
    required this.refit,
    required this.state,
    required this.forecast,
    required this.windows,
    required this.confidence,
  });

  /// The refit that chose the variances this prediction ran with.
  final RefitResult refit;

  /// Posterior after the last observation.
  final FilterState state;

  /// One-step-ahead predictive distribution on the log scale.
  final Forecast forecast;

  /// The day windows shown to the user.
  final PredictionWindows windows;

  /// Confidence class implied by [PredictionWindows.width80].
  final ConfidenceClass confidence;

  @override
  bool operator ==(Object other) =>
      other is HistoryPrediction &&
      other.refit == refit &&
      other.state == state &&
      other.forecast == forecast &&
      other.windows == windows &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(refit, state, forecast, windows, confidence);

  @override
  String toString() =>
      'HistoryPrediction(windows: $windows, confidence: ${confidence.name}, '
      'personalised: ${refit.personalised})';
}

/// Intervals: turns a predictive distribution into the windows the app shows.
///
/// Port of the portable half of `research/src/cyclecore/models/intervals.py`.
/// The half that is not ported is `student_t_quantiles`, which needs SciPy and
/// runs offline; its output ships in `priors_v1.json` as
/// [ModelPriors.quantiles]. That split is the entire reason this file is pure
/// arithmetic.
abstract final class Intervals {
  /// Convert a posterior into day windows.
  ///
  /// Args:
  ///     state (FilterState): The posterior to forecast from.
  ///     priors (FilterPriors): The priors the filter ran with.
  ///     quantiles (QuantileTable): The shipped Student-t quantiles.
  ///
  /// Returns:
  ///     PredictionWindows: The five day figures.
  static PredictionWindows windowsFromState(
    FilterState state,
    FilterPriors priors,
    QuantileTable quantiles,
  ) {
    final fc = BayesFilter.forecast(state, priors);
    return windowsFromForecast(fc, quantiles);
  }

  /// Convert a predictive distribution into day windows.
  ///
  /// Split out from [windowsFromState] so a caller that already holds the
  /// forecast, as [forHistory] does, cannot accidentally recompute it from a
  /// different set of priors than the ones the filter ran with.
  ///
  /// Args:
  ///     fc (Forecast): The predictive distribution.
  ///     quantiles (QuantileTable): The shipped Student-t quantiles.
  ///
  /// Returns:
  ///     PredictionWindows: The five day figures, each rounded through
  ///     [BayesFilter.daysFromLog].
  static PredictionWindows windowsFromForecast(
    Forecast fc,
    QuantileTable quantiles,
  ) => PredictionWindows(
    medianDays: BayesFilter.daysFromLog(
      BayesFilter.predictiveQuantile(fc, quantiles[QuantileLevel.p50]),
    ),
    lo50: BayesFilter.daysFromLog(
      BayesFilter.predictiveQuantile(fc, quantiles[QuantileLevel.p25]),
    ),
    hi50: BayesFilter.daysFromLog(
      BayesFilter.predictiveQuantile(fc, quantiles[QuantileLevel.p75]),
    ),
    lo80: BayesFilter.daysFromLog(
      BayesFilter.predictiveQuantile(fc, quantiles[QuantileLevel.p10]),
    ),
    hi80: BayesFilter.daysFromLog(
      BayesFilter.predictiveQuantile(fc, quantiles[QuantileLevel.p90]),
    ),
  );

  /// Run the full pipeline over a history, exactly as the app does.
  ///
  /// Personalisation comes first, because the refit chooses the variances the
  /// filter then runs with.
  ///
  /// Args:
  ///     cycleLengths (`List<int>`): Observed lengths, oldest first.
  ///     priors (ModelPriors): The shipped priors, quantiles and thresholds.
  ///     personalise (bool, optional): Whether to refit first. Defaults to
  ///         true. Set false only to reproduce the pre-personalisation
  ///         behaviour for comparison in tests; shipping that path would make
  ///         interval width independent of how variable the user actually is,
  ///         which is the defect recorded in `personalize.dart`.
  ///
  /// Returns:
  ///     HistoryPrediction: The refit, the posterior, the forecast, the
  ///     windows and the confidence class.
  static HistoryPrediction forHistory(
    List<int> cycleLengths,
    ModelPriors priors, {
    bool personalise = true,
  }) {
    final refit = personalise
        ? Personalize.refitUser(
            cycleLengths,
            priors.filterPriors,
            priors.personalisation,
          )
        : RefitResult(
            priors: priors.filterPriors,
            obsSd: math.sqrt(priors.filterPriors.obsVar),
            driftSd: math.sqrt(priors.filterPriors.driftVar),
            score: double.negativeInfinity,
            personalised: false,
            nCycles: cycleLengths.length,
          );
    final state = BayesFilter.filterSequence(cycleLengths, refit.priors).last;
    final fc = BayesFilter.forecast(state, refit.priors);
    final windows = windowsFromForecast(fc, priors.quantiles);
    return HistoryPrediction(
      refit: refit,
      state: state,
      forecast: fc,
      windows: windows,
      confidence: confidenceClass(windows.width80, priors.confidenceThresholds),
    );
  }

  /// Classify confidence from the width of the 80% window.
  ///
  /// Args:
  ///     width80Days (int): The window width, counted inclusively.
  ///     thresholds (ConfidenceThresholds): The shipped cut points.
  ///
  /// Returns:
  ///     ConfidenceClass: The band it falls in.
  ///     [ConfidenceClass.tooIrregular] is not a failure: it is the app
  ///     refusing to state a narrow window it cannot support, which is the
  ///     single most important product rule here (`docs/PLAN.md` 6.2).
  static ConfidenceClass confidenceClass(
    int width80Days,
    ConfidenceThresholds thresholds,
  ) {
    if (width80Days < thresholds.highBelowDays) return ConfidenceClass.high;
    if (width80Days < thresholds.mediumBelowDays) return ConfidenceClass.medium;
    if (width80Days < thresholds.lowBelowDays) return ConfidenceClass.low;
    return ConfidenceClass.tooIrregular;
  }
}
