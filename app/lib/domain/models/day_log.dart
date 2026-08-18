import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/converters.dart';

part 'day_log.freezed.dart';
part 'day_log.g.dart';

/// How heavy bleeding was on a given day.
enum FlowIntensity {
  /// Nothing recorded for this day.
  none,

  /// Spotting only.
  spotting,

  /// Light flow.
  light,

  /// Medium flow.
  medium,

  /// Heavy flow.
  heavy;

  /// Whether this intensity counts as a bleeding day for cycle segmentation.
  ///
  /// [spotting] deliberately does **not** count. Treating spotting as the start
  /// of a period is a common source of spurious short cycles, which the
  /// prediction filter then has to treat as outliers. Spotting is still worth
  /// recording, it just does not open a cycle. See `docs/PLAN.md` 5.5.
  bool get isBleeding =>
      this == FlowIntensity.light ||
      this == FlowIntensity.medium ||
      this == FlowIntensity.heavy;
}

/// The fixed symptom set the app records.
///
/// Deliberately small and closed. A free-text symptom field would be the single
/// most sensitive thing in the database and cannot be meaningfully analysed, so
/// it is out of scope (`docs/PLAN.md` 2.2).
enum Symptom {
  /// Abdominal or pelvic cramping.
  cramps,

  /// Headache or migraine.
  headache,

  /// Mood disturbance.
  mood,

  /// Fatigue or low energy.
  energy,

  /// Disturbed sleep.
  sleep,
}

/// How strongly a [Symptom] was felt.
///
/// An enum rather than an `int` so an out-of-range severity cannot be
/// constructed at all. The four levels map onto the 0..3 scale in the plan.
enum SymptomSeverity {
  /// Not present.
  none,

  /// Noticeable but not disruptive.
  mild,

  /// Disruptive.
  moderate,

  /// Severe.
  severe,
}

/// Everything recorded for a single calendar day.
///
/// This is the only user-entered data in the app. Cycles, statistics and
/// predictions are all derived from an ordered list of these, which is why
/// export and import deal in [DayLog] alone: it is the irreducible record.
@freezed
abstract class DayLog with _$DayLog {
  /// Creates a log entry for [date].
  const factory DayLog({
    @CivilDateConverter() required CivilDate date,
    @Default(FlowIntensity.none) FlowIntensity flow,
    @Default(<Symptom, SymptomSeverity>{})
    Map<Symptom, SymptomSeverity> symptoms,
  }) = _DayLog;

  const DayLog._();

  /// Rebuilds a log entry from its JSON form.
  factory DayLog.fromJson(Map<String, dynamic> json) => _$DayLogFromJson(json);

  /// Whether this day counts as a bleeding day.
  bool get isBleedingDay => flow.isBleeding;

  /// Whether this entry records anything at all.
  ///
  /// An entry with no flow and no symptoms carries no information and should be
  /// deleted rather than stored, so that a gap in the data means "not logged"
  /// rather than "logged as nothing".
  bool get isEmpty =>
      flow == FlowIntensity.none &&
      symptoms.values.every((s) => s == SymptomSeverity.none);

  /// Severity recorded for [symptom], or [SymptomSeverity.none].
  SymptomSeverity severityOf(Symptom symptom) =>
      symptoms[symptom] ?? SymptomSeverity.none;
}
