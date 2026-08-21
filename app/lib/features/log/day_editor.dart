import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Edits one day's flow and symptoms.
///
/// Used inline on the log screen for today, and in a sheet from the calendar
/// for any other day, so that "correct a wrong entry" is the same interaction
/// wherever the user starts (`docs/PLAN.md` 2.4.2).
///
/// Every change writes immediately. A save button would add a tap to every
/// correction and, worse, would create a state where the user believes they
/// have recorded something and have not.
class DayEditor extends ConsumerWidget {
  /// Edits [date], whose current entry is [existing].
  const DayEditor({required this.date, required this.existing, super.key});

  /// The day being edited.
  final CivilDate date;

  /// What is currently stored for that day, if anything.
  final DayLog? existing;

  Future<void> _write(WidgetRef ref, DayLog next) async {
    final repository = ref.read(cycleRepositoryProvider);
    if (next.isEmpty) {
      // An entry with no flow and no symptoms carries no information, and
      // storing it would make "logged as nothing" indistinguishable from "not
      // logged" for the segmentation downstream.
      await repository.deleteDay(next.date);
      return;
    }
    await repository.upsert(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = existing ?? DayLog(date: date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.logFlowTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final flow in FlowIntensity.values)
              ChoiceChip(
                selected: current.flow == flow,
                onSelected: (_) => _write(ref, current.copyWith(flow: flow)),
                label: Text(_flowLabel(l10n, flow)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.logSymptomsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.logSeverityHint, style: theme.textTheme.bodySmall),
        // Grouped rather than one long Wrap, because sixteen undifferentiated
        // chips are a list to be read rather than a set to be scanned. The
        // headings are what let someone looking for "bloating" skip two thirds
        // of them, which is the whole reason the catalogue could grow at all.
        //
        // The order is section order, and the first chip of the first section
        // is the most commonly logged symptom, so the four-tap budget in
        // docs/PLAN.md 2.4.2 is unchanged: a heading costs reading, not taps.
        for (final section in SymptomSection.values) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            _sectionLabel(l10n, section),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final symptom in Symptom.inSection(section))
                _SymptomChip(
                  symptom: symptom,
                  severity: current.severityOf(symptom),
                  onChanged: (severity) => _write(
                    ref,
                    current.copyWith(
                      symptoms:
                          <Symptom, SymptomSeverity>{
                            ...current.symptoms,
                            symptom: severity,
                          }..removeWhere(
                            (_, value) => value == SymptomSeverity.none,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _sectionLabel(AppLocalizations l10n, SymptomSection section) =>
      switch (section) {
        SymptomSection.physical => l10n.logSectionPhysical,
        SymptomSection.mental => l10n.logSectionMental,
        SymptomSection.emotional => l10n.logSectionEmotional,
      };

  static String _flowLabel(AppLocalizations l10n, FlowIntensity flow) =>
      switch (flow) {
        FlowIntensity.none => l10n.logFlowNone,
        FlowIntensity.spotting => l10n.logFlowSpotting,
        FlowIntensity.light => l10n.logFlowLight,
        FlowIntensity.medium => l10n.logFlowMedium,
        FlowIntensity.heavy => l10n.logFlowHeavy,
      };
}

/// A symptom chip: tap to record, long-press to say how strong it was.
///
/// One tap records it at [SymptomSeverity.moderate] rather than opening a
/// picker, because the budget for logging symptoms is four taps for the whole
/// interaction and most days the exact severity is not the point. The severity
/// is still reachable, just not on the critical path.
class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.symptom,
    required this.severity,
    required this.onChanged,
  });

  final Symptom symptom;
  final SymptomSeverity severity;
  final ValueChanged<SymptomSeverity> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recorded = severity != SymptomSeverity.none;
    final label = _symptomLabel(l10n, symptom);
    // MergeSemantics, not a bare GestureDetector: a detector wrapping a chip
    // publishes its own node carrying a long-press action and no label, which a
    // screen reader reads out as an unlabelled button. `a11y_test.dart` caught
    // exactly that. Merging folds the action into the chip's labelled node, so
    // the severity shortcut is announced rather than hidden.
    return MergeSemantics(
      child: Semantics(
        onLongPress: () => _chooseSeverity(context),
        child: GestureDetector(
          excludeFromSemantics: true,
          onLongPress: () => _chooseSeverity(context),
          child: FilterChip(
            selected: recorded,
            onSelected: (value) => onChanged(
              value ? SymptomSeverity.moderate : SymptomSeverity.none,
            ),
            // The severity is in the label rather than encoded in the fill
            // alone, so the state survives greyscale and reaches a screen
            // reader.
            label: Text(
              recorded ? '$label · ${_severityLabel(l10n, severity)}' : label,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSeverity(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<SymptomSeverity>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final option in SymptomSeverity.values)
              ListTile(
                title: Text(
                  option == SymptomSeverity.none
                      ? l10n.logFlowNone
                      : _severityLabel(l10n, option),
                ),
                selected: option == severity,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen);
  }

  static String _symptomLabel(AppLocalizations l10n, Symptom symptom) =>
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

  static String _severityLabel(
    AppLocalizations l10n,
    SymptomSeverity severity,
  ) => switch (severity) {
    SymptomSeverity.none => l10n.logFlowNone,
    SymptomSeverity.mild => l10n.logSeverityMild,
    SymptomSeverity.moderate => l10n.logSeverityModerate,
    SymptomSeverity.severe => l10n.logSeveritySevere,
  };
}
