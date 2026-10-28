// A small record for the summary tests: three periods, the days around them
// with symptoms and measurements, a condition and a medicine.
//
// Written out here rather than generated, so that each test can say exactly
// what it expects to find, and so that a change to the cycle rules does not
// move these.

import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// A date in 2026.
CivilDate day(int month, int date) => CivilDate(2026, month, date);

/// The days logged: periods starting 3 May, 1 June and 30 June, symptoms,
/// one of each measurement, and intercourse on two days, which nothing made
/// from a summary may carry.
final List<DayLog> fixtureLogs = <DayLog>[
  // Before the span the tests use, so a cycle runs into it from before.
  DayLog(date: day(4, 5), flow: FlowIntensity.medium),
  DayLog(
    date: day(5, 3),
    flow: FlowIntensity.heavy,
    symptoms: const <Symptom, SymptomSeverity>{
      Symptom.cramps: SymptomSeverity.severe,
      Symptom.headache: SymptomSeverity.none,
    },
    intercourse: Intercourse.unprotected,
  ),
  DayLog(
    date: day(5, 4),
    flow: FlowIntensity.medium,
    symptoms: const <Symptom, SymptomSeverity>{
      Symptom.cramps: SymptomSeverity.moderate,
    },
  ),
  DayLog(
    date: day(5, 17),
    basalTemperatureCelsius: 36.55,
    cervicalMucus: CervicalMucus.eggWhite,
    intercourse: Intercourse.protected,
  ),
  DayLog(
    date: day(5, 24),
    pdgStrip: PdgStripResult.positive,
    progesteroneValue: 12.5,
    progesteroneUnit: ProgesteroneUnit.ngPerMl,
    symptoms: const <Symptom, SymptomSeverity>{
      Symptom.breastTenderness: SymptomSeverity.mild,
    },
  ),
  DayLog(
    date: day(6, 1),
    flow: FlowIntensity.light,
    symptoms: const <Symptom, SymptomSeverity>{
      Symptom.cramps: SymptomSeverity.mild,
    },
    basalTemperatureCelsius: 36.2,
  ),
  DayLog(date: day(6, 30), flow: FlowIntensity.medium),
];

/// The cycles segmentation would find in [fixtureLogs]: one that started
/// before the span, two complete ones, and one still going. The June cycle is
/// flagged as an outlier, as validation flags one against a person's own
/// history, to show how a flagged cycle is carried.
final List<CycleRecord> fixtureCycles = <CycleRecord>[
  CycleRecord(
    startDate: day(4, 5),
    bleedingEndDate: day(4, 5),
    nextStartDate: day(5, 3),
  ),
  CycleRecord(
    startDate: day(5, 3),
    bleedingEndDate: day(5, 4),
    nextStartDate: day(6, 1),
  ),
  CycleRecord(
    startDate: day(6, 1),
    bleedingEndDate: day(6, 1),
    nextStartDate: day(6, 30),
    validity: CycleValidity.unconfirmedOutlier,
  ),
  CycleRecord(startDate: day(6, 30), bleedingEndDate: day(6, 30)),
];

/// One condition running through the span, and one that ended before it.
final List<ConditionRecord> fixtureConditions = <ConditionRecord>[
  ConditionRecord(
    id: 1,
    condition: Condition.copperIud,
    start: CivilDate(2025, 1, 1),
    end: CivilDate(2025, 12, 31),
  ),
  ConditionRecord(
    id: 2,
    condition: Condition.endometriosis,
    start: CivilDate(2024, 3, 1),
  ),
];

/// One medicine, with a comma in its name, as some combinations have.
const List<RecordedMedicine> fixtureMedicines = <RecordedMedicine>[
  RecordedMedicine(
    key: 'acetaminophen+caffeine.oral.otc',
    name: 'ACETAMINOPHEN, CAFFEINE',
  ),
];

/// The summary of 1 May to 15 July 2026 over the fixture record.
CycleSummary fixtureSummary() => CycleSummary.build(
  from: day(5, 1),
  to: day(7, 15),
  logs: fixtureLogs,
  cycles: fixtureCycles,
  conditions: fixtureConditions,
  medicines: fixtureMedicines,
);
