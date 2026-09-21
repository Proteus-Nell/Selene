/// Cycle summary statistics.
///
/// Reduces a user's own cycles to the robust figures the rest of the app reads
/// from: a median length, a spread, the extremes, and a regularity class over
/// them. Median and median absolute deviation throughout, never mean and
/// standard deviation.
///
/// Includes:
///     - RegularityClass: How settled the lengths are.
///     - CycleFeatures: The statistics and the robust estimators behind them.
library;

import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// Regularity class: how settled a user's cycle lengths are.
///
/// Drives copy and the decision to refuse a narrow prediction. Deliberately
/// framed as a property of the data, never of the person: the UI must say
/// "your cycles have varied by about 6 days", never anything resembling a
/// verdict. See `docs/PLAN.md` 6.2 and 6.4.
enum RegularityClass {
  /// Fewer than two completed cycles, so variability is unknowable.
  unknown,

  /// Median absolute deviation within [CycleRules.regularMadDays].
  regular,

  /// Median absolute deviation within [CycleRules.variableMadDays].
  variable,

  /// Median absolute deviation beyond [CycleRules.variableMadDays].
  irregular,
}

/// Cycle features: robust summary statistics over a user's own cycles.
///
/// Median and median absolute deviation are used throughout in preference to
/// mean and standard deviation. With a handful of observations, one mis-logged
/// 60 day pseudo-cycle moves a mean enormously and a median barely at all, and
/// mis-logged cycles are common.
abstract final class CycleFeatures {
  /// Summarise a history into statistics, using only usable observations.
  ///
  /// A cycle counts only if it is complete and its validity is
  /// [CycleValidity.ok]. Flagged cycles stay visible to the user but do not
  /// shape the statistics that feed the model.
  ///
  /// Args:
  ///     cycles (`Iterable<CycleRecord>`): The segmented, validated cycles.
  ///
  /// Returns:
  ///     CycleStatistics: The summary, or [CycleStatistics.empty] when
  ///     nothing is usable yet.
  static CycleStatistics summarise(Iterable<CycleRecord> cycles) {
    final lengths = usableLengths(cycles);
    if (lengths.isEmpty) return CycleStatistics.empty;

    final med = median(lengths.map((l) => l.toDouble()).toList());
    return CycleStatistics(
      completedCycles: lengths.length,
      medianLengthDays: med,
      medianAbsoluteDeviationDays: medianAbsoluteDeviation(
        lengths.map((l) => l.toDouble()).toList(),
      ),
      shortestLengthDays: lengths.reduce((a, b) => a < b ? a : b),
      longestLengthDays: lengths.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Return the lengths of every usable observation, oldest first.
  ///
  /// Args:
  ///     cycles (`Iterable<CycleRecord>`): The segmented, validated cycles.
  ///
  /// Returns:
  ///     `List<int>`: Lengths in days, in the order the cycles were given.
  static List<int> usableLengths(Iterable<CycleRecord> cycles) => <int>[
    for (final cycle in cycles)
      if (cycle.isUsableObservation) cycle.lengthInDays!,
  ];

  /// Classify how settled a history is.
  ///
  /// Args:
  ///     statistics (CycleStatistics): The summary to classify.
  ///
  /// Returns:
  ///     RegularityClass: [RegularityClass.unknown] below two completed
  ///     cycles, otherwise the band the spread falls in.
  static RegularityClass classify(CycleStatistics statistics) {
    final mad = statistics.medianAbsoluteDeviationDays;
    if (statistics.completedCycles < 2 || mad == null) {
      return RegularityClass.unknown;
    }
    if (mad <= CycleRules.regularMadDays) return RegularityClass.regular;
    if (mad <= CycleRules.variableMadDays) return RegularityClass.variable;
    return RegularityClass.irregular;
  }

  /// Return the median of a list.
  ///
  /// For an even count this is the mean of the two central values, so the
  /// result is a double even though cycle lengths are whole days.
  ///
  /// Args:
  ///     values (`List<double>`): The observations. Not modified.
  ///
  /// Returns:
  ///     double: The median.
  ///
  /// Throws:
  ///     ArgumentError: If [values] is empty, rather than inventing a value.
  static double median(List<double> values) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'cannot be empty');
    }
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// Return the median absolute deviation of a list.
  ///
  /// `median(|x - median(x)|)`
  ///
  /// Args:
  ///     values (`List<double>`): The observations. Not modified.
  ///
  /// Returns:
  ///     double: The deviation. Zero for a perfectly regular history, which
  ///     is correct and must not be treated as missing data.
  ///
  /// Throws:
  ///     ArgumentError: If [values] is empty.
  static double medianAbsoluteDeviation(List<double> values) {
    final centre = median(values);
    return median(values.map((v) => (v - centre).abs()).toList());
  }

  /// Return the most recent usable lengths, oldest first.
  ///
  /// Used by the baselines the model must beat, and by the trailing-window
  /// variants of the statistics.
  ///
  /// Args:
  ///     cycles (`Iterable<CycleRecord>`): The segmented, validated cycles.
  ///     count (int): How many to keep. Must be positive.
  ///
  /// Returns:
  ///     `List<int>`: Up to [count] lengths, oldest first. Shorter when the
  ///     history has fewer.
  ///
  /// Throws:
  ///     ArgumentError: If [count] is zero or negative.
  static List<int> recentUsableLengths(
    Iterable<CycleRecord> cycles,
    int count,
  ) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be positive');
    }
    final all = usableLengths(cycles);
    return all.length <= count ? all : all.sublist(all.length - count);
  }
}
