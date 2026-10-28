/// Day editor.
///
/// Edits one day's flow, symptoms and intercourse, and the measurements kept
/// only as a record, in the same shape wherever it is opened from. Every change writes immediately: a save button would add
/// a tap to every correction and create a state where the user believes they
/// have recorded something and have not.
///
/// Includes:
///     - DayEditor: The editor, and the write every control makes.
///     - _IntercourseChips: Two chips, and a way back to having said nothing.
///     - _BleedingToggle: Flow as a yes/no question, and what "yes" records.
///     - _SymptomChip: One symptom, with its severity behind a long press.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/chip_motion.dart';
import 'package:period_tracker/features/log/measurements_editor.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Day editor: one day's flow, symptoms and intercourse.
///
/// Used inline on the log screen for today, and in a sheet from the calendar
/// for any other day, so that "correct a wrong entry" is the same interaction
/// wherever the user starts (`docs/PLAN.md` 2.4.2).
///
/// Every change writes immediately. A save button would add a tap to every
/// correction and, worse, would create a state where the user believes they
/// have recorded something and have not.
///
/// Attributes:
///     date (CivilDate): The day being edited.
///     existing (DayLog?): What is currently stored for it.
class DayEditor extends ConsumerWidget {
  /// Edits [date], whose current entry is [existing].
  ///
  /// Args:
  ///     date (CivilDate): The day being edited.
  ///     existing (DayLog?): What is currently stored for that day, or null.
  ///         Null and an empty log are treated alike, so an unlogged day and
  ///         a day logged as nothing open the same editor.
  const DayEditor({required this.date, required this.existing, super.key});

  /// The day being edited.
  final CivilDate date;

  /// What is currently stored for that day, if anything.
  final DayLog? existing;

  /// Write a day, or delete it when there is nothing left to record.
  ///
  /// Args:
  ///     ref (WidgetRef): For the cycle repository.
  ///     next (DayLog): What the day should become.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the write or the delete is done.
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
    // Falls back to the fuller control while the preference loads. A screen
    // that started simplified and then grew three more chips would read as the
    // app having changed its mind about what it recorded.
    final simplified = ref.watch(flowSimplifiedProvider).valueOrNull ?? false;
    final fahrenheit =
        ref.watch(temperatureFahrenheitProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.logFlowTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (simplified)
          _BleedingToggle(
            flow: current.flow,
            onChanged: (flow) => _write(ref, current.copyWith(flow: flow)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final flow in FlowIntensity.values)
                ChipMotion(
                  selected: current.flow == flow,
                  builder: (context, checkSlot) => ChoiceChip(
                    avatar: checkSlot,
                    selected: current.flow == flow,
                    onSelected: (_) =>
                        _write(ref, current.copyWith(flow: flow)),
                    label: Text(_flowLabel(l10n, flow)),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text(l10n.logSymptomsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.logSeverityHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 20),
        Text(l10n.logIntercourseTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        // Both facts a user needs before touching this, stated before they do:
        // it is optional, and it is not used for predictions, which they would
        // otherwise reasonably assume, since everything else here is.
        Text(l10n.logIntercourseHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        _IntercourseChips(
          value: current.intercourse,
          onChanged: (value) =>
              _write(ref, current.copyWith(intercourse: value)),
        ),
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
        const SizedBox(height: 12),
        MeasurementsEditor(
          current: current,
          fahrenheit: fahrenheit,
          onChanged: (next) => _write(ref, next),
        ),
      ],
    );
  }

  /// Return the heading for one symptom section.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     section (SymptomSection): The section to name.
  ///
  /// Returns:
  ///     String: Its heading, in the user's language.
  static String _sectionLabel(AppLocalizations l10n, SymptomSection section) =>
      switch (section) {
        SymptomSection.physical => l10n.logSectionPhysical,
        SymptomSection.mental => l10n.logSectionMental,
        SymptomSection.emotional => l10n.logSectionEmotional,
      };

  /// Return the label for one flow intensity.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     flow (FlowIntensity): The intensity to name.
  ///
  /// Returns:
  ///     String: Its name, in the user's language.
  static String _flowLabel(AppLocalizations l10n, FlowIntensity flow) =>
      switch (flow) {
        FlowIntensity.none => l10n.logFlowNone,
        FlowIntensity.spotting => l10n.logFlowSpotting,
        FlowIntensity.light => l10n.logFlowLight,
        FlowIntensity.medium => l10n.logFlowMedium,
        FlowIntensity.heavy => l10n.logFlowHeavy,
      };
}

/// The intercourse control (AND-30).
///
/// Two chips and no third "none" option, because [Intercourse] has no such
/// value: null means *not recorded*, and that has to stay a different statement
/// from either answer. Tapping the selected chip clears it, which is how a user
/// takes something back. The alternative would be an app that, once told,
/// cannot be untold.
///
/// Attributes:
///     value (Intercourse?): What is recorded, or null for nothing.
///     onChanged (`ValueChanged<Intercourse?>`): Reports a new answer.
class _IntercourseChips extends StatelessWidget {
  /// Creates the control.
  ///
  /// Args:
  ///     value (Intercourse?): What is recorded, or null for nothing.
  ///     onChanged (`ValueChanged<Intercourse?>`): Reports a new answer, and
  ///         is passed null when the selected chip is tapped again.
  const _IntercourseChips({required this.value, required this.onChanged});

  /// What is recorded, or null for nothing.
  final Intercourse? value;

  /// Reports a new answer, or null to clear it.
  final ValueChanged<Intercourse?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final option in Intercourse.values)
          ChipMotion(
            selected: value == option,
            builder: (context, checkSlot) => ChoiceChip(
              avatar: checkSlot,
              selected: value == option,
              // Re-selecting clears rather than re-writing the same value, so
              // there is always a way back to having said nothing.
              onSelected: (_) => onChanged(value == option ? null : option),
              label: Text(_label(l10n, option)),
            ),
          ),
      ],
    );
  }

  /// Return the label for one answer.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     value (Intercourse): The answer to name.
  ///
  /// Returns:
  ///     String: Its name, in the user's language.
  static String _label(AppLocalizations l10n, Intercourse value) =>
      switch (value) {
        Intercourse.protected => l10n.logIntercourseProtected,
        Intercourse.unprotected => l10n.logIntercourseUnprotected,
      };
}

/// Flow as a yes/no question, for users who do not want to grade it (AND-24).
///
/// **The mapping is the whole risk in this feature.** `Segmentation` reads
/// nothing but [DayLog.isBleedingDay], and [FlowIntensity.spotting] is
/// deliberately *not* a bleeding day: mid-cycle spotting must not open a cycle,
/// because a spurious short cycle is an outlier the filter then has to widen
/// its intervals to absorb. So "yes" writes [FlowIntensity.medium], a real
/// bleeding intensity in the middle of the range, which is the least wrong
/// thing to record when the user has declined to say. Writing spotting here
/// would silently stop cycles being detected at all for every user who turned
/// this on, and nothing on screen would say so.
///
/// [FlowIntensity.medium] is also what `CycleRepository.markPeriodStart`
/// records when the user taps the primary action without saying an intensity,
/// so the two ways of answering "yes, today" agree rather than producing days
/// that differ by which button was pressed.
///
/// Reads back through the same predicate rather than through equality: a day
/// recorded as heavy before the toggle was turned on answers "yes", and stays
/// heavy.
///
/// Attributes:
///     flow (FlowIntensity): What is currently recorded.
///     onChanged (`ValueChanged<FlowIntensity>`): Reports a new answer.
class _BleedingToggle extends StatelessWidget {
  /// Creates the toggle.
  ///
  /// Args:
  ///     flow (FlowIntensity): What is currently recorded, at whatever
  ///         intensity. Read through `isBleeding` rather than by equality.
  ///     onChanged (`ValueChanged<FlowIntensity>`): Reports a new answer. Not
  ///         called when the current answer is tapped again, which is what
  ///         keeps a heavy day heavy.
  const _BleedingToggle({required this.flow, required this.onChanged});

  /// What is currently recorded, at whatever intensity.
  final FlowIntensity flow;

  /// Reports a new answer.
  final ValueChanged<FlowIntensity> onChanged;

  /// What "yes" records. See the class comment: never [FlowIntensity.spotting].
  static const FlowIntensity yesIntensity = FlowIntensity.medium;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bleeding = flow.isBleeding;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ChipMotion(
          selected: bleeding,
          builder: (context, checkSlot) => ChoiceChip(
            avatar: checkSlot,
            selected: bleeding,
            // Re-selecting the current answer writes nothing. That is what
            // keeps a heavy day heavy: the user confirming "yes" must not
            // quietly downgrade it to medium, and switching the preference on
            // and off must leave the database untouched.
            onSelected: (_) => bleeding ? null : onChanged(yesIntensity),
            label: Text(l10n.logBleedingYes),
          ),
        ),
        ChipMotion(
          selected: !bleeding,
          builder: (context, checkSlot) => ChoiceChip(
            avatar: checkSlot,
            selected: !bleeding,
            onSelected: (_) => bleeding ? onChanged(FlowIntensity.none) : null,
            label: Text(l10n.logBleedingNo),
          ),
        ),
      ],
    );
  }
}

/// A symptom chip: tap to record, long-press to say how strong it was.
///
/// One tap records it at [SymptomSeverity.moderate] rather than opening a
/// picker, because the budget for logging symptoms is four taps for the whole
/// interaction and most days the exact severity is not the point. The severity
/// is still reachable, just not on the critical path.
///
/// Attributes:
///     symptom (Symptom): The symptom this chip records.
///     severity (SymptomSeverity): How strong it currently is.
///     onChanged (`ValueChanged<SymptomSeverity>`): Reports a new severity.
class _SymptomChip extends StatelessWidget {
  /// Creates a symptom chip.
  ///
  /// Args:
  ///     symptom (Symptom): The symptom this chip records.
  ///     severity (SymptomSeverity): How strong it currently is.
  ///         [SymptomSeverity.none] means it is not recorded at all.
  ///     onChanged (`ValueChanged<SymptomSeverity>`): Reports a new severity,
  ///         including `none` when the chip is deselected.
  const _SymptomChip({
    required this.symptom,
    required this.severity,
    required this.onChanged,
  });

  /// The symptom this chip records.
  final Symptom symptom;

  /// How strong it currently is, or none if it is not recorded.
  final SymptomSeverity severity;

  /// Reports a new severity.
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
          child: ChipMotion(
            selected: recorded,
            builder: (context, checkSlot) => FilterChip(
              avatar: checkSlot,
              selected: recorded,
              onSelected: (value) => onChanged(
                value ? SymptomSeverity.moderate : SymptomSeverity.none,
              ),
              // The severity is in the label rather than encoded in the fill
              // alone, so the state survives greyscale and reaches a screen
              // reader. It is also why these chips still change width when
              // they are selected, where the rest do not: the reserved
              // checkmark slot holds the mark's width, not the label's.
              label: Text(
                recorded ? '$label · ${_severityLabel(l10n, severity)}' : label,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Offer the severities in a sheet, and report the chosen one.
  ///
  /// Args:
  ///     context (BuildContext): What to show the sheet over.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the sheet is closed. Nothing is
  ///     reported when it is dismissed, so backing out leaves the chip as it
  ///     was rather than clearing it.
  Future<void> _chooseSeverity(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<SymptomSeverity>(
      context: context,
      // Short enough today that it never reaches the cutout, but set for the
      // same reason as the other two: a sheet that grows later should not have
      // to rediscover this.
      useSafeArea: true,
      showDragHandle: true,
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

  /// Return the label for one symptom.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     symptom (Symptom): The symptom to name.
  ///
  /// Returns:
  ///     String: Its name, in the user's language. Exhaustive over the enum,
  ///     so a symptom added later fails to compile until it has a name.
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

  /// Return the label for one severity.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     severity (SymptomSeverity): The severity to name.
  ///
  /// Returns:
  ///     String: Its name, in the user's language.
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
