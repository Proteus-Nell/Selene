import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';

/// Assigns a [CycleValidity] to each segmented cycle.
///
/// The governing principle: **flag, never drop**. A cycle the user entered stays
/// in the database, stays visible on the calendar, and stays correctable. All a
/// flag does is stop the prediction model treating it as a clean observation.
/// Silently discarding user data is how an app loses trust, and it also hides
/// the mis-log that caused the flag, so the user never learns to fix it.
///
/// See `docs/PLAN.md` 5.5 and risk R17.
abstract final class Validation {
  /// Returns [cycles] with validity assigned, preserving order.
  ///
  /// Runs in two stages, because they need different information:
  ///
  /// 1. **Absolute plausibility.** Anything outside
  ///    [CycleRules.minPlausibleCycleDays]..[CycleRules.maxPlausibleCycleDays]
  ///    is flagged regardless of who the user is.
  /// 2. **Relative plausibility.** Among the cycles that survive stage one, one
  ///    that is a strong outlier against this user's own median and MAD is
  ///    flagged for confirmation.
  ///
  /// Stage two runs only with at least
  /// [CycleRules.minCyclesForOutlierDetection] plausible observations, and it
  /// deliberately uses only the *plausible* cycles to compute the baseline. Using
  /// all of them would let a single mis-logged 120 day cycle inflate the spread
  /// enough to mask genuine outliers.
  static List<CycleRecord> assign(Iterable<CycleRecord> cycles) {
    final stageOne = <CycleRecord>[
      for (final cycle in cycles) cycle.copyWith(validity: _absolute(cycle)),
    ];

    final baseline = <double>[
      for (final cycle in stageOne)
        if (cycle.isComplete && cycle.validity == CycleValidity.ok)
          cycle.lengthInDays!.toDouble(),
    ];

    if (baseline.length < CycleRules.minCyclesForOutlierDetection) {
      return stageOne;
    }

    final centre = CycleFeatures.median(baseline);
    final mad = CycleFeatures.medianAbsoluteDeviation(baseline);

    // A MAD of zero means a perfectly regular history. Any deviation at all is
    // then infinitely many MADs away, which would flag a single 29 day cycle in
    // a run of 28s. That is not a data problem, so outlier detection is skipped.
    if (mad == 0) return stageOne;

    return <CycleRecord>[
      for (final cycle in stageOne)
        if (cycle.validity == CycleValidity.ok && cycle.isComplete)
          cycle.copyWith(
            validity: _relative(cycle.lengthInDays!, centre, mad),
          )
        else
          cycle,
    ];
  }

  /// The modified z-score of [lengthDays] against a [centre] and [mad].
  ///
  /// Uses median and MAD rather than mean and standard deviation because with
  /// fewer than a dozen observations a single mis-log would dominate a standard
  /// deviation. Returns 0 when [mad] is 0, since no deviation is measurable.
  static double modifiedZScore(int lengthDays, double centre, double mad) {
    if (mad == 0) return 0;
    return (lengthDays - centre).abs() / (CycleRules.madToSigma * mad);
  }

  /// Whether [lengthDays] is inside the absolute plausibility band.
  static bool isPlausibleLength(int lengthDays) =>
      lengthDays >= CycleRules.minPlausibleCycleDays &&
      lengthDays <= CycleRules.maxPlausibleCycleDays;

  static CycleValidity _absolute(CycleRecord cycle) {
    final length = cycle.lengthInDays;
    // An in-progress cycle has no length to judge. It is not an observation
    // either way, so leave it alone rather than inventing a verdict.
    if (length == null) return CycleValidity.ok;
    if (length < CycleRules.minPlausibleCycleDays) {
      return CycleValidity.implausiblyShort;
    }
    if (length > CycleRules.maxPlausibleCycleDays) {
      return CycleValidity.implausiblyLong;
    }
    return CycleValidity.ok;
  }

  static CycleValidity _relative(int lengthDays, double centre, double mad) {
    final z = modifiedZScore(lengthDays, centre, mad);
    return z > CycleRules.outlierModifiedZThreshold
        ? CycleValidity.unconfirmedOutlier
        : CycleValidity.ok;
  }
}
