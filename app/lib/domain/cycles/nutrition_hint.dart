/// Nutrition hint rule.
///
/// Decides whether the app has grounds to mention one logged pattern: heavy
/// flow and moderate-or-worse fatigue recorded on the same day, often enough,
/// recently enough. Says nothing about nutrients, deficiencies or supplements,
/// and produces a bool rather than a score.
///
/// Includes:
///     - NutritionHints: The thresholds and the two predicates over them.
library;

import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Nutrition hints: whether a logged pattern is worth mentioning.
///
/// One hint, one condition, and deliberately no more. The app is looking at
/// two things the user recorded themselves, heavy flow and fatigue on the same
/// day, and the only thing it says about them is that the pattern is worth
/// raising with a clinician. It names no nutrient, no deficiency and no
/// supplement.
///
/// The line this walks is in `docs/PLAN.md` 6.2. *"Heavy menstrual bleeding is
/// a recognised cause of iron loss"* is a statement about physiology and
/// belongs in the reference text. *"You are low in iron"* is a diagnosis of a
/// person, from data that cannot support one, and belongs nowhere in this app.
/// Observing what the user logged and pointing at a human is on the right side
/// of that line; naming a cause is not.
abstract final class NutritionHints {
  /// How many coinciding days are needed before the hint appears.
  ///
  /// A judgement call with no source behind it, and it exists to stop the app
  /// saying something every month. One heavy, tired day is an ordinary period.
  /// A prompt that fires on every cycle is a prompt the user learns to dismiss
  /// without reading, which costs them the one time it would have mattered.
  static const int minCoincidences = 3; // qualifying days, not consecutive

  /// How far back the pattern is looked for, in days.
  ///
  /// About three cycles. Long enough for a pattern to be a pattern, short
  /// enough that it reflects how things are now rather than how they were two
  /// years ago.
  static const int lookbackDays = 90; // days, about three cycles

  /// The severity of fatigue that counts.
  ///
  /// Mild fatigue on a heavy day is unremarkable and including it would fire
  /// the hint for almost everyone, which is the same as never firing it.
  static const SymptomSeverity fatigueThreshold = SymptomSeverity.moderate;

  /// Report whether logged fatigue has coincided with heavy flow often
  /// enough.
  ///
  /// Both facts come from the same logged day. Neither is inferred, and this
  /// returns a plain bool rather than a score, because there is nothing here
  /// to grade: the hint either has grounds to appear or it does not.
  ///
  /// Args:
  ///     logs (`List<DayLog>`): Every day the user has logged, in any order.
  ///     today (CivilDate): The end of the lookback window.
  ///
  /// Returns:
  ///     bool: True when at least [minCoincidences] days qualify.
  static bool fatigueWithHeavyFlow(List<DayLog> logs, CivilDate today) =>
      coincidingDays(logs, today).length >= minCoincidences;

  /// Return the days within the lookback where both were recorded.
  ///
  /// Exposed so a test can state which days it means rather than asserting a
  /// bool and hoping the count came from the right ones.
  ///
  /// Args:
  ///     logs (`List<DayLog>`): Every day the user has logged, in any order.
  ///     today (CivilDate): The end of the lookback window.
  ///
  /// Returns:
  ///     `List<CivilDate>`: The qualifying days, in the order [logs] gave
  ///     them.
  static List<CivilDate> coincidingDays(List<DayLog> logs, CivilDate today) {
    final earliest = today.addDays(-lookbackDays);
    return <CivilDate>[
      for (final log in logs)
        if (log.date >= earliest &&
            log.date <= today &&
            log.flow == FlowIntensity.heavy &&
            _atLeastThreshold(log.severityOf(Symptom.energy)))
          log.date,
    ];
  }

  /// Report whether a severity reaches [fatigueThreshold].
  ///
  /// Compares by index, which relies on [SymptomSeverity] staying ordered from
  /// least to most severe.
  ///
  /// Args:
  ///     severity (SymptomSeverity): What was logged for that day.
  ///
  /// Returns:
  ///     bool: True when [severity] is at or above the threshold.
  static bool _atLeastThreshold(SymptomSeverity severity) =>
      severity.index >= fatigueThreshold.index;
}
