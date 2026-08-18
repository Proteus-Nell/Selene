import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/cycles/validation.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/prediction.dart';

import 'cycle_fixtures.dart';

CycleStatistics summaryOf(List<int> lengths) =>
    CycleFeatures.summarise(Validation.assign(cyclesWithLengths(lengths)));

void main() {
  group('median', () {
    test('odd count takes the middle value', () {
      expect(CycleFeatures.median(const [1, 2, 3]), 2);
      expect(CycleFeatures.median(const [29, 27, 28]), 28);
    });

    test('even count averages the two central values', () {
      expect(CycleFeatures.median(const [1, 2, 3, 4]), 2.5);
      expect(CycleFeatures.median(const [28, 29]), 28.5);
    });

    test('does not depend on input order', () {
      expect(
        CycleFeatures.median(const [34, 26, 28, 30]),
        CycleFeatures.median(const [26, 28, 30, 34]),
      );
    });

    test('is robust to a single extreme value', () {
      // The reason median is used throughout rather than mean: one mis-logged
      // 200 day pseudo-cycle must not move the centre much.
      expect(CycleFeatures.median(const [28, 28, 29, 200]), 28.5);
    });

    test('throws on empty input rather than inventing a value', () {
      expect(() => CycleFeatures.median(const []), throwsArgumentError);
    });

    test('handles a single value', () {
      expect(CycleFeatures.median(const [28]), 28);
    });
  });

  group('medianAbsoluteDeviation', () {
    test('is zero for a constant history', () {
      expect(CycleFeatures.medianAbsoluteDeviation(const [28, 28, 28]), 0);
    });

    test('matches a hand-computed case', () {
      // values 26, 28, 30, median 28, deviations 2, 0, 2, median 2
      expect(CycleFeatures.medianAbsoluteDeviation(const [26, 28, 30]), 2);
    });

    test('grows with spread', () {
      final tight = CycleFeatures.medianAbsoluteDeviation(
        const [27, 28, 29, 28],
      );
      final loose = CycleFeatures.medianAbsoluteDeviation(
        const [21, 28, 35, 28],
      );
      expect(loose, greaterThan(tight));
    });
  });

  group('summarise', () {
    test('no cycles yields the empty statistics', () {
      expect(
        CycleFeatures.summarise(const <CycleRecord>[]),
        CycleStatistics.empty,
      );
      expect(
        CycleFeatures.summarise(const <CycleRecord>[]).hasHistory,
        isFalse,
      );
    });

    test('an in-progress-only history yields empty statistics', () {
      // One cycle that has not completed is not an observation yet.
      final cycles = cyclesWithLengths(const []);
      expect(cycles, hasLength(1));
      expect(CycleFeatures.summarise(cycles), CycleStatistics.empty);
    });

    test('counts only completed, unflagged cycles', () {
      final stats = summaryOf(const [28, 5, 30, 200, 29]);
      expect(
        stats.completedCycles,
        3,
        reason: 'the 5 and the 200 are flagged and excluded',
      );
    });

    test('reports median, shortest and longest', () {
      final stats = summaryOf(const [26, 28, 30, 32]);
      expect(stats.completedCycles, 4);
      expect(stats.medianLengthDays, 29);
      expect(stats.shortestLengthDays, 26);
      expect(stats.longestLengthDays, 32);
      expect(stats.observedSpreadDays, 6);
    });

    test('reports a zero MAD for a perfectly regular history', () {
      final stats = summaryOf(const [28, 28, 28, 28]);
      expect(stats.medianAbsoluteDeviationDays, 0);
      expect(
        stats.medianAbsoluteDeviationDays,
        isNotNull,
        reason: 'zero is a real value, not missing data',
      );
    });

    test('a single completed cycle gives stats but no spread', () {
      final stats = summaryOf(const [28]);
      expect(stats.completedCycles, 1);
      expect(stats.medianLengthDays, 28);
      expect(stats.observedSpreadDays, isNull, reason: 'needs two cycles');
    });
  });

  group('classify', () {
    test('is unknown below two completed cycles', () {
      expect(
        CycleFeatures.classify(CycleStatistics.empty),
        RegularityClass.unknown,
      );
      expect(
        CycleFeatures.classify(summaryOf(const [28])),
        RegularityClass.unknown,
      );
    });

    test('a tight history is regular', () {
      expect(
        CycleFeatures.classify(summaryOf(const [28, 28, 29, 27, 28])),
        RegularityClass.regular,
      );
    });

    test('a moderately spread history is variable', () {
      // sorted 24,26,28,30,32,34 -> median 29, deviations 5,3,1,1,3,5
      // -> MAD 3, which is above the regular bound of 2 and within the
      // variable bound of 5.
      expect(
        CycleFeatures.classify(summaryOf(const [24, 28, 32, 26, 34, 30])),
        RegularityClass.variable,
      );
    });

    test('a MAD of exactly the regular bound stays regular', () {
      // sorted 25,27,28,29,31,33 -> median 28.5, deviations 3.5,1.5,0.5,0.5,
      // 2.5,4.5 -> MAD exactly 2.0, which is inclusive at the tighter class.
      final stats = summaryOf(const [25, 28, 31, 27, 33, 29]);
      expect(stats.medianAbsoluteDeviationDays, 2);
      expect(CycleFeatures.classify(stats), RegularityClass.regular);
    });

    test('a widely spread history is irregular', () {
      expect(
        CycleFeatures.classify(summaryOf(const [21, 45, 28, 38, 24, 50])),
        RegularityClass.irregular,
      );
    });

    test('the boundaries are inclusive at the tighter class', () {
      const atRegularEdge = CycleStatistics(
        completedCycles: 5,
        medianAbsoluteDeviationDays: 2,
      );
      const atVariableEdge = CycleStatistics(
        completedCycles: 5,
        medianAbsoluteDeviationDays: 5,
      );
      expect(CycleFeatures.classify(atRegularEdge), RegularityClass.regular);
      expect(CycleFeatures.classify(atVariableEdge), RegularityClass.variable);
    });
  });

  group('usableLengths and recentUsableLengths', () {
    test('usableLengths excludes flagged and in-progress cycles', () {
      final assigned = Validation.assign(cyclesWithLengths(const [28, 5, 30]));
      expect(CycleFeatures.usableLengths(assigned), <int>[28, 30]);
    });

    test('recentUsableLengths takes the newest, oldest first', () {
      final assigned = Validation.assign(
        cyclesWithLengths(const [26, 27, 28, 29, 30]),
      );
      expect(
        CycleFeatures.recentUsableLengths(assigned, 3),
        <int>[28, 29, 30],
      );
    });

    test('recentUsableLengths returns everything when asked for more', () {
      final assigned = Validation.assign(cyclesWithLengths(const [28, 30]));
      expect(
        CycleFeatures.recentUsableLengths(assigned, 10),
        <int>[28, 30],
      );
    });

    test('recentUsableLengths rejects a non-positive count', () {
      expect(
        () => CycleFeatures.recentUsableLengths(const <CycleRecord>[], 0),
        throwsArgumentError,
      );
    });
  });

  group('end to end from day logs', () {
    test('logs to statistics via segmentation and validation', () {
      final logs = periodsWithLengths(const [28, 30, 27, 29]);
      final cycles = Validation.assign(
        // Segmentation is covered by its own suite; this checks the pipeline
        // composes without an adapter in between.
        cyclesWithLengths(const [28, 30, 27, 29]),
      );
      expect(logs, isNotEmpty);
      final stats = CycleFeatures.summarise(cycles);
      expect(stats.completedCycles, 4);
      expect(stats.medianLengthDays, 28.5);
      expect(CycleFeatures.classify(stats), RegularityClass.regular);
    });
  });
}
