/// A summary of the record over a chosen span, for a doctor (ADR-0024).
///
/// What the PDF summary and the CSV files are both made from: the periods
/// that started in the span and the cycles they began, every logged day in it,
/// the conditions that ran during it, and the medicines recorded. Pure, so it
/// can be built and checked in a plain test.
///
/// **Intercourse is not in it.** [SummaryDay] has no field for it, so nothing
/// made from a summary can carry it: not the PDF a doctor is handed, and not
/// a spreadsheet that may be shared further. A clinician summary is a record
/// someone other than the user reads, which `docs/PLAN.md` 6.5 says to plan
/// for.
///
/// Includes:
///     - SummarySpan: How far back a summary reaches.
///     - SummaryDay: One logged day, as a summary carries it.
///     - CycleSummary: The summary, and what it says about its span.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// How far back a summary reaches, from the day it is made.
enum SummarySpan {
  /// The last three months.
  threeMonths(3),

  /// The last six months.
  sixMonths(6),

  /// The last year.
  twelveMonths(12),

  /// Everything, from the first logged day.
  everything(null);

  const SummarySpan(this.months);

  /// How many calendar months it reaches back, or null for everything.
  final int? months;

  /// The first day the span covers, when it is made on [today].
  ///
  /// Args:
  ///     today (CivilDate): The day the summary is made, its last day.
  ///     firstLogged (CivilDate?): The oldest logged day, which is where
  ///         [everything] starts. Null when nothing is logged.
  ///
  /// Returns:
  ///     CivilDate: The same day of the month [months] months before
  ///     [today], or the month's last day where it has no such day: three
  ///     months before 31 May is 28 or 29 February. [everything] starts at
  ///     the first logged day, or today when there is none.
  CivilDate startOn(CivilDate today, {CivilDate? firstLogged}) {
    final back = months;
    if (back == null) {
      return firstLogged == null || firstLogged > today ? today : firstLogged;
    }
    final total = today.year * 12 + (today.month - 1) - back;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = today.day.clamp(1, CivilDate.daysInMonth(year, month));
    return CivilDate(year, month, day);
  }
}

/// One logged day, as a summary carries it.
///
/// Attributes:
///     date (CivilDate): The day.
///     cycleDay (int?): Which day of its cycle it was, from 1 on the day a
///         period started. Null before the first period on record.
///     flow (FlowIntensity): How heavy bleeding was.
///     symptoms (`Map<Symptom, SymptomSeverity>`): Each symptom recorded,
///         never one recorded as none.
///     temperatureCelsius (double?): The basal temperature, in Celsius.
///     mucus (CervicalMucus?): The cervical mucus observed.
///     pdgStrip (PdgStripResult?): A home PdG strip's result.
///     progesteroneValue (double?): A blood test's result.
///     progesteroneUnit (ProgesteroneUnit?): The unit it was reported in.
@immutable
final class SummaryDay {
  /// Creates a day.
  const SummaryDay({
    required this.date,
    required this.flow,
    required this.symptoms,
    this.cycleDay,
    this.temperatureCelsius,
    this.mucus,
    this.pdgStrip,
    this.progesteroneValue,
    this.progesteroneUnit,
  });

  /// [log] as a summary carries it: everything but intercourse.
  ///
  /// Args:
  ///     log (DayLog): The logged day.
  ///     cycleDay (int?): Which day of its cycle it was.
  ///
  /// Returns:
  ///     SummaryDay: The day.
  factory SummaryDay.of(DayLog log, {int? cycleDay}) => SummaryDay(
    date: log.date,
    cycleDay: cycleDay,
    flow: log.flow,
    symptoms: Map<Symptom, SymptomSeverity>.unmodifiable(
      <Symptom, SymptomSeverity>{
        for (final MapEntry(:key, :value) in log.symptoms.entries)
          if (value != SymptomSeverity.none) key: value,
      },
    ),
    temperatureCelsius: log.basalTemperatureCelsius,
    mucus: log.cervicalMucus,
    pdgStrip: log.pdgStrip,
    progesteroneValue: log.progesteroneValue,
    progesteroneUnit: log.progesteroneUnit,
  );

  /// The day.
  final CivilDate date;

  /// Which day of its cycle it was, from 1, or null before the first period
  /// on record.
  final int? cycleDay;

  /// How heavy bleeding was.
  final FlowIntensity flow;

  /// Each symptom recorded, never one recorded as none.
  final Map<Symptom, SymptomSeverity> symptoms;

  /// The basal temperature, in Celsius, or null.
  final double? temperatureCelsius;

  /// The cervical mucus observed, or null.
  final CervicalMucus? mucus;

  /// A home PdG strip's result, or null.
  final PdgStripResult? pdgStrip;

  /// A blood test's progesterone result, or null.
  final double? progesteroneValue;

  /// The unit [progesteroneValue] was reported in, or null with it.
  final ProgesteroneUnit? progesteroneUnit;

  /// Whether anything is recorded besides the flow and symptoms.
  bool get hasMeasurements =>
      temperatureCelsius != null ||
      mucus != null ||
      pdgStrip != null ||
      progesteroneValue != null;
}

/// A summary of the record from [from] to [to].
///
/// Attributes:
///     from (CivilDate): The first day it covers.
///     to (CivilDate): The last, the day it was made.
///     cycles (`List<CycleRecord>`): The cycles that started in the span,
///         oldest first.
///     cyclesKnown (bool): Whether the cycles could be worked out at all.
///     days (`List<SummaryDay>`): Every logged day in the span, oldest first.
///     conditions (`List<ConditionRecord>`): The conditions that ran during
///         any of it, by when they started.
///     medicines (`List<RecordedMedicine>`): The medicines recorded, as the
///         list stands when it is made.
@immutable
final class CycleSummary {
  /// Creates a summary.
  const CycleSummary({
    required this.from,
    required this.to,
    required this.cycles,
    required this.cyclesKnown,
    required this.days,
    required this.conditions,
    required this.medicines,
  });

  /// Build the summary of a span from the whole record.
  ///
  /// Args:
  ///     from (CivilDate): The first day to cover.
  ///     to (CivilDate): The last, the day it is made.
  ///     logs (`List<DayLog>`): Every logged day, in any order.
  ///     cycles (`List<CycleRecord>?`): Every cycle segmentation found, or
  ///         null when the record is inconsistent and it found none.
  ///     conditions (`List<ConditionRecord>`): Every condition recorded.
  ///     medicines (`List<RecordedMedicine>`): The medicines recorded.
  ///
  /// Returns:
  ///     CycleSummary: What falls in the span. A cycle counts when it started
  ///     in it, a condition when it ran on any day of it.
  factory CycleSummary.build({
    required CivilDate from,
    required CivilDate to,
    required List<DayLog> logs,
    required List<CycleRecord>? cycles,
    required List<ConditionRecord> conditions,
    required List<RecordedMedicine> medicines,
  }) {
    bool inSpan(CivilDate date) => date >= from && date <= to;
    final all = <CycleRecord>[...?cycles]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    // Which day of its cycle each day was, from every cycle there is: a day
    // early in the span belongs to a cycle that started before it.
    int? cycleDayOf(CivilDate date) {
      CycleRecord? latest;
      for (final cycle in all) {
        if (cycle.startDate > date) break;
        latest = cycle;
      }
      if (latest == null) return null;
      final next = latest.nextStartDate;
      if (next != null && date >= next) return null;
      return latest.startDate.daysBetween(date) + 1;
    }

    final days = <SummaryDay>[
      for (final log in logs.where((log) => inSpan(log.date)))
        SummaryDay.of(log, cycleDay: cycleDayOf(log.date)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return CycleSummary(
      from: from,
      to: to,
      cycles: List<CycleRecord>.unmodifiable(
        all.where((cycle) => inSpan(cycle.startDate)),
      ),
      cyclesKnown: cycles != null,
      days: List<SummaryDay>.unmodifiable(days),
      conditions: List<ConditionRecord>.unmodifiable(
        conditions
            .where((record) => record.start <= to && (record.end ?? to) >= from)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
      ),
      medicines: List<RecordedMedicine>.unmodifiable(medicines),
    );
  }

  /// Gather the whole record, and build the summary of [span] from it.
  ///
  /// Args:
  ///     span (SummarySpan): How far back it reaches.
  ///     today (CivilDate): The day it is made, its last day.
  ///     cycles (CycleRepository): The logged days, and the cycles in them.
  ///     conditions (ConditionRepository): The conditions recorded.
  ///     medicines (MedicineListRepository): The medicines recorded.
  ///
  /// Returns:
  ///     `Future<CycleSummary>`: The summary. Its cycles are unknown when the
  ///     logged days contradict each other, and the rest is unaffected.
  static Future<CycleSummary> load({
    required SummarySpan span,
    required CivilDate today,
    required CycleRepository cycles,
    required ConditionRepository conditions,
    required MedicineListRepository medicines,
  }) async {
    final logs = await cycles.logs();
    final segmented = await cycles.cycles();
    CivilDate? first;
    for (final log in logs) {
      if (first == null || log.date < first) first = log.date;
    }
    return CycleSummary.build(
      from: span.startOn(today, firstLogged: first),
      to: today,
      logs: logs,
      cycles: segmented.valueOrNull,
      conditions: await conditions.all(),
      medicines: await medicines.read(),
    );
  }

  /// The first day it covers.
  final CivilDate from;

  /// The last day it covers, the day it was made.
  final CivilDate to;

  /// The cycles that started in the span, oldest first. The last may still be
  /// going.
  final List<CycleRecord> cycles;

  /// Whether the cycles could be worked out. False when the record
  /// contradicts itself, in which case [cycles] is empty and says nothing.
  final bool cyclesKnown;

  /// Every logged day in the span, oldest first.
  final List<SummaryDay> days;

  /// The conditions that ran on any day of the span, by when they started.
  final List<ConditionRecord> conditions;

  /// The medicines recorded, as the list stands when the summary is made. The
  /// list has no dates (ADR-0015), so it is not cut to the span.
  final List<RecordedMedicine> medicines;

  /// The lengths of the complete cycles the app counts, from one period's
  /// start to the next, in days: the ones prediction would use (ADR-0003),
  /// not those flagged as implausible.
  List<int> get cycleLengths => <int>[
    for (final cycle in cycles)
      if (cycle.isUsableObservation) cycle.lengthInDays!,
  ];

  /// How many days each period in the span bled, where its end is known.
  List<int> get periodLengths => <int>[
    for (final cycle in cycles) ?cycle.bleedingDays,
  ];

  /// How many days each symptom was recorded on, at each severity, for the
  /// symptoms recorded at all.
  Map<Symptom, Map<SymptomSeverity, int>> get symptomDays {
    final counts = <Symptom, Map<SymptomSeverity, int>>{};
    for (final day in days) {
      for (final MapEntry(:key, :value) in day.symptoms.entries) {
        final bySeverity = counts.putIfAbsent(
          key,
          () => <SymptomSeverity, int>{},
        );
        bySeverity[value] = (bySeverity[value] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// The days a basal temperature was recorded on.
  List<SummaryDay> get temperatureDays => <SummaryDay>[
    for (final day in days)
      if (day.temperatureCelsius != null) day,
  ];

  /// How many days each kind of cervical mucus was recorded on.
  Map<CervicalMucus, int> get mucusDays {
    final counts = <CervicalMucus, int>{};
    for (final day in days) {
      final mucus = day.mucus;
      if (mucus != null) counts[mucus] = (counts[mucus] ?? 0) + 1;
    }
    return counts;
  }

  /// The days a PdG strip was recorded on.
  List<SummaryDay> get pdgDays => <SummaryDay>[
    for (final day in days)
      if (day.pdgStrip != null) day,
  ];

  /// The days a blood test's progesterone was recorded on.
  List<SummaryDay> get progesteroneDays => <SummaryDay>[
    for (final day in days)
      if (day.progesteroneValue != null) day,
  ];

  /// The median of [values], or null for none: the middle one, or halfway
  /// between the middle two.
  static double? median(List<int> values) => values.isEmpty
      ? null
      : CycleFeatures.median(<double>[
          for (final value in values) value.toDouble(),
        ]);
}
