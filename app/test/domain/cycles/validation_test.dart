import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/cycles/validation.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';

import 'cycle_fixtures.dart';

List<CycleValidity> validitiesFor(List<int> lengths) =>
    Validation.assign(cyclesWithLengths(lengths))
        .map((c) => c.validity)
        .toList();

void main() {
  group('absolute plausibility', () {
    test('a normal cycle is ok', () {
      expect(validitiesFor(const [28]).first, CycleValidity.ok);
    });

    test('a cycle shorter than 15 days is flagged short', () {
      expect(
        validitiesFor(const [14]).first,
        CycleValidity.implausiblyShort,
      );
    });

    test('a cycle longer than 90 days is flagged long', () {
      expect(
        validitiesFor(const [91]).first,
        CycleValidity.implausiblyLong,
      );
    });

    test('the plausibility band is inclusive at both ends', () {
      expect(Validation.isPlausibleLength(15), isTrue);
      expect(Validation.isPlausibleLength(90), isTrue);
      expect(Validation.isPlausibleLength(14), isFalse);
      expect(Validation.isPlausibleLength(91), isFalse);
      expect(validitiesFor(const [15]).first, CycleValidity.ok);
      expect(validitiesFor(const [90]).first, CycleValidity.ok);
    });

    test('an in-progress cycle is never flagged', () {
      // It has no length yet, so there is nothing to judge and inventing a
      // verdict would be wrong.
      final assigned = Validation.assign(cyclesWithLengths(const [28, 30]));
      expect(assigned.last.isComplete, isFalse);
      expect(assigned.last.validity, CycleValidity.ok);
    });
  });

  group('flag, never drop', () {
    test('a flagged cycle keeps every field intact', () {
      final assigned = Validation.assign(cyclesWithLengths(const [120]));
      final flagged = assigned.first;
      expect(flagged.validity, CycleValidity.implausiblyLong);
      expect(flagged.lengthInDays, 120);
      expect(flagged.startDate, d('2026-01-01'));
      expect(flagged.bleedingEndDate, d('2026-01-04'));
      expect(flagged.nextStartDate, isNotNull);
    });

    test('assign preserves order and count', () {
      final input = cyclesWithLengths(const [28, 5, 30, 200]);
      final output = Validation.assign(input);
      expect(output, hasLength(input.length));
      for (var i = 0; i < input.length; i++) {
        expect(output[i].startDate, input[i].startDate);
      }
    });

    test('a flagged cycle is excluded from usable observations', () {
      final assigned = Validation.assign(cyclesWithLengths(const [28, 5, 30]));
      expect(assigned[1].validity, CycleValidity.implausiblyShort);
      expect(assigned[1].isUsableObservation, isFalse);
      expect(assigned[0].isUsableObservation, isTrue);
    });
  });

  group('relative outlier detection', () {
    test('needs at least four plausible observations', () {
      // Three cycles, one wildly different. With too little history there is no
      // stable notion of "unusual for this person", so nothing is flagged.
      final three = validitiesFor(const [28, 28, 45]);
      expect(three, everyElement(CycleValidity.ok));
      expect(
        CycleRules.minCyclesForOutlierDetection,
        4,
        reason: 'test encodes the documented threshold',
      );
    });

    test('a strong outlier is flagged once there is enough history', () {
      final validities = validitiesFor(const [27, 28, 29, 28, 27, 55]);
      expect(validities[5], CycleValidity.unconfirmedOutlier);
      expect(validities.take(5), everyElement(CycleValidity.ok));
    });

    test('normal variation is not flagged', () {
      final validities = validitiesFor(const [26, 28, 30, 27, 29, 31, 28]);
      expect(validities.where((v) => v != CycleValidity.ok), isEmpty);
    });

    test('a perfectly regular history flags nothing', () {
      // MAD is zero here. Without the zero-MAD guard, a single 29 in a run of
      // 28s would be infinitely many MADs from the median and get flagged.
      final validities = validitiesFor(const [28, 28, 28, 28, 28, 29]);
      expect(validities.where((v) => v != CycleValidity.ok), isEmpty);
    });

    test('the baseline ignores implausible cycles', () {
      // The 200 day cycle is a missed log. If it fed the median and MAD it would
      // widen the spread enough to hide the genuine 50 day outlier.
      final validities = validitiesFor(const [28, 27, 29, 28, 200, 50]);
      expect(validities[4], CycleValidity.implausiblyLong);
      expect(
        validities[5],
        CycleValidity.unconfirmedOutlier,
        reason: 'the 200 must not mask the 50',
      );
    });

    test('an irregular user is not carpet-flagged', () {
      // Genuinely variable cycles, as in PCOS or perimenopause. Every one of
      // these is plausible, and flagging them all would be both wrong and
      // demoralising (risk R17).
      final validities = validitiesFor(const [24, 35, 28, 42, 31, 26, 38]);
      expect(
        validities.where((v) => v == CycleValidity.unconfirmedOutlier),
        isEmpty,
      );
    });
  });

  group('modifiedZScore', () {
    test('is zero at the centre', () {
      expect(Validation.modifiedZScore(28, 28, 2), 0);
    });

    test('is symmetric about the centre', () {
      expect(
        Validation.modifiedZScore(24, 28, 2),
        Validation.modifiedZScore(32, 28, 2),
      );
    });

    test('scales inversely with the MAD', () {
      final tight = Validation.modifiedZScore(34, 28, 1);
      final loose = Validation.modifiedZScore(34, 28, 3);
      expect(tight, greaterThan(loose));
    });

    test('returns zero when the MAD is zero rather than dividing by it', () {
      expect(Validation.modifiedZScore(40, 28, 0), 0);
    });

    test('matches the documented formula', () {
      // |34 - 28| / (1.4826 * 2) = 6 / 2.9652
      expect(
        Validation.modifiedZScore(34, 28, 2),
        closeTo(6 / (CycleRules.madToSigma * 2), 1e-12),
      );
    });
  });

  group('empty input', () {
    test('assign handles an empty list', () {
      expect(Validation.assign(const <CycleRecord>[]), isEmpty);
    });
  });
}
