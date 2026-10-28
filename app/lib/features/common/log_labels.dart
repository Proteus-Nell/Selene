/// Log labels.
///
/// What the log's closed vocabularies are called, in the user's language. One
/// place for each name, read by the day editor and by the summary for a
/// doctor (ADR-0024), so the two cannot call one thing by two names.
///
/// Each switch is exhaustive over its enum, so a value added later fails to
/// compile until it has a name.
///
/// Includes:
///     - flowLabel: A flow intensity.
///     - symptomLabel: A symptom.
///     - severityLabel: How strongly a symptom was felt.
///     - mucusLabel: What cervical mucus was observed.
///     - pdgLabel: A home progesterone strip's result.
///     - progesteroneUnitLabel: The unit a blood test reported in.
///     - temperatureUnitLabel: The unit temperatures are shown in.
library;

import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The name of [flow].
String flowLabel(AppLocalizations l10n, FlowIntensity flow) => switch (flow) {
  FlowIntensity.none => l10n.logFlowNone,
  FlowIntensity.spotting => l10n.logFlowSpotting,
  FlowIntensity.light => l10n.logFlowLight,
  FlowIntensity.medium => l10n.logFlowMedium,
  FlowIntensity.heavy => l10n.logFlowHeavy,
};

/// The name of [symptom].
String symptomLabel(AppLocalizations l10n, Symptom symptom) =>
    switch (symptom) {
      Symptom.cramps => l10n.logSymptomCramps,
      Symptom.headache => l10n.logSymptomHeadache,
      Symptom.bloating => l10n.logSymptomBloating,
      Symptom.nausea => l10n.logSymptomNausea,
      Symptom.breastTenderness => l10n.logSymptomBreastTenderness,
      Symptom.backPain => l10n.logSymptomBackPain,
      Symptom.acne => l10n.logSymptomAcne,
      Symptom.digestiveUpset => l10n.logSymptomDigestiveUpset,
      Symptom.sleep => l10n.logSymptomSleep,
      Symptom.brainFog => l10n.logSymptomBrainFog,
      Symptom.poorConcentration => l10n.logSymptomPoorConcentration,
      Symptom.mood => l10n.logSymptomMood,
      Symptom.energy => l10n.logSymptomEnergy,
      Symptom.irritability => l10n.logSymptomIrritability,
      Symptom.anxiety => l10n.logSymptomAnxiety,
      Symptom.lowMood => l10n.logSymptomLowMood,
    };

/// The name of [severity]. [SymptomSeverity.none] reads as the flow's
/// "none", which is the word the editor uses for not recorded.
String severityLabel(AppLocalizations l10n, SymptomSeverity severity) =>
    switch (severity) {
      SymptomSeverity.none => l10n.logFlowNone,
      SymptomSeverity.mild => l10n.logSeverityMild,
      SymptomSeverity.moderate => l10n.logSeverityModerate,
      SymptomSeverity.severe => l10n.logSeveritySevere,
    };

/// The name of [mucus].
String mucusLabel(AppLocalizations l10n, CervicalMucus mucus) =>
    switch (mucus) {
      CervicalMucus.dry => l10n.logMucusDry,
      CervicalMucus.sticky => l10n.logMucusSticky,
      CervicalMucus.creamy => l10n.logMucusCreamy,
      CervicalMucus.watery => l10n.logMucusWatery,
      CervicalMucus.eggWhite => l10n.logMucusEggWhite,
    };

/// The name of a PdG strip's [result].
String pdgLabel(AppLocalizations l10n, PdgStripResult result) =>
    switch (result) {
      PdgStripResult.negative => l10n.logPdgNegative,
      PdgStripResult.positive => l10n.logPdgPositive,
    };

/// The symbol of a blood test's [unit].
String progesteroneUnitLabel(AppLocalizations l10n, ProgesteroneUnit unit) =>
    switch (unit) {
      ProgesteroneUnit.ngPerMl => l10n.logProgesteroneNgPerMl,
      ProgesteroneUnit.nmolPerL => l10n.logProgesteroneNmolPerL,
    };

/// The symbol of the unit temperatures are shown in.
String temperatureUnitLabel(
  AppLocalizations l10n, {
  required bool fahrenheit,
}) => fahrenheit ? l10n.logTemperatureFahrenheit : l10n.logTemperatureCelsius;
