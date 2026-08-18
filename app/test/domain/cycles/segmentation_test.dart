import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/cycles/segmentation.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

import 'cycle_fixtures.dart';

List<CycleRecord> segmented(Iterable<DayLog> logs) {
  final result = Segmentation.segment(logs);
  expect(result.isOk, isTrue, reason: 'unexpected ${result.errorOrNull}');
  return result.valueOrNull!;
}

void main() {
  group('empty and trivial input', () {
    test('no logs yields no cycles, not an error', () {
      // A brand-new user is a normal state, not a failure.
      expect(segmented(const <DayLog>[]), isEmpty);
    });

    test('logs with no bleeding yield no cycles', () {
      final logs = <DayLog>[
        DayLog(date: d('2026-03-01')),
        DayLog(
          date: d('2026-03-02'),
          symptoms: const {Symptom.mood: SymptomSeverity.mild},
        ),
      ];
      expect(segmented(logs), isEmpty);
    });

    test('a single bleeding day is one in-progress cycle', () {
      final cycles = segmented(bleed('2026-03-01', 1));
      expect(cycles, hasLength(1));
      expect(cycles.single.startDate, d('2026-03-01'));
      expect(cycles.single.bleedingEndDate, d('2026-03-01'));
      expect(cycles.single.isComplete, isFalse);
      expect(cycles.single.bleedingDays, 1);
    });
  });

  group('episode grouping', () {
    test('consecutive bleeding days are one episode', () {
      final cycles = segmented(bleed('2026-03-01', 5));
      expect(cycles, hasLength(1));
      expect(cycles.single.bleedingDays, 5);
    });

    test('a one day gap inside a period does not split it', () {
      // Day 3 unlogged, which is extremely common.
      final logs = <DayLog>[
        ...bleed('2026-03-01', 2),
        ...bleed('2026-03-04', 2),
      ];
      final cycles = segmented(logs);
      expect(cycles, hasLength(1));
      expect(cycles.single.bleedingEndDate, d('2026-03-05'));
    });

    test('a stop-start period is one cycle, not two', () {
      // Bleeds 1 to 3, stops for four days, resumes 8 to 9. Well inside the
      // 10 day minimum between episodes, so it is the same period returning.
      final logs = <DayLog>[
        ...bleed('2026-03-01', 3),
        ...bleed('2026-03-08', 2),
      ];
      final cycles = segmented(logs);
      expect(cycles, hasLength(1), reason: 'must not create a 7 day cycle');
      expect(cycles.single.startDate, d('2026-03-01'));
      expect(cycles.single.bleedingEndDate, d('2026-03-09'));
    });

    test('bleeding 10 or more days later is a new cycle', () {
      final logs = <DayLog>[
        ...bleed('2026-03-01', 2),
        ...bleed('2026-03-11', 2),
      ];
      final cycles = segmented(logs);
      expect(cycles, hasLength(2));
      expect(cycles.first.lengthInDays, 10);
    });
  });

  group('spotting is not a period start', () {
    test('spotting alone yields no cycles', () {
      final cycles = segmented(
        bleed('2026-03-01', 3, flow: FlowIntensity.spotting),
      );
      expect(cycles, isEmpty);
    });

    test('mid-cycle spotting does not split a cycle', () {
      // Without the spotting rule this would create a spurious short cycle that
      // the prediction filter would then have to reject as an outlier.
      final logs = <DayLog>[
        ...bleed('2026-03-01', 4),
        ...bleed('2026-03-15', 2, flow: FlowIntensity.spotting),
        ...bleed('2026-03-29', 4),
      ];
      final cycles = segmented(logs);
      expect(cycles, hasLength(2));
      expect(cycles.first.lengthInDays, 28);
    });

    test('spotting immediately before a period does not move the start', () {
      final logs = <DayLog>[
        ...bleed('2026-02-28', 1, flow: FlowIntensity.spotting),
        ...bleed('2026-03-01', 4),
      ];
      final cycles = segmented(logs);
      expect(cycles.single.startDate, d('2026-03-01'));
    });
  });

  group('multi-cycle histories', () {
    test('three 28 day cycles produce correct lengths', () {
      final cycles = segmented(periodsWithLengths(const [28, 28, 28]));
      expect(cycles, hasLength(4), reason: '3 complete plus 1 in progress');
      expect(
        cycles.map((c) => c.lengthInDays).toList(),
        <int?>[28, 28, 28, null],
      );
      expect(cycles.last.isComplete, isFalse);
    });

    test('varied lengths are preserved exactly', () {
      final cycles = segmented(periodsWithLengths(const [26, 31, 28, 34]));
      expect(
        cycles.map((c) => c.lengthInDays).toList(),
        <int?>[26, 31, 28, 34, null],
      );
    });

    test('each cycle ends where the next begins', () {
      final cycles = segmented(periodsWithLengths(const [28, 30]));
      expect(cycles[0].nextStartDate, cycles[1].startDate);
      expect(cycles[1].nextStartDate, cycles[2].startDate);
      expect(cycles.last.nextStartDate, isNull);
    });

    test('a long gap becomes one long cycle rather than a missing one', () {
      // Segmentation does not guess at a missed period. It reports the cycle it
      // can see, and validation flags it as implausibly long.
      final cycles = segmented(periodsOn(const ['2026-01-01', '2026-05-01']));
      expect(cycles, hasLength(2));
      expect(cycles.first.lengthInDays, 120);
    });

    test('cycles survive a year boundary and a leap day', () {
      final cycles = segmented(
        periodsOn(const ['2023-12-20', '2024-01-17', '2024-02-14']),
      );
      expect(cycles[0].lengthInDays, 28);
      expect(cycles[1].lengthInDays, 28);
    });
  });

  group('input robustness', () {
    test('out-of-order logs are sorted', () {
      final ordered = periodsWithLengths(const [28, 30]);
      final shuffled = ordered.reversed.toList();
      expect(
        segmented(shuffled).map((c) => c.lengthInDays).toList(),
        segmented(ordered).map((c) => c.lengthInDays).toList(),
      );
    });

    test('interleaved order gives the same result', () {
      final ordered = periodsWithLengths(const [28, 28]);
      final interleaved = <DayLog>[
        for (var i = 0; i < ordered.length; i += 2) ordered[i],
        for (var i = 1; i < ordered.length; i += 2) ordered[i],
      ];
      expect(
        segmented(interleaved).map((c) => c.lengthInDays).toList(),
        segmented(ordered).map((c) => c.lengthInDays).toList(),
      );
    });

    test('a duplicate date is an error, not a silent merge', () {
      // Duplicates mean the storage layer let through something it should have
      // rejected. Picking a winner here would hide a real bug.
      final logs = <DayLog>[
        DayLog(date: d('2026-03-01'), flow: FlowIntensity.medium),
        DayLog(date: d('2026-03-01'), flow: FlowIntensity.light),
      ];
      final result = Segmentation.segment(logs);
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, DataInconsistency.duplicateDate);
    });

    test('a duplicate is detected even on a non-bleeding day', () {
      final logs = <DayLog>[
        DayLog(date: d('2026-03-01')),
        DayLog(date: d('2026-03-01'), flow: FlowIntensity.spotting),
      ];
      expect(Segmentation.segment(logs).isErr, isTrue);
    });

    test('non-bleeding logs between periods are ignored', () {
      final logs = <DayLog>[
        ...periodsOn(const ['2026-03-01', '2026-03-29']),
        DayLog(
          date: d('2026-03-15'),
          symptoms: const {Symptom.cramps: SymptomSeverity.mild},
        ),
      ];
      final cycles = segmented(logs);
      expect(cycles, hasLength(2));
      expect(cycles.first.lengthInDays, 28);
    });
  });

  group('editing history', () {
    test('removing a period start merges two cycles into one', () {
      final full = periodsOn(const ['2026-01-01', '2026-01-29', '2026-02-26']);
      expect(segmented(full).map((c) => c.lengthInDays).first, 28);

      final withoutMiddle = full
          .where(
            (log) => log.date < d('2026-01-29') || log.date >= d('2026-02-26'),
          )
          .toList();
      final merged = segmented(withoutMiddle);
      expect(merged, hasLength(2));
      expect(merged.first.lengthInDays, 56, reason: '28 + 28 merged');
    });

    test('adding a period start splits one cycle into two', () {
      final sparse = segmented(periodsOn(const ['2026-01-01', '2026-02-26']));
      expect(sparse.first.lengthInDays, 56);

      final dense = segmented(
        periodsOn(const ['2026-01-01', '2026-01-29', '2026-02-26']),
      );
      expect(dense, hasLength(3));
      expect(dense.map((c) => c.lengthInDays).toList(), <int?>[28, 28, null]);
    });
  });

  group('hasLostTrack', () {
    test('is false with no logs at all', () {
      expect(
        Segmentation.hasLostTrack(
          logs: const <DayLog>[],
          today: d('2026-06-01'),
        ),
        isFalse,
      );
    });

    test('is false while logs are recent', () {
      expect(
        Segmentation.hasLostTrack(
          logs: bleed('2026-03-01', 4),
          today: d('2026-04-01'),
        ),
        isFalse,
      );
    });

    test('is true once the newest log is more than 60 days old', () {
      final logs = bleed('2026-03-01', 4);
      // Newest log is 2026-03-04, and 2026-03-04 plus 60 days is 2026-05-03.
      // The rule is strictly greater than 60, so day 60 is not yet lost.
      expect(
        Segmentation.hasLostTrack(logs: logs, today: d('2026-05-03')),
        isFalse,
        reason: 'exactly 60 days is not lost',
      );
      expect(
        Segmentation.hasLostTrack(logs: logs, today: d('2026-05-04')),
        isTrue,
        reason: '61 days is lost',
      );
    });
  });

  group('BleedingEpisode', () {
    test('exposes the bleeding span for the calendar', () {
      final result = Segmentation.bleedingEpisodes(
        periodsOn(const ['2026-03-01', '2026-03-29']),
      );
      final episodes = result.valueOrNull!;
      expect(episodes, hasLength(2));
      expect(episodes.first.lengthInDays, 4);
      expect(episodes.first.start, d('2026-03-01'));
      expect(episodes.first.end, d('2026-03-04'));
    });

    test('equality is by value', () {
      final a = Segmentation.bleedingEpisodes(bleed('2026-03-01', 3))
          .valueOrNull!
          .single;
      final b = Segmentation.bleedingEpisodes(bleed('2026-03-01', 3))
          .valueOrNull!
          .single;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), '2026-03-01..2026-03-03');
    });
  });
}
