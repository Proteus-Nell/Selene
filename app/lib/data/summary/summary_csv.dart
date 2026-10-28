/// The summary as spreadsheet files (ADR-0024).
///
/// Three tables, one file each, for anyone who wants to work with the record
/// themselves: the logged days, the cycles, and the conditions and medicines.
/// The columns are the backup's own keys and the values its own names
/// (`export_v1.dart`), so the files and a backup describe a day in the same
/// words, and dates are `YYYY-MM-DD`, which every spreadsheet reads as a date.
///
/// Written as RFC 4180 describes: a header row, commas, a field quoted where
/// it holds a comma, a quote or a line break, and CRLF line endings.
///
/// Includes:
///     - SummaryCsv: The three files, and their names.
library;

import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/temperature.dart';

/// The summary as three CSV files.
abstract final class SummaryCsv {
  /// Every file, by the name it is saved under.
  ///
  /// Args:
  ///     summary (CycleSummary): What goes in them.
  ///     fahrenheit (bool): Whether temperatures are shown in Fahrenheit, which
  ///         adds a Fahrenheit column beside the Celsius one.
  ///
  /// Returns:
  ///     `Map<String, String>`: The days, the cycles, and the conditions and
  ///     medicines, in that order. Each name says what it holds and the span:
  ///     `selene-days-2026-04-28-to-2026-10-28.csv`.
  static Map<String, String> files(
    CycleSummary summary, {
    required bool fahrenheit,
  }) {
    final span = '${summary.from.toIso8601()}-to-${summary.to.toIso8601()}';
    return <String, String>{
      'selene-days-$span.csv': days(summary, fahrenheit: fahrenheit),
      'selene-cycles-$span.csv': cycles(summary),
      'selene-conditions-and-medicines-$span.csv': conditionsAndMedicines(
        summary,
      ),
    };
  }

  /// One row per logged day, oldest first.
  ///
  /// A symptom has a column of its own, named as the backup names it, holding
  /// how strongly it was felt; an empty cell is not recorded.
  ///
  /// Args:
  ///     summary (CycleSummary): The days.
  ///     fahrenheit (bool): Whether to add a Fahrenheit column.
  ///
  /// Returns:
  ///     String: The file.
  static String days(CycleSummary summary, {required bool fahrenheit}) {
    final rows = <List<String>>[
      <String>[
        'date',
        'cycle_day',
        'flow',
        for (final symptom in Symptom.values) symptom.name,
        'basal_temperature_celsius',
        if (fahrenheit) 'basal_temperature_fahrenheit',
        'cervical_mucus',
        'pdg_strip',
        'progesterone_value',
        'progesterone_unit',
      ],
      for (final day in summary.days) _day(day, fahrenheit: fahrenheit),
    ];
    return _table(rows);
  }

  /// One day's row, in the columns [days] heads.
  static List<String> _day(SummaryDay day, {required bool fahrenheit}) {
    final celsius = day.temperatureCelsius;
    // Empty for none: a flow of none is a day with nothing recorded for it.
    final flow = day.flow == FlowIntensity.none ? '' : day.flow.name;
    final shown = celsius == null
        ? ''
        : Temperature.format(Temperature.toShown(celsius, fahrenheit: true));
    return <String>[
      day.date.toIso8601(),
      day.cycleDay?.toString() ?? '',
      flow,
      for (final symptom in Symptom.values) day.symptoms[symptom]?.name ?? '',
      _temperature(celsius),
      if (fahrenheit) shown,
      day.mucus?.name ?? '',
      day.pdgStrip?.name ?? '',
      _number(day.progesteroneValue),
      day.progesteroneUnit?.name ?? '',
    ];
  }

  /// A Celsius reading as the editor writes it, or an empty field for none.
  static String _temperature(double? celsius) =>
      celsius == null ? '' : Temperature.format(celsius);

  /// One row per cycle that started in the span, oldest first.
  ///
  /// `validity` is the app's own judgement of the cycle (ADR-0003): `ok`, or
  /// why prediction leaves it out. The last cycle may still be going, and has
  /// no next start or length.
  ///
  /// Args:
  ///     summary (CycleSummary): The cycles.
  ///
  /// Returns:
  ///     String: The file.
  static String cycles(CycleSummary summary) => _table(<List<String>>[
    <String>[
      'start',
      'bleeding_end',
      'next_start',
      'bleeding_days',
      'length_days',
      'validity',
    ],
    for (final cycle in summary.cycles)
      <String>[
        cycle.startDate.toIso8601(),
        cycle.bleedingEndDate?.toIso8601() ?? '',
        cycle.nextStartDate?.toIso8601() ?? '',
        cycle.bleedingDays?.toString() ?? '',
        cycle.lengthInDays?.toString() ?? '',
        cycle.validity.name,
      ],
  ]);

  /// One row per condition that ran during the span, by when it started, then
  /// one per medicine recorded.
  ///
  /// A condition is named as the backup names it, with the days it ran; an
  /// empty end is still going. A medicine is named as it was recorded, and
  /// has no dates, because the list has none (ADR-0015).
  ///
  /// Args:
  ///     summary (CycleSummary): The conditions and medicines.
  ///
  /// Returns:
  ///     String: The file.
  static String conditionsAndMedicines(CycleSummary summary) =>
      _table(<List<String>>[
        <String>['kind', 'name', 'start', 'end'],
        for (final record in summary.conditions)
          <String>[
            'condition',
            record.condition.name,
            record.start.toIso8601(),
            record.end?.toIso8601() ?? '',
          ],
        for (final medicine in summary.medicines)
          <String>['medicine', medicine.name, '', ''],
      ]);

  /// [rows] as CSV, each line ended with CRLF.
  static String _table(List<List<String>> rows) {
    final out = StringBuffer();
    for (final row in rows) {
      out
        ..write(row.map(_field).join(','))
        ..write('\r\n');
    }
    return out.toString();
  }

  /// [value] as a field: quoted, with its quotes doubled, where it holds a
  /// comma, a quote or a line break.
  static String _field(String value) => value.contains(RegExp('[",\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;

  /// [value] as it was recorded, a whole number without its ".0", or an empty
  /// field for none.
  static String _number(double? value) => switch (value) {
    null => '',
    final whole when whole == whole.roundToDouble() => whole.toInt().toString(),
    final fraction => fraction.toString(),
  };
}
