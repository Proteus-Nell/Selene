import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/personalize.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// How tightly the model can pin the next cycle length.
///
/// Distinct from [Confidence] in `domain/models/prediction.dart`, which has no
/// `tooIrregular` member on purpose: at that width the app must not show a
/// window at all, so the state is a separate [PredictionResult] variant rather
/// than a confidence label on a prediction. [toConfidence] is the bridge, and
/// it returns null exactly when the caller must build a
/// [PredictionResult.tooIrregular] instead.
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

  /// The equivalent [Confidence], or null when no window may be shown.
  Confidence? toConfidence() => switch (this) {
    ConfidenceClass.high => Confidence.high,
    ConfidenceClass.medium => Confidence.medium,
    ConfidenceClass.low => Confidence.low,
    ConfidenceClass.tooIrregular => null,
  };
}

/// A predicted next cycle length and its windows, all in whole days.
///
/// Lengths, not dates. Anchoring them to a calendar needs the user's last
/// period start, which lives in the data layer; that conversion belongs to the
/// repository (AND-09), so this file stays pure model output.
@immutable
final class PredictionWindows {
  /// Creates a window set.
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

/// Everything one run of the prediction pipeline produces.
///
/// Carries the intermediate results, not just the windows, because the callers
/// need them: [refit] tells the UI whether the model is tuned to this user,
/// [state] is what the prediction cache persists (AND-09), and [forecast] is
/// what `explain.dart` reasons over.
@immutable
final class HistoryPrediction {
  /// Creates a pipeline result.
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

/// Turns a predictive distribution into the day windows the app shows.
///
/// Port of the portable half of `research/src/cyclecore/models/intervals.py`.
/// The half that is not ported is `student_t_quantiles`, which needs SciPy and
/// runs offline; its output ships in `priors_v1.json` as
/// [ModelPriors.quantiles]. That split is the entire reason this file is pure
/// arithmetic.
abstract final class Intervals {
  /// Converts a posterior into day windows.
  static PredictionWindows windowsFromState(
    FilterState state,
    FilterPriors priors,
    QuantileTable quantiles,
  ) {
    final fc = BayesFilter.forecast(state, priors);
    return windowsFromForecast(fc, quantiles);
  }

  /// Converts a predictive distribution into day windows.
  ///
  /// Split out from [windowsFromState] so a caller that already holds the
  /// forecast, as [forHistory] does, cannot accidentally recompute it from a
  /// different set of priors than the ones the filter ran with.
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

  /// Runs the full pipeline over [cycleLengths], exactly as the app does.
  ///
  /// Personalisation comes first, because the refit chooses the variances the
  /// filter then runs with. Set [personalise] to false only to reproduce the
  /// pre-personalisation behaviour for comparison in tests; shipping that path
  /// would make interval width independent of how variable the user actually
  /// is, which is the defect recorded in `personalize.dart`.
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

  /// Classifies confidence from the width of the 80% window.
  ///
  /// [ConfidenceClass.tooIrregular] is not a failure: it is the app refusing to
  /// state a narrow window it cannot support, which is the single most
  /// important product rule here (`docs/PLAN.md` 6.2).
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
