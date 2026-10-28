/// Day log model.
///
/// Holds everything the user records against one calendar day, and the closed
/// vocabularies that record it. This is the only user-entered data in the app:
/// cycles, statistics and predictions are all derived from an ordered list of
/// these, which is why export and import deal in [DayLog] alone.
///
/// Every enum member here is a wire value, written to the database and to the
/// export file by name. Renaming one orphans stored rows; the labels the user
/// reads live in the ARB file instead.
///
/// Includes:
///     - FlowIntensity: How heavy bleeding was.
///     - SymptomSection: How a symptom is grouped on screen.
///     - Symptom: The fixed symptom set.
///     - SymptomSeverity: How strongly one was felt.
///     - Intercourse: Whether intercourse was recorded, and if protected.
///     - CervicalMucus: What cervical mucus was observed.
///     - PdgStripResult: A home progesterone (PdG) test strip's result.
///     - ProgesteroneUnit: The unit a blood test reported progesterone in.
///     - DayLog: The day itself.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/converters.dart';

part 'day_log.freezed.dart';
part 'day_log.g.dart';

/// Flow intensity: how heavy bleeding was on a given day.
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
  /// [spotting] deliberately does **not** count. Treating spotting as the
  /// start of a period is a common source of spurious short cycles, which the
  /// prediction filter then has to treat as outliers. Spotting is still worth
  /// recording, it just does not open a cycle. See `docs/PLAN.md` 5.5.
  bool get isBleeding =>
      this == FlowIntensity.light ||
      this == FlowIntensity.medium ||
      this == FlowIntensity.heavy;
}

/// Symptom section: how a [Symptom] is grouped in the day editor.
///
/// A display property and nothing more. The section is **not** part of what is
/// stored: only the symptom's name reaches the database and the export file,
/// so moving one between sections later is a one-line change with no
/// migration. That is worth knowing for [Symptom.energy], which is filed as
/// emotional here and is arguably physical. That decision can be revisited
/// cheaply, unlike the wire names.
enum SymptomSection {
  /// Felt in the body.
  physical,

  /// Felt in thinking, attention, or rest.
  mental,

  /// Felt in mood.
  emotional,
}

/// Symptom: the fixed symptom set the app records.
///
/// Deliberately closed. A free-text symptom field would be the single most
/// sensitive thing in the database and cannot be meaningfully analysed, so it
/// is out of scope (`docs/PLAN.md` 2.2). Closed is not the same as short: the
/// list is long enough that a user can find what they felt, and a symptom
/// nobody can express is a symptom that goes unlogged.
///
/// **The names are wire values.** They are written to the database and to
/// exports by name, so renaming a member orphans every stored row that used
/// it, and no migration recovers a name the code has forgotten. The label
/// shown to the user is in the ARB file and can be changed freely; the member
/// cannot.
///
/// Adding a value is a schema change even though no column moves. An older
/// build throws on a name it does not know, and the version is the only thing
/// that makes it refuse the file first. `enum_widening_test.dart` has the
/// argument in full.
///
/// Declared in section order so that reading the enum and reading the screen
/// give the same picture. Nothing depends on the order: storage is by name,
/// and the editor groups by [section] rather than by position.
///
/// Attributes:
///     section (SymptomSection): Which group it is shown under. Display
///         only; never stored.
enum Symptom {
  /// Abdominal or pelvic cramping.
  cramps(SymptomSection.physical),

  /// Headache or migraine.
  headache(SymptomSection.physical),

  /// Abdominal bloating or a feeling of fullness.
  bloating(SymptomSection.physical),

  /// Nausea, with or without vomiting.
  nausea(SymptomSection.physical),

  /// Sore or tender breasts.
  breastTenderness(SymptomSection.physical),

  /// Lower back pain.
  backPain(SymptomSection.physical),

  /// Breakouts or skin flare-ups.
  acne(SymptomSection.physical),

  /// Constipation, diarrhoea, or other gut upset.
  digestiveUpset(SymptomSection.physical),

  /// Disturbed sleep.
  sleep(SymptomSection.mental),

  /// Cloudy or slowed thinking.
  brainFog(SymptomSection.mental),

  /// Difficulty holding attention.
  poorConcentration(SymptomSection.mental),

  /// Mood disturbance.
  mood(SymptomSection.emotional),

  /// Fatigue or low energy.
  energy(SymptomSection.emotional),

  /// Irritability or a short fuse.
  irritability(SymptomSection.emotional),

  /// Anxiety or a sense of dread.
  anxiety(SymptomSection.emotional),

  /// Low mood, distinct from the general [mood] disturbance above.
  lowMood(SymptomSection.emotional);

  const Symptom(this.section);

  /// Which group this symptom is shown under. Display only; never stored.
  final SymptomSection section;

  /// Return the symptoms in one section, in declaration order.
  ///
  /// Args:
  ///     section (SymptomSection): The group to filter to.
  ///
  /// Returns:
  ///     `List<Symptom>`: The members of that section, in declaration order.
  static List<Symptom> inSection(SymptomSection section) =>
      values.where((s) => s.section == section).toList();
}

/// Symptom severity: how strongly a [Symptom] was felt.
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

/// Intercourse: whether it was recorded for a day, and whether protected.
///
/// **The most sensitive thing this app stores.** `docs/PLAN.md` 6.5 says to
/// treat everything here as if it will be read by someone the user did not
/// choose; that instruction applies to every field, and this is the one where
/// the consequences of being wrong are worst. `PRIVACY.md` and the onboarding
/// name it explicitly rather than letting a user discover it themselves.
///
/// **Nothing in `lib/domain/predict/` may read it.** Assumption A5 forbids
/// this app from presenting a fertile window or a safe day, and the shortest
/// path to breaking that rule is a well-meaning correlation between this
/// column and a cycle phase. `intercourse_isolation_test.dart` fails the build
/// on any reference to the type from the prediction layer, the same way
/// ADR-0010's guard does for conditions.
///
/// There is deliberately **no "none" value**. The column is nullable, and null
/// means not recorded, which has to stay distinguishable from a recorded
/// answer. A user who logs nothing has said nothing, and an app that recorded
/// "no" on their behalf would be inventing a statement about their private
/// life.
enum Intercourse {
  /// Recorded as protected.
  protected,

  /// Recorded as unprotected.
  unprotected,
}

/// Cervical mucus: what was observed, in the categories fertility-awareness
/// charts use.
///
/// **Recorded only** (ADR-0020), with the same guarantee as [Intercourse]:
/// nothing in `lib/domain/predict/` or `lib/domain/cycles/` may name it, and
/// `record_only_isolation_test.dart` fails the build if anything does. These
/// are fertility signs. A model reading them would be one step from a fertile
/// window, which assumption A5 forbids this app from presenting.
enum CervicalMucus {
  /// None noticed; the vulva feels dry.
  dry,

  /// Thick and tacky, breaking rather than stretching.
  sticky,

  /// Smooth and white, like lotion.
  creamy,

  /// Thin, clear and wet.
  watery,

  /// Clear and slippery, stretching between the fingers like raw egg white.
  eggWhite,
}

/// PdG strip result: what a home urine test for a progesterone metabolite
/// showed.
///
/// Recorded only (ADR-0020). What a positive strip means depends on the brand
/// and on when in the cycle it was taken, which the app does not try to judge.
enum PdgStripResult {
  /// The strip read negative.
  negative,

  /// The strip read positive.
  positive,
}

/// Progesterone unit: the unit a blood test reported serum progesterone in.
///
/// Kept with the value rather than converted, because the value is the
/// laboratory's and the app has no business restating it in other units.
enum ProgesteroneUnit {
  /// Nanograms per millilitre, common in the United States.
  ngPerMl,

  /// Nanomoles per litre, common elsewhere.
  nmolPerL,
}

/// Day log: everything recorded for a single calendar day.
///
/// This is the only user-entered data in the app. Cycles, statistics and
/// predictions are all derived from an ordered list of these, which is why
/// export and import deal in [DayLog] alone: it is the irreducible record.
///
/// Attributes:
///     date (CivilDate): The calendar day this describes.
///     flow (FlowIntensity): How heavy bleeding was. Defaults to
///         [FlowIntensity.none].
///     symptoms (`Map<Symptom, SymptomSeverity>`): What was felt, and how
///         strongly. Defaults to empty.
///     intercourse (Intercourse?): What was recorded, or null for nothing.
///     basalTemperatureCelsius (double?): Waking temperature, in degrees
///         Celsius whatever unit it was entered in, or null.
///     cervicalMucus (CervicalMucus?): What was observed, or null.
///     pdgStrip (PdgStripResult?): A PdG strip's result, or null.
///     progesteroneValue (double?): A blood test's progesterone, in
///         [progesteroneUnit], or null. Set exactly when the unit is.
///     progesteroneUnit (ProgesteroneUnit?): The unit it was reported in.
///
/// The last five are recorded only (ADR-0020): nothing predicts from them, and
/// the prediction and cycle layers cannot name them.
@freezed
abstract class DayLog with _$DayLog {
  /// Creates a log entry for [date].
  ///
  /// Args:
  ///     date (CivilDate): The calendar day this describes.
  ///     flow (FlowIntensity, optional): Defaults to [FlowIntensity.none].
  ///     symptoms (`Map<Symptom, SymptomSeverity>`, optional): Defaults to
  ///         empty.
  ///     intercourse (Intercourse?, optional): Defaults to null, meaning not
  ///         recorded.
  ///     basalTemperatureCelsius (double?, optional): Defaults to null.
  ///     cervicalMucus (CervicalMucus?, optional): Defaults to null.
  ///     pdgStrip (PdgStripResult?, optional): Defaults to null.
  ///     progesteroneValue (double?, optional): Defaults to null. Given
  ///         exactly when [progesteroneUnit] is.
  ///     progesteroneUnit (ProgesteroneUnit?, optional): Defaults to null.
  @Assert(
    '(progesteroneValue == null) == (progesteroneUnit == null)',
    'a blood test value is meaningless without its unit',
  )
  const factory DayLog({
    @CivilDateConverter() required CivilDate date,
    @Default(FlowIntensity.none) FlowIntensity flow,
    @Default(<Symptom, SymptomSeverity>{})
    Map<Symptom, SymptomSeverity> symptoms,
    // Nullable with no default, unlike every other field here. Null means not
    // recorded, and that must stay distinguishable from a recorded answer:
    // defaulting it would have the app assert something about the user's
    // private life that they never said.
    Intercourse? intercourse,
    // The same rule for everything below: null is not recorded. Each is its
    // own key in an export, in snake case like the envelope's own keys.
    @JsonKey(name: 'basal_temperature_celsius') double? basalTemperatureCelsius,
    @JsonKey(name: 'cervical_mucus') CervicalMucus? cervicalMucus,
    @JsonKey(name: 'pdg_strip') PdgStripResult? pdgStrip,
    @JsonKey(name: 'progesterone_value') double? progesteroneValue,
    @JsonKey(name: 'progesterone_unit') ProgesteroneUnit? progesteroneUnit,
  }) = _DayLog;

  const DayLog._();

  /// Rebuild a log entry from its JSON form.
  ///
  /// Args:
  ///     json (`Map<String, dynamic>`): The encoded entry.
  ///
  /// Returns:
  ///     DayLog: The decoded day.
  factory DayLog.fromJson(Map<String, dynamic> json) => _$DayLogFromJson(json);

  /// Whether this day counts as a bleeding day.
  bool get isBleedingDay => flow.isBleeding;

  /// Whether this entry records anything at all.
  ///
  /// An entry with no flow and no symptoms carries no information and should
  /// be deleted rather than stored, so that a gap in the data means "not
  /// logged" rather than "logged as nothing".
  bool get isEmpty =>
      flow == FlowIntensity.none &&
      symptoms.values.every((s) => s == SymptomSeverity.none) &&
      // Counted, so that a day whose only content is an intercourse entry is
      // stored rather than deleted as empty. Without this the editor would
      // accept the tap and then silently discard it on write. The same holds
      // for each of the measurements.
      intercourse == null &&
      !hasMeasurements;

  /// Whether a temperature, mucus or progesterone result is recorded.
  bool get hasMeasurements =>
      basalTemperatureCelsius != null ||
      cervicalMucus != null ||
      pdgStrip != null ||
      progesteroneValue != null;

  /// Return the severity recorded for one symptom.
  ///
  /// Args:
  ///     symptom (Symptom): The symptom to look up.
  ///
  /// Returns:
  ///     SymptomSeverity: What was recorded, or [SymptomSeverity.none] when
  ///     the symptom is absent from the map.
  SymptomSeverity severityOf(Symptom symptom) =>
      symptoms[symptom] ?? SymptomSeverity.none;
}
