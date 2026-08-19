import 'package:meta/meta.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// How accurate this app's own predictions have turned out to be.
///
/// Reported to the user rather than to a dashboard, because there is no
/// dashboard: no analytics, no server, nothing transmitted (`docs/PLAN.md`
/// 2.4.5).
@immutable
final class TrackRecord {
  /// Creates a track record.
  const TrackRecord({
    required this.predictions,
    required this.withinTolerance,
    required this.toleranceDays,
    required this.meanAbsoluteErrorDays,
  });

  /// How many past cycles were scored.
  final int predictions;

  /// How many of those landed within [toleranceDays] of the real length.
  final int withinTolerance;

  /// The tolerance the score is quoted against.
  final int toleranceDays;

  /// Average absolute error in days across the scored predictions.
  final double meanAbsoluteErrorDays;

  @override
  bool operator ==(Object other) =>
      other is TrackRecord &&
      other.predictions == predictions &&
      other.withinTolerance == withinTolerance &&
      other.toleranceDays == toleranceDays &&
      other.meanAbsoluteErrorDays == meanAbsoluteErrorDays;

  @override
  int get hashCode => Object.hash(
    predictions,
    withinTolerance,
    toleranceDays,
    meanAbsoluteErrorDays,
  );

  @override
  String toString() =>
      'TrackRecord($withinTolerance/$predictions within ${toleranceDays}d, '
      'MAE ${meanAbsoluteErrorDays.toStringAsFixed(2)}d)';
}

/// Scores the model against the user's own history, on device.
///
/// This is the structural counterweight to overclaiming (`docs/PLAN.md` 6.2): a
/// model that continuously reports its own error rate cannot quietly oversell
/// itself. It builds justified trust when the model is good and warns the user
/// when it is not, which is more useful than either a confident number or
/// silence.
///
/// The evaluation is a rolling-origin backtest, the same shape as the one the
/// research side runs, but over one user and with no stored history of past
/// predictions: cycle `i` is predicted from cycles `0..i-1` only, so every
/// score is genuinely out of sample. Recomputing rather than storing means the
/// figures cannot go stale after an edit, and there is nothing extra on disk.
abstract final class SelfMetrics {
  /// Days either side that count as a hit.
  ///
  /// Two days is the figure the app quotes. It is a judgement about what makes
  /// a prediction useful to a person planning around it, not a statistical
  /// threshold.
  static const int defaultToleranceDays = 2;

  /// How many recent predictions the headline covers.
  static const int defaultRecentPredictions = 5;

  /// Cycles needed before the model is scored at all.
  ///
  /// Below this the only predictions available came from the population prior
  /// with almost nothing to go on, and scoring them tells the user about the
  /// prior rather than about their own model.
  static const int minCyclesForScoring = 3;

  /// Scores the model over [cycleLengths], oldest first.
  ///
  /// Returns null when there is not yet enough history to say anything honest.
  static TrackRecord? evaluate(
    List<int> cycleLengths,
    ModelPriors priors, {
    int recent = defaultRecentPredictions,
    int toleranceDays = defaultToleranceDays,
  }) {
    if (cycleLengths.length < minCyclesForScoring) return null;

    final errors = <int>[];
    // Start at 1: predicting the very first cycle from no history at all is the
    // population prior, and the user did not ask about the population.
    for (var i = 1; i < cycleLengths.length; i++) {
      final history = cycleLengths.sublist(0, i);
      final predicted = Intervals.forHistory(
        history,
        priors,
      ).windows.medianDays;
      errors.add((predicted - cycleLengths[i]).abs());
    }
    if (errors.isEmpty) return null;

    final scored = errors.length <= recent
        ? errors
        : errors.sublist(errors.length - recent);
    final hits = scored.where((e) => e <= toleranceDays).length;
    final total = scored.fold<int>(0, (sum, e) => sum + e);

    return TrackRecord(
      predictions: scored.length,
      withinTolerance: hits,
      toleranceDays: toleranceDays,
      meanAbsoluteErrorDays: total / scored.length,
    );
  }
}
