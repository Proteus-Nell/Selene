/// Condition model.
///
/// Records the long-term conditions and medications a user tells the app
/// about, each over the span of days it applied to. These are stored and
/// displayed; none of them reaches the prediction model (ADR-0010).
///
/// Includes:
///     - Condition: The closed vocabulary of conditions.
///     - ConditionRecord: One condition over one span of days.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Condition: a long-term condition or medication the user has recorded.
///
/// `docs/PLAN.md` 1081 lists what the prediction model structurally cannot
/// know: hormonal contraception, pregnancy, postpartum, breastfeeding,
/// perimenopause, PCOS, endometriosis, thyroid disease. Each of them breaks
/// the "cycles are a noisy stationary-ish process" assumption the filter is
/// built on, and the filter has no way to see any of them.
///
/// **These are recorded and displayed. They do not reach the model.** That is
/// a deliberate decision rather than an omission; see
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
  /// pregnancy suppresses the prediction rather than confidently forecasting
  /// a period that is not coming. It withholds a claim; it does not make a
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

/// Condition record: one condition, over the span of days it applied to.
///
/// The end date is optional because most of these are open-ended when they are
/// first recorded: a user starting the pill does not know when they will stop.
/// Recording the span rather than a flag is what lets insights say "these six
/// cycles were logged while you were on hormonal contraception". A flag would
/// lose that the moment it was switched off, taking the interpretation of
/// every past cycle with it.
///
/// Attributes:
///     id (int): Row identity. Zero for a record not yet stored.
///     condition (Condition): What is being recorded.
///     start (CivilDate): The first day it applied.
///     end (CivilDate?): The last day it applied, or null while still going.
@immutable
final class ConditionRecord {
  /// Records a condition as running from [start] until [end].
  ///
  /// Args:
  ///     id (int): Row identity. Zero for a record not yet stored.
  ///     condition (Condition): What is being recorded.
  ///     start (CivilDate): The first day it applied.
  ///     end (CivilDate?, optional): The last day it applied. Defaults to
  ///         null, leaving the record open-ended.
  const ConditionRecord({
    required this.id,
    required this.condition,
    required this.start,
    this.end,
  });

  /// Rebuild a record from its exported form.
  ///
  /// The id is **not** carried in an export and is not read back here: it is a
  /// SQLite row number, meaningless in another database, and restoring one
  /// would either collide with an existing row or be silently ignored. Imports
  /// get fresh ids, which is correct: the identity of a condition record is
  /// its condition and its dates, not its position in a table.
  ///
  /// Args:
  ///     json (`Map<String, Object?>`): One exported record.
  ///
  /// Returns:
  ///     ConditionRecord: The decoded record, with an [id] of zero.
  ///
  /// Throws:
  ///     FormatException: On anything it cannot read, so the importer's
  ///         refusal path handles it rather than a half-parsed record
  ///         reaching storage.
  factory ConditionRecord.fromJson(Map<String, Object?> json) {
    final name = json['condition'];
    if (name is! String) {
      throw const FormatException('condition is missing or not text');
    }
    final condition = Condition.values.asNameMap()[name];
    if (condition == null) {
      throw FormatException('unknown condition: $name');
    }
    final start = json['start'];
    if (start is! String) {
      throw const FormatException('start is missing or not text');
    }
    final end = json['end'];
    if (end != null && end is! String) {
      throw const FormatException('end is not text');
    }
    return ConditionRecord(
      id: 0,
      condition: condition,
      start: CivilDate.parseIso8601(start),
      end: end == null ? null : CivilDate.parseIso8601(end as String),
    );
  }

  /// Row identity. Zero for a record that has not been stored yet.
  final int id;

  /// What is being recorded.
  final Condition condition;

  /// The first day it applied.
  final CivilDate start;

  /// The last day it applied, or null while it is still going.
  final CivilDate? end;

  /// Report whether this record covers one day.
  ///
  /// Args:
  ///     date (CivilDate): The day to test.
  ///
  /// Returns:
  ///     bool: True when [date] is on or after [start], and on or before
  ///     [end] when the record is closed.
  bool covers(CivilDate date) {
    if (date < start) return false;
    final closed = end;
    return closed == null || date <= closed;
  }

  /// Report whether this record is still running on a given day.
  ///
  /// Args:
  ///     today (CivilDate): The day to test.
  ///
  /// Returns:
  ///     bool: True when the record covers it.
  bool isActiveOn(CivilDate today) => covers(today);

  /// Render this record for export.
  ///
  /// See [ConditionRecord.fromJson] for why [id] is absent.
  ///
  /// Returns:
  ///     `Map<String, Object?>`: The condition by name, and both dates as
  ///     `YYYY-MM-DD` strings, with a null end for an open record.
  Map<String, Object?> toJson() => <String, Object?>{
    'condition': condition.name,
    'end': end?.toIso8601(),
    'start': start.toIso8601(),
  };

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
