import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';

void main() {
  group('completeness', () {
    test('a cycle without a next start is still in progress', () {
      final cycle = CycleRecord(startDate: CivilDate(2026, 8, 1));
      expect(cycle.isComplete, isFalse);
      expect(cycle.lengthInDays, isNull);
      expect(cycle.span, isNull);
    });

    test('a cycle with a next start is a complete observation', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 8, 29),
      );
      expect(cycle.isComplete, isTrue);
      expect(cycle.lengthInDays, 28);
    });

    test('length is measured start to start', () {
      // Start-to-start is the standard definition and the quantity the model
      // works in. Bleeding duration is a separate, independent measure.
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 1, 1),
        bleedingEndDate: CivilDate(2026, 1, 5),
        nextStartDate: CivilDate(2026, 1, 30),
      );
      expect(cycle.lengthInDays, 29);
      expect(cycle.bleedingDays, 5);
    });

    test('length is correct across a year boundary', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 12, 20),
        nextStartDate: CivilDate(2027, 1, 17),
      );
      expect(cycle.lengthInDays, 28);
    });

    test('length is correct across a leap day', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2024, 2, 20),
        nextStartDate: CivilDate(2024, 3, 19),
      );
      expect(cycle.lengthInDays, 28);
    });
  });

  group('bleeding days', () {
    test('are counted inclusively', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        bleedingEndDate: CivilDate(2026, 8, 1),
      );
      expect(cycle.bleedingDays, 1, reason: 'a one day period is 1, not 0');
    });

    test('are null when the end was never recorded', () {
      final cycle = CycleRecord(startDate: CivilDate(2026, 8, 1));
      expect(cycle.bleedingDays, isNull);
      expect(cycle.bleedingSpan, isNull);
    });

    test('bleedingSpan covers start through end inclusive', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        bleedingEndDate: CivilDate(2026, 8, 5),
      );
      expect(cycle.bleedingSpan!.lengthInDays, 5);
    });
  });

  group('span', () {
    test('ends the day before the next cycle starts', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 8, 29),
      );
      expect(cycle.span!.start, CivilDate(2026, 8, 1));
      expect(cycle.span!.end, CivilDate(2026, 8, 28));
      expect(cycle.span!.lengthInDays, cycle.lengthInDays);
    });
  });

  group('validity gates model use', () {
    test('a complete, ok cycle is usable', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 8, 29),
      );
      expect(cycle.validity, CycleValidity.ok, reason: 'ok is the default');
      expect(cycle.isUsableObservation, isTrue);
    });

    test('an in-progress cycle is not usable however valid', () {
      final cycle = CycleRecord(startDate: CivilDate(2026, 8, 1));
      expect(cycle.isUsableObservation, isFalse);
    });

    test('every non-ok validity makes a complete cycle unusable', () {
      for (final validity in CycleValidity.values) {
        final cycle = CycleRecord(
          startDate: CivilDate(2026, 8, 1),
          nextStartDate: CivilDate(2026, 8, 29),
          validity: validity,
        );
        expect(
          cycle.isUsableObservation,
          validity == CycleValidity.ok,
          reason: '$validity',
        );
      }
    });

    test('a flagged cycle still keeps all of its data', () {
      // Flagged means down-weighted by the model, never discarded. The user
      // entered it, so it stays visible and correctable.
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 12, 1),
        validity: CycleValidity.implausiblyLong,
      );
      expect(cycle.lengthInDays, 122);
      expect(cycle.startDate, CivilDate(2026, 8, 1));
      expect(cycle.isUsableObservation, isFalse);
    });
  });

  group('value semantics', () {
    test('equality is by value', () {
      final a = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 8, 29),
      );
      final b = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        nextStartDate: CivilDate(2026, 8, 29),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith leaves the original untouched', () {
      final original = CycleRecord(startDate: CivilDate(2026, 8, 1));
      final copy = original.copyWith(nextStartDate: CivilDate(2026, 8, 29));
      expect(original.isComplete, isFalse);
      expect(copy.isComplete, isTrue);
      expect(copy.lengthInDays, 28);
    });
  });

  group('JSON round-trip', () {
    test('a complete cycle survives a round-trip', () {
      final cycle = CycleRecord(
        startDate: CivilDate(2026, 8, 1),
        bleedingEndDate: CivilDate(2026, 8, 5),
        nextStartDate: CivilDate(2026, 8, 29),
        validity: CycleValidity.unconfirmedOutlier,
      );
      expect(CycleRecord.fromJson(cycle.toJson()), cycle);
    });

    test('nullable dates survive as null', () {
      final cycle = CycleRecord(startDate: CivilDate(2026, 8, 1));
      final json = cycle.toJson();
      expect(json['bleedingEndDate'], isNull);
      expect(json['nextStartDate'], isNull);
      expect(CycleRecord.fromJson(json), cycle);
    });

    test('dates are encoded as plain YYYY-MM-DD strings', () {
      final json = CycleRecord(
        startDate: CivilDate(2026, 1, 2),
        nextStartDate: CivilDate(2026, 1, 30),
      ).toJson();
      expect(json['startDate'], '2026-01-02');
      expect(json['nextStartDate'], '2026-01-30');
    });

    test('round-trips for every validity', () {
      for (final validity in CycleValidity.values) {
        final cycle = CycleRecord(
          startDate: CivilDate(2026, 8, 1),
          validity: validity,
        );
        expect(
          CycleRecord.fromJson(cycle.toJson()),
          cycle,
          reason: '$validity',
        );
      }
    });
  });
}
