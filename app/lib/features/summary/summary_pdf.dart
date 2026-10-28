/// The summary for a doctor, laid out as a PDF (ADR-0024).
///
/// One document, read top to bottom: what it is and whose, the periods and
/// cycles with their lengths, the symptoms by how often and how strongly, the
/// measurements if there are any, the conditions, and the medicines. Every
/// word is from the ARB file, and every name for a symptom, a mucus or a
/// condition is the one the app shows for it.
///
/// Includes:
///     - summaryPdf: The summary, as a PDF file.
///     - summaryPdfFileName: What it is saved as.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/data/summary/pdf_document.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/temperature.dart';
import 'package:period_tracker/features/common/log_labels.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// What the PDF of [summary] is saved as: the span, and nothing about what is
/// in it, since a file's name is read in places its contents are not.
String summaryPdfFileName(CycleSummary summary) =>
    'selene-summary-${summary.from.toIso8601()}-to-'
    '${summary.to.toIso8601()}.pdf';

/// Lay [summary] out as the PDF a doctor is given.
///
/// Args:
///     summary (CycleSummary): What goes in it.
///     l10n (AppLocalizations): The words, and the language dates are
///         written in.
///     fahrenheit (bool): Whether temperatures are written in Fahrenheit.
///     made (DateTime): When it was made, for the file's own record.
///
/// Returns:
///     Uint8List: The PDF file.
Uint8List summaryPdf(
  CycleSummary summary, {
  required AppLocalizations l10n,
  required bool fahrenheit,
  required DateTime made,
}) {
  final dates = DateFormat.yMMMMd(l10n.localeName);
  String date(CivilDate day) => dates.format(day.toLocalMidnight());
  final from = date(summary.from);
  final to = date(summary.to);
  final document = PdfDocument(
    title: '${l10n.summaryPdfTitle}, ${l10n.summaryPdfSpan(from, to)}',
  );
  final flow = PdfFlow(document)
    ..paragraph(l10n.summaryPdfTitle, size: 18, font: PdfFont.bold)
    ..paragraph(l10n.summaryPdfSpan(from, to), size: 12)
    ..space(6)
    ..paragraph(l10n.summaryPdfAbout(to), size: 9, grey: 0.35);

  _cycles(flow, summary, l10n, date);
  _symptoms(flow, summary, l10n);
  _measurements(flow, summary, l10n, date, fahrenheit: fahrenheit);
  _conditions(flow, summary, l10n, date);
  _medicines(flow, summary, l10n);

  flow.footers(
    start: (page, count) => l10n.summaryPdfFooter(from, to),
    end: (page, count) => l10n.summaryPdfPage(page, count),
  );
  return document.encode(created: made);
}

/// Start a section: some space, and its heading, kept with what follows it.
void _heading(PdfFlow flow, String text) => flow
  ..space(16)
  ..paragraph(text, size: 13, font: PdfFont.bold, keepWith: 40)
  ..space(4);

/// The periods that started in the span, their lengths, and a table of them.
void _cycles(
  PdfFlow flow,
  CycleSummary summary,
  AppLocalizations l10n,
  String Function(CivilDate) date,
) {
  _heading(flow, l10n.summaryPdfCyclesHeading);
  if (!summary.cyclesKnown) {
    flow.paragraph(l10n.summaryPdfCyclesUnknown);
    return;
  }
  final cycles = summary.cycles;
  if (cycles.isEmpty) {
    flow.paragraph(l10n.summaryPdfNoPeriods);
    return;
  }
  flow.paragraph(l10n.summaryPdfPeriodsStarted(cycles.length));
  final lengths = summary.cycleLengths;
  if (lengths.isNotEmpty) {
    flow.paragraph(
      l10n.summaryPdfCycleLength(
        lengths.length,
        _days(CycleSummary.median(lengths)!),
        '${lengths.reduce((a, b) => a < b ? a : b)}',
        '${lengths.reduce((a, b) => a > b ? a : b)}',
      ),
    );
  }
  final bleeding = summary.periodLengths;
  if (bleeding.isNotEmpty) {
    flow.paragraph(
      l10n.summaryPdfBleeding(
        bleeding.length,
        _days(CycleSummary.median(bleeding)!),
        '${bleeding.reduce((a, b) => a < b ? a : b)}',
        '${bleeding.reduce((a, b) => a > b ? a : b)}',
      ),
    );
  }
  final noted = cycles.any(
    (cycle) => cycle.isComplete && cycle.validity != CycleValidity.ok,
  );
  if (noted) flow.paragraph(l10n.summaryPdfNotCounted, size: 9, grey: 0.35);
  flow
    ..space(6)
    ..table(
      header: <String>[
        l10n.summaryPdfColumnStarted,
        l10n.summaryPdfColumnBleeding,
        l10n.summaryPdfColumnLength,
        l10n.summaryPdfColumnNote,
      ],
      rows: <List<String>>[
        for (final cycle in cycles)
          <String>[
            date(cycle.startDate),
            cycle.bleedingDays?.toString() ?? '',
            cycle.lengthInDays?.toString() ?? '',
            _note(l10n, cycle),
          ],
      ],
      columns: const <double>[0.3, 0.2, 0.22, 0.28],
    );
}

/// Why a cycle is set apart, or nothing for one that is not.
String _note(AppLocalizations l10n, CycleRecord cycle) {
  if (!cycle.isComplete) return l10n.summaryPdfStillGoing;
  return switch (cycle.validity) {
    CycleValidity.ok => '',
    CycleValidity.implausiblyShort => l10n.summaryPdfShort,
    CycleValidity.implausiblyLong => l10n.summaryPdfLong,
    CycleValidity.unconfirmedOutlier => l10n.summaryPdfOutlier,
  };
}

/// Each symptom logged, by how many days and how strongly, most often first.
void _symptoms(PdfFlow flow, CycleSummary summary, AppLocalizations l10n) {
  _heading(flow, l10n.summaryPdfSymptomsHeading);
  final counts = summary.symptomDays;
  if (counts.isEmpty) {
    flow.paragraph(l10n.summaryPdfNoSymptoms);
    return;
  }
  int total(Map<SymptomSeverity, int> bySeverity) =>
      bySeverity.values.fold(0, (sum, days) => sum + days);
  // Most often first, and in the editor's order where two are level.
  final symptoms = <Symptom>[
    for (final symptom in Symptom.values)
      if (counts.containsKey(symptom)) symptom,
  ]..sort((a, b) => total(counts[b]!).compareTo(total(counts[a]!)));
  const severities = <SymptomSeverity>[
    SymptomSeverity.mild,
    SymptomSeverity.moderate,
    SymptomSeverity.severe,
  ];
  flow
    ..paragraph(l10n.summaryPdfSymptomsIntro)
    ..space(6)
    ..table(
      header: <String>[
        l10n.summaryPdfColumnSymptom,
        l10n.summaryPdfColumnDays,
        for (final severity in severities) severityLabel(l10n, severity),
      ],
      rows: <List<String>>[
        for (final symptom in symptoms)
          <String>[
            symptomLabel(l10n, symptom),
            '${total(counts[symptom]!)}',
            for (final severity in severities)
              '${counts[symptom]![severity] ?? 0}',
          ],
      ],
      columns: const <double>[0.36, 0.13, 0.17, 0.17, 0.17],
    );
}

/// The temperatures, mucus and progesterone results, when there are any.
void _measurements(
  PdfFlow flow,
  CycleSummary summary,
  AppLocalizations l10n,
  String Function(CivilDate) date, {
  required bool fahrenheit,
}) {
  final temperatures = summary.temperatureDays;
  final mucus = summary.mucusDays;
  final strips = summary.pdgDays;
  final blood = summary.progesteroneDays;
  if (temperatures.isEmpty &&
      mucus.isEmpty &&
      strips.isEmpty &&
      blood.isEmpty) {
    return;
  }
  _heading(flow, l10n.summaryPdfMeasurementsHeading);
  flow.paragraph(l10n.summaryPdfMeasurementsNote, size: 9, grey: 0.35);
  if (temperatures.isNotEmpty) {
    final shown = <double>[
      for (final day in temperatures)
        Temperature.toShown(day.temperatureCelsius!, fahrenheit: fahrenheit),
    ]..sort();
    flow.paragraph(
      l10n.summaryPdfTemperature(
        shown.length,
        Temperature.format(shown.first),
        Temperature.format(shown.last),
        temperatureUnitLabel(l10n, fahrenheit: fahrenheit),
      ),
    );
  }
  if (mucus.isNotEmpty) {
    flow.paragraph(
      l10n.summaryPdfMucus(
        <String>[
          for (final kind in CervicalMucus.values)
            if (mucus[kind] case final count?)
              l10n.summaryPdfMucusKind(mucusLabel(l10n, kind), count),
        ].join(', '),
      ),
    );
  }
  if (strips.isNotEmpty) {
    flow.paragraph(
      l10n.summaryPdfPdg(
        <String>[
          for (final day in strips)
            l10n.summaryPdfPdgResult(
              pdgLabel(l10n, day.pdgStrip!),
              date(day.date),
            ),
        ].join('; '),
      ),
    );
  }
  if (blood.isNotEmpty) {
    flow.paragraph(
      l10n.summaryPdfBlood(
        <String>[
          for (final day in blood)
            l10n.summaryPdfBloodResult(
              Temperature.format(day.progesteroneValue!),
              progesteroneUnitLabel(l10n, day.progesteroneUnit!),
              date(day.date),
            ),
        ].join('; '),
      ),
    );
  }
}

/// The conditions that ran during the span, with their dates.
void _conditions(
  PdfFlow flow,
  CycleSummary summary,
  AppLocalizations l10n,
  String Function(CivilDate) date,
) {
  _heading(flow, l10n.summaryPdfConditionsHeading);
  if (summary.conditions.isEmpty) {
    flow.paragraph(l10n.summaryPdfNoConditions);
    return;
  }
  for (final record in summary.conditions) {
    final name = conditionLabel(l10n, record.condition);
    final end = record.end;
    flow.paragraph(
      end == null
          ? l10n.summaryPdfConditionSince(name, date(record.start))
          : l10n.summaryPdfConditionFromTo(
              name,
              date(record.start),
              date(end),
            ),
    );
  }
}

/// The medicines recorded, which have no dates of their own.
void _medicines(PdfFlow flow, CycleSummary summary, AppLocalizations l10n) {
  _heading(flow, l10n.summaryPdfMedicinesHeading);
  if (summary.medicines.isEmpty) {
    flow.paragraph(l10n.summaryPdfNoMedicines);
    return;
  }
  flow.paragraph(l10n.summaryPdfMedicinesNote, size: 9, grey: 0.35);
  for (final medicine in summary.medicines) {
    flow.paragraph('• ${medicine.name}', indent: 4);
  }
}

/// A number of days as the summary writes it: whole, or with a half.
String _days(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
