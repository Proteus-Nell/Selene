// "These six cycles were logged while you were on hormonal contraception."
//
// The sentence a flag cannot produce, and the reason the conditions table
// stores spans. Presented and nothing more: the count is context for reading
// the user's own numbers, never an input to them (ADR-0010).

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/condition_overlap.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';

void main() {
  CivilDate d(String iso) => CivilDate.parseIso8601(iso);

  /// Completed 28-day cycles, back to back from [from].
  List<CycleRecord> cycles(String from, int count) {
    var start = d(from);
    return <CycleRecord>[
      for (var i = 0; i < count; i++)
        () {
          final next = start.addDays(28);
          final record = CycleRecord(startDate: start, nextStartDate: next);
          start = next;
          return record;
        }(),
    ];
  }

  ConditionRecord record(
    Condition condition,
    String start, [
    String? end,
  ]) => ConditionRecord(
    id: 0,
    condition: condition,
    start: d(start),
    end: end == null ? null : d(end),
  );

  test('an ongoing condition covers every cycle from its start', () {
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 6),
      records: <ConditionRecord>[record(Condition.pcos, '2026-01-01')],
    );
    expect(overlaps.single.cycles, 6);
  });

  test('a closed span covers only the cycles it ran through', () {
    // Six 28-day cycles from 1 January; the span covers the first three.
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 6),
      records: <ConditionRecord>[
        record(
          Condition.hormonalContraceptionCombined,
          '2026-01-01',
          '2026-03-20',
        ),
      ],
    );
    expect(overlaps.single.cycles, 3);
  });

  test('a cycle counts if the condition was active on any day of it', () {
    // Someone who starts contraception mid-cycle has that cycle affected by it.
    // Requiring the start day to fall inside the span would drop exactly the
    // cycle a reader is most likely to be asking about.
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 1),
      records: <ConditionRecord>[
        record(Condition.hormonalIud, '2026-01-20'),
      ],
    );
    expect(overlaps.single.cycles, 1);
  });

  test('a condition ending before any cycle counts nothing', () {
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 3),
      records: <ConditionRecord>[
        record(Condition.postpartum, '2020-01-01', '2020-06-01'),
      ],
    );
    expect(overlaps, isEmpty);
  });

  test('two spans of the same condition are summed, not listed twice', () {
    // The sentence is about the condition, not the episode.
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 6),
      records: <ConditionRecord>[
        record(Condition.pcos, '2026-01-01', '2026-02-01'),
        record(Condition.pcos, '2026-05-01'),
      ],
    );
    expect(overlaps, hasLength(1));
    expect(overlaps.single.condition, Condition.pcos);
  });

  test('a cycle spanning two episodes of one condition counts once', () {
    // Counted with a set for exactly this. Double counting would produce
    // "7 cycles" out of six, which reads as a bug in the user's own history.
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 2),
      records: <ConditionRecord>[
        record(Condition.thyroidDisorder, '2026-01-02', '2026-01-10'),
        record(Condition.thyroidDisorder, '2026-01-15', '2026-01-20'),
      ],
    );
    expect(overlaps.single.cycles, 1);
  });

  test('a cycle still in progress is counted, not skipped', () {
    // It has no next start and so no length. It is the cycle the user is in
    // right now, and dropping it would make the count lag by one for as long as
    // the condition runs.
    final overlaps = ConditionOverlaps.summarise(
      cycles: <CycleRecord>[CycleRecord(startDate: d('2026-06-01'))],
      records: <ConditionRecord>[record(Condition.endometriosis, '2026-01-01')],
    );
    expect(overlaps.single.cycles, 1);
  });

  test('conditions with no overlapping cycles are left out entirely', () {
    // Rather than reported as zero. "0 cycles logged while this was recorded"
    // is noise on a screen whose job is to be readable.
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 2),
      records: <ConditionRecord>[
        record(Condition.pcos, '2026-01-01'),
        record(Condition.copperIud, '2019-01-01', '2019-02-01'),
      ],
    );
    expect(overlaps.map((o) => o.condition), <Condition>[Condition.pcos]);
  });

  test('the most-overlapped condition comes first', () {
    final overlaps = ConditionOverlaps.summarise(
      cycles: cycles('2026-01-01', 6),
      records: <ConditionRecord>[
        record(Condition.copperIud, '2026-05-01'),
        record(Condition.pcos, '2026-01-01'),
      ],
    );
    expect(overlaps.first.condition, Condition.pcos);
  });
}
