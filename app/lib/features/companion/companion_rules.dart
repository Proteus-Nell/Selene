import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';

/// Everything the companion is allowed to look at (AND-37).
///
/// A flat record of the user's own state, derived once by [CompanionState.of]
/// and then read by [CompanionRules.select]. Two properties matter and both are
/// deliberate:
///
/// * **It is small and closed.** Nothing here is a free-text field, a score or
///   a model output. Every value is either something the user typed in or plain
///   arithmetic over it, which is what makes the whole rule set enumerable by a
///   test.
/// * **Selection is pure.** [CompanionRules.select] takes one of these and
///   returns one [CompanionLine], with no clock, no database and no randomness,
///   so `companion_lines_test.dart` can walk every combination of inputs and
///   assert the complete set of sentences that fall out.
@immutable
final class CompanionState {
  /// Creates a state.
  const CompanionState({
    this.ready = true,
    this.phase,
    this.predictionPaused = false,
    this.hasPrediction = false,
    this.periodOverdue = false,
    this.daysSinceLastLog,
    this.loggedToday = false,
    this.symptomsToday = const <Symptom>{},
    this.heavyBleedingRecently = false,
  });

  /// Nothing has been read yet.
  const CompanionState.notReady()
    : ready = false,
      phase = null,
      predictionPaused = false,
      hasPrediction = false,
      periodOverdue = false,
      daysSinceLastLog = null,
      loggedToday = false,
      symptomsToday = const <Symptom>{},
      heavyBleedingRecently = false;

  /// Derives the state from what the repositories hold.
  ///
  /// Pure over its arguments, so the derivation is testable without a database
  /// and cannot pick up a second opinion about what "today" is.
  factory CompanionState.of({
    required List<DayLog> logs,
    required PredictionResult prediction,
    required List<ConditionRecord> conditions,
    required CivilDate today,
  }) {
    final todayLog = logs.where((log) => log.date == today).firstOrNull;
    final lastLogged = logs.isEmpty
        ? null
        : logs.map((log) => log.date).reduce((a, b) => a > b ? a : b);

    // No ovulation estimate is asked for, and the default is false, so none can
    // arrive here by accident (PLAN 6.2, ADR-0007).
    final position = CyclePhases.on(
      date: today,
      logs: logs,
      predictedStart: switch (prediction) {
        Predicted(prediction: final predicted) => predicted.medianStart,
        _ => null,
      },
    );

    return CompanionState(
      phase: position.phase,
      predictionPaused: conditions.any(
        (record) =>
            record.condition.suppressesPrediction && record.isActiveOn(today),
      ),
      hasPrediction: prediction is Predicted,
      periodOverdue: switch (prediction) {
        Predicted(prediction: final predicted) =>
          predicted.window80.end < today,
        _ => false,
      },
      // Never negative: a log dated in the future is refused on write, but a
      // clock that moved backwards would produce one, and "minus two days since
      // the last log" is not a silence.
      daysSinceLastLog: lastLogged == null
          ? null
          : (lastLogged.daysBetween(today) < 0
                ? 0
                : lastLogged.daysBetween(today)),
      loggedToday: todayLog != null,
      symptomsToday: <Symptom>{
        if (todayLog != null)
          for (final entry in todayLog.symptoms.entries)
            if (entry.value != SymptomSeverity.none) entry.key,
      },
      heavyBleedingRecently: _heavyDays(logs, today) >= heavyFlowDaysNeeded,
    );
  }

  /// How far back heavy flow is looked for, in days.
  ///
  /// A month, so the answer is about the period just had rather than about one
  /// six months ago. Shorter than `NutritionHints.lookbackDays`, which is
  /// looking for a pattern across cycles; this is looking at the current one.
  static const int heavyFlowLookbackDays = 30;

  /// How many heavy days inside [heavyFlowLookbackDays] the iron line needs.
  ///
  /// The same figure and the same argument as `NutritionHints.minCoincidences`:
  /// one heavy day is an ordinary period, and a line that fires every month is
  /// a line the user learns to dismiss without reading.
  static const int heavyFlowDaysNeeded = 3;

  /// Days of silence after which the companion offers the log.
  ///
  /// Deliberately not a nudge and deliberately not a streak: a gap may be
  /// pregnancy, loss, illness, or simply not wanting to think about it
  /// (`docs/PLAN.md` 2.4.1), so what it offers is a door rather than a reason.
  static const int quietDays = 4;

  /// Whether the logs, prediction and conditions have all been read.
  final bool ready;

  /// Where today falls in the cycle, or null when the app has no basis for a
  /// phase name.
  final CyclePhase? phase;

  /// Whether a recorded condition is suppressing the prediction.
  final bool predictionPaused;

  /// Whether a personalised prediction exists.
  final bool hasPrediction;

  /// Whether the predicted window has passed with no period logged.
  final bool periodOverdue;

  /// Days since the most recent logged day, or null if nothing was ever logged.
  final int? daysSinceLastLog;

  /// Whether today has an entry.
  final bool loggedToday;

  /// Symptoms recorded for today, at any severity above none.
  final Set<Symptom> symptomsToday;

  /// Whether heavy flow was logged on enough recent days to mention iron.
  final bool heavyBleedingRecently;

  static int _heavyDays(List<DayLog> logs, CivilDate today) {
    final earliest = today.addDays(-heavyFlowLookbackDays);
    return logs
        .where(
          (log) =>
              log.date >= earliest &&
              log.date <= today &&
              log.flow == FlowIntensity.heavy,
        )
        .length;
  }
}

/// Picks the one thing the companion says (AND-37).
///
/// **A rules engine, not a model.** An ordered walk down a fixed list of
/// conditions, returning the first that matches. There is no scoring, no
/// randomness and no learning: the same state always produces the same
/// sentence, which is what lets a test enumerate every sentence there is.
///
/// The order is the editorial judgement, and it runs from *what the app is
/// currently unable to do* through *what was logged today* to *nothing in
/// particular*. Two placements are worth stating outright:
///
/// * [CompanionLine.predictionPaused] comes before every health line. Somebody
///   who has recorded a pregnancy should not be shown a note about menstrual
///   iron loss above the explanation of why their predictions stopped.
/// * [CompanionLine.overdue] comes after the symptom lines and says only that
///   a window has passed. `docs/PLAN.md` 6.3 is explicit that a missed period
///   is a data state and not a life event, so nothing further is inferred from
///   it, and nothing else in this file may ever be conditioned on it.
abstract final class CompanionRules {
  /// The line for [state].
  static CompanionLine select(CompanionState state) {
    if (!state.ready) return CompanionLine.stillReading;
    if (state.predictionPaused) return CompanionLine.predictionPaused;
    if (state.heavyBleedingRecently) return CompanionLine.heavyBleeding;
    if (state.symptomsToday.contains(Symptom.cramps)) {
      return CompanionLine.cramps;
    }
    if (state.symptomsToday.contains(Symptom.sleep)) return CompanionLine.sleep;
    if (state.symptomsToday.contains(Symptom.energy)) {
      return CompanionLine.lowEnergy;
    }
    if (state.phase == CyclePhase.period) return CompanionLine.periodToday;
    if (state.periodOverdue) return CompanionLine.overdue;

    final quiet = state.daysSinceLastLog;
    if (quiet == null) return CompanionLine.noLogsYet;
    if (quiet >= CompanionState.quietDays) {
      return CompanionLine.nothingLoggedRecently;
    }
    if (!state.hasPrediction) return CompanionLine.noPredictionYet;
    if (state.loggedToday) return CompanionLine.todayLogged;
    return CompanionLine.nothingToPointAt;
  }
}
