// The summary for a doctor, as the PDF the app writes (ADR-0024).
//
// What is pinned here is what a doctor reads in it, found in the file's own
// text: whose record it is and over what span, the figures and the table of
// cycles, the symptoms, the measurements, the conditions and the medicines,
// numbered pages, and no word of intercourse, which the summary never holds.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/data/summary/pdf_document.dart';
import 'package:period_tracker/features/summary/summary_pdf.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

import '../../data/summary/summary_fixture.dart';

/// Every run of text [pdf] sets, as WinAnsi bytes, joined by spaces.
///
/// Lines break at spaces, so joining them with one gives a paragraph back,
/// and a phrase can be looked for whole.
List<int> _text(List<int> pdf) {
  final file = latin1.decode(pdf);
  final out = <int>[];
  for (final match in RegExp(r'\(((?:\\.|[^\\)])*)\) Tj').allMatches(file)) {
    final literal = match.group(1)!;
    for (var i = 0; i < literal.length; i++) {
      if (literal[i] != r'\') {
        out.add(literal.codeUnitAt(i));
      } else if (RegExp('[0-7]').hasMatch(literal[i + 1])) {
        out.add(int.parse(literal.substring(i + 1, i + 4), radix: 8));
        i += 3;
      } else {
        out.add(literal.codeUnitAt(i + 1));
        i += 1;
      }
    }
    out.add(0x20);
  }
  return out;
}

/// Whether [haystack] holds [needle], in order.
bool _holds(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final made = DateTime.utc(2026, 7, 15, 8);

  List<int> textOf(CycleSummary summary, {bool fahrenheit = false}) => _text(
    summaryPdf(summary, l10n: l10n, fahrenheit: fahrenheit, made: made),
  );

  Matcher says(String phrase) => predicate<List<int>>(
    (text) => _holds(text, winAnsi(phrase)),
    'says "$phrase"',
  );

  final summary = fixtureSummary();
  late List<int> text;

  setUpAll(() async {
    // The app has this loaded by its localizations; a plain test loads it.
    await initializeDateFormatting('en');
    text = textOf(summary);
  });

  test('is a PDF file', () {
    final file = latin1.decode(
      summaryPdf(summary, l10n: l10n, fahrenheit: false, made: made),
    );
    expect(file, startsWith('%PDF-1.4'));
    expect(file, endsWith('%%EOF\n'));
  });

  test('is named for its span and nothing else', () {
    expect(
      summaryPdfFileName(summary),
      'selene-summary-2026-05-01-to-2026-07-15.pdf',
    );
  });

  test('says what it is, over what span, and whose record it is', () {
    expect(text, says(l10n.summaryPdfTitle));
    expect(text, says('May 1, 2026 to July 15, 2026'));
    expect(text, says(l10n.summaryPdfAbout('July 15, 2026')));
  });

  test('gives the cycle figures, counting only the cycles prediction '
      'counts', () {
    expect(text, says(l10n.summaryPdfPeriodsStarted(3)));
    expect(text, says(l10n.summaryPdfCycleLength(1, '29', '29', '29')));
    expect(text, says(l10n.summaryPdfBleeding(3, '1', '1', '2')));
    expect(text, says(l10n.summaryPdfNotCounted));
  });

  test('lists every period, with why one is set apart', () {
    expect(text, says(l10n.summaryPdfColumnStarted));
    expect(text, says('May 3, 2026 2 29'));
    expect(text, says('June 1, 2026 1 29 ${l10n.summaryPdfOutlier}'));
    expect(text, says('June 30, 2026 1 ${l10n.summaryPdfStillGoing}'));
  });

  test('counts the symptoms by how strongly they were felt', () {
    // Cramps: three days, one mild, one moderate, one severe.
    expect(text, says('${l10n.logSymptomCramps} 3 1 1 1'));
    expect(text, says('${l10n.logSymptomBreastTenderness} 1 1 0 0'));
  });

  test('gives the measurements, in the unit the person reads', () {
    expect(text, says(l10n.summaryPdfMeasurementsNote));
    expect(text, says(l10n.summaryPdfTemperature(2, '36.2', '36.55', '°C')));
    expect(
      textOf(summary, fahrenheit: true),
      says(l10n.summaryPdfTemperature(2, '97.16', '97.79', '°F')),
    );
    expect(text, says('Cervical mucus: Egg white on 1 day.'));
    expect(text, says('Home PdG strips: Positive on May 24, 2026.'));
    expect(text, says('Blood progesterone: 12.5 ng/mL on May 24, 2026.'));
  });

  test('lists the conditions with their dates, and the medicines', () {
    expect(text, says('Endometriosis: since March 1, 2024'));
    expect(text, says(l10n.summaryPdfMedicinesNote));
    expect(text, says('• ACETAMINOPHEN, CAFFEINE'));
  });

  test('numbers its pages', () {
    expect(text, says(l10n.summaryPdfPage(1, 1)));
    expect(text, says(l10n.summaryPdfFooter('May 1, 2026', 'July 15, 2026')));
  });

  test('says nothing about intercourse', () {
    final words = latin1.decode(text).toLowerCase();
    expect(words, isNot(contains('intercourse')));
    expect(words, isNot(contains('protected')));
  });

  test('says so where the cycles could not be worked out', () {
    final unknown = CycleSummary.build(
      from: summary.from,
      to: summary.to,
      logs: fixtureLogs,
      cycles: null,
      conditions: const [],
      medicines: const [],
    );
    final text = textOf(unknown);
    expect(text, says(l10n.summaryPdfCyclesUnknown));
    expect(text, says(l10n.summaryPdfNoConditions));
    expect(text, says(l10n.summaryPdfNoMedicines));
  });

  test('leaves the measurements out where none were taken', () {
    final bare = CycleSummary.build(
      from: summary.from,
      to: summary.to,
      logs: const [],
      cycles: const [],
      conditions: const [],
      medicines: const [],
    );
    final text = textOf(bare);
    expect(text, isNot(says(l10n.summaryPdfMeasurementsHeading)));
    expect(text, says(l10n.summaryPdfNoPeriods));
    expect(text, says(l10n.summaryPdfNoSymptoms));
  });
}
