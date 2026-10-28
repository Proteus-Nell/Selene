/// Measurements editor.
///
/// Basal body temperature, cervical mucus and progesterone tests, for one day
/// (ADR-0020). Recorded only: the section says so before anything is entered,
/// because everything else on the screen does feed the prediction, and someone
/// tracking these would reasonably expect them to.
///
/// Collapsed unless the day already has one, so the everyday editor is no
/// longer for people who never use it.
///
/// Includes:
///     - MeasurementsEditor: The section, and the writes it makes.
///     - _NumberField: A number that writes when it is finished, not on every
///       keystroke.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/temperature.dart';
import 'package:period_tracker/features/common/chip_motion.dart';
import 'package:period_tracker/features/common/log_labels.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Measurements editor: one day's temperature, mucus and progesterone.
///
/// Attributes:
///     current (DayLog): The day as it stands.
///     fahrenheit (bool): Whether temperatures are shown in Fahrenheit.
///     onChanged (`ValueChanged<DayLog>`): Writes what the day becomes.
class MeasurementsEditor extends StatelessWidget {
  /// Creates the section.
  ///
  /// Args:
  ///     current (DayLog): The day as it stands.
  ///     fahrenheit (bool): Whether temperatures are shown and entered in
  ///         Fahrenheit. They are stored in Celsius either way.
  ///     onChanged (`ValueChanged<DayLog>`): Writes what the day becomes.
  const MeasurementsEditor({
    required this.current,
    required this.fahrenheit,
    required this.onChanged,
    super.key,
  });

  /// The day as it stands.
  final DayLog current;

  /// Whether temperatures are shown in Fahrenheit.
  final bool fahrenheit;

  /// Writes what the day becomes.
  final ValueChanged<DayLog> onChanged;

  /// The temperatures that can be entered, in Celsius. A waking temperature
  /// outside this is a slip of the finger, not a reading.
  static const double lowestCelsius = 34;

  /// See [lowestCelsius].
  static const double highestCelsius = 42;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = temperatureUnitLabel(l10n, fahrenheit: fahrenheit);
    final temperature = current.basalTemperatureCelsius;

    return ExpansionTile(
      // A day that has one opens with them showing; one that has none keeps
      // the editor as short as it was.
      initiallyExpanded: current.hasMeasurements,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(l10n.logMeasurementsTitle, style: theme.textTheme.titleSmall),
      subtitle: Text(
        l10n.logMeasurementsHint,
        style: theme.textTheme.bodySmall,
      ),
      children: <Widget>[
        _NumberField(
          label: '${l10n.logTemperatureLabel} ($unit)',
          value: temperature == null
              ? null
              : Temperature.toShown(temperature, fahrenheit: fahrenheit),
          format: Temperature.format,
          validate: (shown) {
            final celsius = Temperature.toCelsius(
              shown,
              fahrenheit: fahrenheit,
            );
            if (celsius >= lowestCelsius && celsius <= highestCelsius) {
              return null;
            }
            return l10n.logTemperatureInvalid(
              Temperature.format(
                Temperature.toShown(lowestCelsius, fahrenheit: fahrenheit),
              ),
              Temperature.format(
                Temperature.toShown(highestCelsius, fahrenheit: fahrenheit),
              ),
            );
          },
          onCommitted: (shown) => onChanged(
            current.copyWith(
              basalTemperatureCelsius: shown == null
                  ? null
                  : Temperature.hundredths(
                      Temperature.toCelsius(shown, fahrenheit: fahrenheit),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.logMucusTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        _Choices<CervicalMucus>(
          values: CervicalMucus.values,
          selected: current.cervicalMucus,
          label: (value) => mucusLabel(l10n, value),
          onChanged: (value) =>
              onChanged(current.copyWith(cervicalMucus: value)),
        ),
        const SizedBox(height: 16),
        Text(l10n.logProgesteroneTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(l10n.logPdgStripLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        _Choices<PdgStripResult>(
          values: PdgStripResult.values,
          selected: current.pdgStrip,
          label: (value) => pdgLabel(l10n, value),
          onChanged: (value) => onChanged(current.copyWith(pdgStrip: value)),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _NumberField(
                label: l10n.logProgesteroneBloodLabel,
                value: current.progesteroneValue,
                format: Temperature.format,
                validate: (value) =>
                    value > 0 ? null : l10n.logProgesteroneInvalid,
                // The value and its unit go together or not at all: a number
                // with no unit is not a result.
                onCommitted: (value) => onChanged(
                  current.copyWith(
                    progesteroneValue: value,
                    progesteroneUnit: value == null
                        ? null
                        : current.progesteroneUnit ?? ProgesteroneUnit.ngPerMl,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<ProgesteroneUnit>(
              value: current.progesteroneUnit ?? ProgesteroneUnit.ngPerMl,
              hint: Text(l10n.logProgesteroneUnitLabel),
              items: <DropdownMenuItem<ProgesteroneUnit>>[
                for (final unit in ProgesteroneUnit.values)
                  DropdownMenuItem<ProgesteroneUnit>(
                    value: unit,
                    child: Text(progesteroneUnitLabel(l10n, unit)),
                  ),
              ],
              // Relabels rather than converts: the number is the laboratory's,
              // and changing the unit corrects which one it was reported in.
              onChanged: (unit) {
                if (unit == null || current.progesteroneValue == null) return;
                onChanged(current.copyWith(progesteroneUnit: unit));
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// A row of chips, one of which may be chosen, and none of which must be.
///
/// Tapping the chosen chip clears it, the way the intercourse chips do: there
/// is always a way back to having recorded nothing.
///
/// Attributes:
///     values (`List<T>`): The options.
///     selected (T?): The chosen one, or null.
///     label (`String Function(T)`): Names an option.
///     onChanged (`ValueChanged<T?>`): Reports a choice, or null to clear.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      for (final value in values)
        ChipMotion(
          selected: selected == value,
          builder: (context, checkSlot) => ChoiceChip(
            avatar: checkSlot,
            selected: selected == value,
            onSelected: (_) => onChanged(selected == value ? null : value),
            label: Text(label(value)),
          ),
        ),
    ],
  );
}

/// A number that writes when it is finished.
///
/// The rest of the editor writes on every tap, which suits a chip. A number
/// written on every keystroke would store "3", then "36", then "36.5", and a
/// reading interrupted halfway would be kept. So this writes when the field is
/// submitted or loses focus, an empty field clears the value, and a value that
/// fails [validate] says why and writes nothing.
///
/// Attributes:
///     label (String): What the number is.
///     value (double?): What is stored, in the units shown.
///     format (`String Function(double)`): Writes it for the field.
///     validate (`String? Function(double)`): Null for a good value, else
///         why it is refused.
///     onCommitted (`ValueChanged<double?>`): Writes a value, or null.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.format,
    required this.validate,
    required this.onCommitted,
  });

  final String label;
  final double? value;
  final String Function(double) format;
  final String? Function(double) validate;
  final ValueChanged<double?> onCommitted;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

/// State for [_NumberField].
///
/// Attributes:
///     _controller (TextEditingController): The text being typed.
///     _focus (FocusNode): Reports the field losing focus.
///     _error (String?): Why the last value was refused.
class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _shown(widget.value),
  );
  final FocusNode _focus = FocusNode();
  String? _error;

  String _shown(double? value) => value == null ? '' : widget.format(value);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A change from elsewhere, such as the unit setting, shows here unless the
    // field is being typed in.
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _shown(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = null);
      if (widget.value != null) widget.onCommitted(null);
      return;
    }
    // A comma is how much of the world writes a decimal point.
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    // Something that is not a number fails every range, so each field's own
    // validator gives the reason in its own words.
    final reason = widget.validate(
      parsed == null || !parsed.isFinite ? double.nan : parsed,
    );
    setState(() => _error = reason);
    if (reason != null || parsed == null) return;
    if (parsed != widget.value) widget.onCommitted(parsed);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: widget.label, errorText: _error),
    onSubmitted: (_) => _commit(),
  );
}
