// The summary for a doctor, before it is a PDF or a spreadsheet (ADR-0024).
//
// What is pinned here is what falls in a span and what is worked out from
// it, because both files are made from this and nothing else: the days in
// the span, which day of its cycle each was, the cycles that started in it,
// the conditions that ran during it, and the figures a doctor reads first.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

import 'summary_fixture.dart';

void main() {
  group('a span', () {
    test('reaches back whole calendar months', () {
      final today = day(10, 28);
      expect(SummarySpan.threeMonths.startOn(today), day(7, 28));
      expect(SummarySpan.sixMonths.startOn(today), day(4, 28));
      expect(SummarySpan.twelveMonths.startOn(today), CivilDate(2025, 10, 28));
    });

    test('lands on the last day of a shorter month', () {
      expect(
        SummarySpan.threeMonths.startOn(CivilDate(2026, 5, 31)),
        CivilDate(2026, 2, 28),
      );
      expect(
        SummarySpan.threeMonths.startOn(CivilDate(2024, 5, 31)),
        CivilDate(2024, 2, 29),
      );
    });

    test('reaches back over a new year', () {
      expect(
        SummarySpan.sixMonths.startOn(CivilDate(2026, 2, 10)),
        CivilDate(2025, 8, 10),
      );
    });

    test('of everything starts at the first logged day', () {
      final today = day(10, 28);
      expect(
        SummarySpan.everything.startOn(today, firstLogged: day(1, 5)),
        day(1, 5),
      );
      expect(SummarySpan.everything.startOn(today), today);
    });
  });

  group('the summary of a span', () {
    final summary = fixtureSummary();

    test('holds the days logged in it, oldest first', () {
      expect(summary.days.map((each) => each.date), <CivilDate>[
        day(5, 3),
        day(5, 4),
        day(5, 17),
        day(5, 24),
        day(6, 1),
        day(6, 30),
      ]);
    });

    test('says which day of its cycle each was', () {
      expect(summary.days.map((each) => each.cycleDay), <int?>[
        1,
        2,
        15,
        22,
        1,
        1,
      ]);
    });

    test('keeps the symptoms felt, not those recorded as none', () {
      expect(summary.days.first.symptoms, <Symptom, SymptomSeverity>{
        Symptom.cramps: SymptomSeverity.severe,
      });
    });

    test('holds the cycles that started in it, and not one before it', () {
      expect(summary.cycles.map((cycle) => cycle.startDate), <CivilDate>[
        day(5, 3),
        day(6, 1),
        day(6, 30),
      ]);
      expect(summary.cyclesKnown, isTrue);
    });

    test('counts only the cycles prediction counts', () {
      // The June cycle is flagged, and the last is still going.
      expect(summary.cycleLengths, <int>[29]);
      expect(summary.periodLengths, <int>[2, 1, 1]);
      expect(CycleSummary.median(summary.periodLengths), 1);
      expect(CycleSummary.median(const <int>[28, 31]), 29.5);
      expect(CycleSummary.median(const <int>[]), isNull);
    });

    test('counts each symptom by how strongly it was felt', () {
      expect(summary.symptomDays, <Symptom, Map<SymptomSeverity, int>>{
        Symptom.cramps: <SymptomSeverity, int>{
          SymptomSeverity.severe: 1,
          SymptomSeverity.moderate: 1,
          SymptomSeverity.mild: 1,
        },
        Symptom.breastTenderness: <SymptomSeverity, int>{
          SymptomSeverity.mild: 1,
        },
      });
    });

    test('gathers the measurements', () {
      expect(summary.temperatureDays.map((each) => each.date), <CivilDate>[
        day(5, 17),
        day(6, 1),
      ]);
      expect(summary.mucusDays, <CervicalMucus, int>{
        CervicalMucus.eggWhite: 1,
      });
      expect(summary.pdgDays.single.pdgStrip, PdgStripResult.positive);
      expect(summary.progesteroneDays.single.progesteroneValue, 12.5);
    });

    test('holds the conditions that ran during it, and not one that ended '
        'before it', () {
      expect(summary.conditions.map((record) => record.condition), <Condition>[
        Condition.endometriosis,
      ]);
    });

    test('holds the medicines, as the list stands', () {
      expect(summary.medicines, fixtureMedicines);
    });
  });

  test('with no cycles worked out says so, and keeps the days', () {
    final summary = CycleSummary.build(
      from: day(5, 1),
      to: day(7, 15),
      logs: fixtureLogs,
      cycles: null,
      conditions: const [],
      medicines: const [],
    );
    expect(summary.cyclesKnown, isFalse);
    expect(summary.cycles, isEmpty);
    expect(summary.days, hasLength(6));
    expect(summary.days.every((each) => each.cycleDay == null), isTrue);
  });
}
