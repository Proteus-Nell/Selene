import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';

/// A long-term condition or medication the user has told the app about.
///
/// `docs/PLAN.md` 1081 lists what the prediction model structurally cannot
/// know: hormonal contraception, pregnancy, postpartum, breastfeeding,
/// perimenopause, PCOS, endometriosis, thyroid disease. Each of them breaks the
/// "cycles are a noisy stationary-ish process" assumption the filter is built
/// on, and the filter has no way to see any of them.
///
/// **These are recorded and displayed. They do not reach the model.** That is a
/// deliberate decision, not an omission — see
/// [ADR-0010](../../../../docs/DECISIONS.md). The shipped priors were fitted
/// with no condition strata, so making the filter behave differently for PCOS
/// would be inventing calibration and presenting it as a measurement.
///
/// The values are wire names: they are written into the database and into
/// export files by name, so renaming one breaks every stored row. Adding is
/// safe, renaming and removing are not.
enum Condition {
  /// Combined oral contraceptive, containing oestrogen and a progestogen.
  hormonalContraceptionCombined,

  /// Progestogen-only pill.
  hormonalContraceptionProgestogen,

  /// Hormonal intrauterine device.
  hormonalIud,

  /// Contraceptive implant.
  contraceptiveImplant,

  /// Copper intrauterine device. Non-hormonal, and often heavier bleeding.
  copperIud,

  /// Currently pregnant.
  ///
  /// The one condition that changes what the app is willing to say: an active
  /// pregnancy suppresses the prediction rather than confidently forecasting a
  /// period that is not coming. It withholds a claim; it does not make a
  /// different one, and it needs no new arithmetic.
  pregnancy,

  /// The months after giving birth, while cycles are returning.
  postpartum,

  /// Breastfeeding, which commonly suppresses or delays cycles.
  breastfeeding,

  /// Polycystic ovary syndrome.
  pcos,

  /// Endometriosis.
  endometriosis,

  /// Any thyroid disorder, over- or under-active.
  thyroidDisorder,

  /// The years of irregularity leading up to menopause.
  perimenopause,

  /// Uterine fibroids.
  uterineFibroids,

  /// Something the list does not cover.
  other;

  /// Whether the app should withhold a prediction while this is active.
  ///
  /// Only [pregnancy]. Hormonal contraception often removes true cycles
  /// entirely and is the obvious next candidate, but suppressing it was
  /// considered and **not** chosen (ADR-0010), so it must not be added here
  /// without revisiting that decision.
  bool get suppressesPrediction => this == Condition.pregnancy;
}

/// One condition, over the span of days it applied to.
///
/// The end date is optional because most of these are open-ended when they are
/// first recorded: a user starting the pill does not know when they will stop.
/// Recording the span rather than a flag is what lets insights say "these six
/// cycles were logged while you were on hormonal contraception" — a flag would
/// lose that the moment it was switched off, taking the interpretation of every
/// past cycle with it.
@immutable
final class ConditionRecord {
  /// Records [condition] as running from [start] until [end], or still active.
  const ConditionRecord({
    required this.id,
    required this.condition,
    required this.start,
    this.end,
  });

  /// Row identity. Zero for a record that has not been stored yet.
  final int id;

  /// What is being recorded.
  final Condition condition;

  /// The first day it applied.
  final CivilDate start;

  /// The last day it applied, or null while it is still going.
  final CivilDate? end;

  /// Whether this record covers [date].
  bool covers(CivilDate date) {
    if (date < start) return false;
    final closed = end;
    return closed == null || date <= closed;
  }

  /// Whether this record is still running as of [today].
  bool isActiveOn(CivilDate today) => covers(today);

  @override
  bool operator ==(Object other) =>
      other is ConditionRecord &&
      other.id == id &&
      other.condition == condition &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, condition, start, end);

  @override
  String toString() =>
      'ConditionRecord($condition, ${start.toIso8601()}'
      '${end == null ? ', ongoing' : ' to ${end!.toIso8601()}'})';
}
