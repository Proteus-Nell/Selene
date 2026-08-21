import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/cycles/segmentation.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Where in the cycle a day falls, by clinical name.
///
/// Derived, never stored — no column holds one of these, so widening this enum
/// is not a schema change and `enum_widening_test.dart` correctly ignores it.
///
/// The names are the clinical ones because they are what the user will meet
/// everywhere else, and inventing gentler synonyms would leave them unable to
/// look anything up. What is *not* here is as deliberate: there is no ovulation
/// phase and no fertile phase, because naming a day that way is the inference
/// `docs/PLAN.md` 6.2 gates and ADR-0007 kept gated.
enum CyclePhase {
  /// Bleeding, as logged. The only phase read directly off what the user
  /// recorded rather than derived from anything.
  period,

  /// Between the end of bleeding and the luteal phase.
  follicular,

  /// The roughly fixed-length run of days before the next period is due.
  luteal,
}

/// Where [CyclePosition.date] sits in the cycle, as far as the app can honestly
/// say.
///
/// Both fields are nullable, and separately. The app can very often say what
/// day of the cycle it is — that is arithmetic on a date the user logged — while
/// having no basis at all for a phase name, which needs a prediction to anchor
/// the luteal boundary to. Collapsing the two into one nullable object would
/// force the day count to be withheld along with the phase.
@immutable
final class CyclePosition {
  /// Creates a position.
  const CyclePosition({
    required this.date,
    required this.dayOfCycle,
    required this.phase,
    this.ovulationEstimate,
  });

  /// Nothing known: no bleeding has been logged, or the trail has gone cold.
  const CyclePosition.unknown(this.date)
    : dayOfCycle = null,
      phase = null,
      ovulationEstimate = null;

  /// The day this describes.
  final CivilDate date;

  /// Days since the current cycle began, counting the first day as 1.
  ///
  /// Null when no bleeding has been logged, or when the most recent log is old
  /// enough that the app has lost track (`CycleRules.lostTrackAfterDays`).
  /// Counting on past that point would produce "day 340 of your cycle", which
  /// is not a cycle day, it is a gap.
  final int? dayOfCycle;

  /// The named phase, or null when the app has no basis for one.
  final CyclePhase? phase;

  /// An estimated ovulation range, present only when explicitly asked for.
  ///
  /// **Off by default and never computed unless requested** — `docs/PLAN.md`
  /// 6.2, preserved by ADR-0007. It is a separate field rather than a variant
  /// of [phase] so that no rendering path can produce it by accident: a screen
  /// that does not ask for it cannot receive it.
  final CivilDateRange? ovulationEstimate;

  @override
  bool operator ==(Object other) =>
      other is CyclePosition &&
      other.date == date &&
      other.dayOfCycle == dayOfCycle &&
      other.phase == phase &&
      other.ovulationEstimate == ovulationEstimate;

  @override
  int get hashCode => Object.hash(date, dayOfCycle, phase, ovulationEstimate);

  @override
  String toString() =>
      'CyclePosition(${date.toIso8601()}, day $dayOfCycle, ${phase?.name})';
}

/// Works out where a day falls in the cycle.
///
/// Pure arithmetic over logged days plus, optionally, the predicted next start.
/// It reads nothing and writes nothing, which is what lets the tests state the
/// rules as examples rather than as fixtures.
abstract final class CyclePhases {
  /// How long the luteal phase is taken to be, in days.
  ///
  /// Fourteen is the conventional figure, and it is used here for the one
  /// property that makes it defensible: the luteal phase is the most consistent
  /// part of the cycle across people and across cycles, typically twelve to
  /// sixteen days, which is why almost all of the variation in cycle length
  /// sits in the follicular phase. So counting *backwards* from the next
  /// expected period is a far better-behaved estimate than counting forwards
  /// from the last one.
  ///
  /// This is a boundary between two named phases and nothing else. It is not
  /// published as a date, it is not called ovulation, and no day is described
  /// by it. ADR-0007 accepted precisely this: the phase name is permitted, the
  /// inference dressed as a fertile window is not.
  static const int lutealPhaseDays = 14;

  /// Half-width of the estimated ovulation range, in days.
  ///
  /// The range is deliberately five days wide rather than a single day. A point
  /// estimate would be read as a fact, and this is a population average applied
  /// to a person whose actual ovulation this app has no way to observe — no
  /// temperature, no LH, no ultrasound. Widening it is not hedging; it is the
  /// honest shape of what is known.
  static const int ovulationSpreadDays = 2;

  /// Where [date] falls, given [logs] and optionally [predictedStart].
  ///
  /// Pass [withOvulationEstimate] only from a call site that has checked the
  /// user's opt-in. It defaults to false so that forgetting to ask is the safe
  /// outcome rather than the leaky one.
  static CyclePosition on({
    required CivilDate date,
    required List<DayLog> logs,
    CivilDate? predictedStart,
    bool withOvulationEstimate = false,
  }) {
    final episodes = Segmentation.bleedingEpisodes(logs).valueOrNull;
    if (episodes == null || episodes.isEmpty) {
      return CyclePosition.unknown(date);
    }

    // The most recent episode that had started by [date]. Later ones are
    // ignored rather than treated as the current cycle, so asking about a past
    // day gives that day's answer instead of today's.
    BleedingEpisode? current;
    for (final episode in episodes) {
      if (episode.start <= date) current = episode;
    }
    if (current == null) return CyclePosition.unknown(date);

    final dayOfCycle = current.start.daysBetween(date) + 1;
    // Past this, the app has lost track and the count stops being a cycle day.
    // The same threshold the log screen uses to stop counting and say welcome
    // back, so the two screens cannot disagree about whether a cycle is still
    // in progress.
    if (dayOfCycle > CycleRules.lostTrackAfterDays) {
      return CyclePosition.unknown(date);
    }

    if (date <= current.end) {
      // Read straight off what was logged, so it needs no prediction and is the
      // one phase the app can always name.
      return CyclePosition(
        date: date,
        dayOfCycle: dayOfCycle,
        phase: CyclePhase.period,
      );
    }

    if (predictedStart == null || predictedStart <= date) {
      // No anchor for the luteal boundary, so no phase is named. The day count
      // still stands: it is arithmetic on a logged date and does not depend on
      // the prediction. A prediction already in the past is no anchor either —
      // it means the period is overdue, and calling those days luteal would be
      // asserting something about a cycle that has already outrun the model.
      return CyclePosition(
        date: date,
        dayOfCycle: dayOfCycle,
        phase: null,
      );
    }

    final lutealStart = predictedStart.addDays(-lutealPhaseDays);
    final phase = date < lutealStart
        ? CyclePhase.follicular
        : CyclePhase.luteal;

    return CyclePosition(
      date: date,
      dayOfCycle: dayOfCycle,
      phase: phase,
      ovulationEstimate: withOvulationEstimate
          ? _ovulationAround(lutealStart)
          : null,
    );
  }

  static CivilDateRange _ovulationAround(CivilDate lutealStart) =>
      CivilDateRange(
        lutealStart.addDays(-ovulationSpreadDays),
        lutealStart.addDays(ovulationSpreadDays),
      );
}
