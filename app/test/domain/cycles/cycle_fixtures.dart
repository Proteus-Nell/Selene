import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Shorthand for a date literal in tests.
CivilDate d(String iso) => CivilDate.parseIso8601(iso);

/// Bleeding logs for [bleedDays] consecutive days starting at [startIso].
List<DayLog> bleed(
  String startIso,
  int bleedDays, {
  FlowIntensity flow = FlowIntensity.medium,
}) {
  final start = d(startIso);
  return <DayLog>[
    for (var i = 0; i < bleedDays; i++)
      DayLog(date: start.addDays(i), flow: flow),
  ];
}

/// Bleeding logs for a period starting on each of [startIsos].
List<DayLog> periodsOn(
  List<String> startIsos, {
  int bleedDays = 4,
  FlowIntensity flow = FlowIntensity.medium,
}) => <DayLog>[
  for (final iso in startIsos) ...bleed(iso, bleedDays, flow: flow),
];

/// Bleeding logs for cycles of the given [lengths], starting at [firstStart].
///
/// Produces `lengths.length` complete cycles plus a final in-progress one, which
/// is what a real history always looks like.
List<DayLog> periodsWithLengths(
  List<int> lengths, {
  String firstStart = '2026-01-01',
  int bleedDays = 4,
}) {
  var current = d(firstStart);
  final starts = <String>[current.toIso8601()];
  for (final length in lengths) {
    current = current.addDays(length);
    starts.add(current.toIso8601());
  }
  return periodsOn(starts, bleedDays: bleedDays);
}

/// Complete [CycleRecord]s with the given [lengths], plus a trailing
/// in-progress cycle.
List<CycleRecord> cyclesWithLengths(
  List<int> lengths, {
  String firstStart = '2026-01-01',
  int bleedDays = 4,
}) {
  var start = d(firstStart);
  final records = <CycleRecord>[];
  for (final length in lengths) {
    final next = start.addDays(length);
    records.add(
      CycleRecord(
        startDate: start,
        bleedingEndDate: start.addDays(bleedDays - 1),
        nextStartDate: next,
      ),
    );
    start = next;
  }
  records.add(
    CycleRecord(
      startDate: start,
      bleedingEndDate: start.addDays(bleedDays - 1),
    ),
  );
  return records;
}
