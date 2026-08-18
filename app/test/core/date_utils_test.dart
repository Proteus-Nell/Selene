import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Bounds for the exhaustive sweeps: 1900-01-01 to 2100-12-31.
///
/// Exhaustive rather than randomly sampled. For a domain this small, iterating
/// every day is both faster to reason about and strictly stronger than a
/// property-test library with a random seed, and it can never flake.
final _sweepStart = CivilDate(1900, 1, 1);
final _sweepEnd = CivilDate(2100, 12, 31);

void main() {
  group('CivilDate epoch round-trip', () {
    test('fromEpochDay and epochDay are exact inverses for every day', () {
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d++) {
        expect(CivilDate.fromEpochDay(d).epochDay, d);
      }
    });

    test('year/month/day round-trip through the validating constructor', () {
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d++) {
        final date = CivilDate.fromEpochDay(d);
        final rebuilt = CivilDate(date.year, date.month, date.day);
        expect(rebuilt.epochDay, d, reason: 'failed at $date');
      }
    });

    test('epoch day 0 is 1970-01-01, a Thursday', () {
      const epoch = CivilDate.fromEpochDay(0);
      expect(epoch.year, 1970);
      expect(epoch.month, 1);
      expect(epoch.day, 1);
      expect(epoch.weekday, 4);
    });
  });

  group('addDays and daysBetween are exact inverses', () {
    test('across a wide range of dates and offsets', () {
      final offsets = <int>[
        -400,
        -366,
        -365,
        -100,
        -31,
        -30,
        -29,
        -8,
        -1,
        0,
        1,
        8,
        27,
        28,
        29,
        30,
        31,
        35,
        60,
        100,
        365,
        366,
        400,
        1000,
      ];
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d += 37) {
        final base = CivilDate.fromEpochDay(d);
        for (final n in offsets) {
          final shifted = base.addDays(n);
          expect(base.daysBetween(shifted), n, reason: '$base + $n');
          expect(shifted.daysBetween(base), -n, reason: '$base + $n reversed');
          expect(shifted.addDays(-n), base, reason: '$base + $n - $n');
        }
      }
    });

    test('daysBetween of a date with itself is zero', () {
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d += 101) {
        final date = CivilDate.fromEpochDay(d);
        expect(date.daysBetween(date), 0);
      }
    });
  });

  group('leap years', () {
    test('known leap and common years', () {
      expect(CivilDate.isLeapYear(2024), isTrue);
      expect(CivilDate.isLeapYear(2000), isTrue, reason: 'divisible by 400');
      expect(CivilDate.isLeapYear(1900), isFalse, reason: 'century, not /400');
      expect(CivilDate.isLeapYear(2100), isFalse, reason: 'century, not /400');
      expect(CivilDate.isLeapYear(2026), isFalse);
    });

    test('29 February exists only in leap years', () {
      expect(CivilDate(2024, 2, 29).toIso8601(), '2024-02-29');
      expect(() => CivilDate(2023, 2, 29), throwsArgumentError);
      expect(() => CivilDate(1900, 2, 29), throwsArgumentError);
      expect(CivilDate(2000, 2, 29).toIso8601(), '2000-02-29');
    });

    test('a leap year is 366 days and a common year 365', () {
      expect(CivilDate(2024, 1, 1).daysBetween(CivilDate(2025, 1, 1)), 366);
      expect(CivilDate(2026, 1, 1).daysBetween(CivilDate(2027, 1, 1)), 365);
      expect(CivilDate(1900, 1, 1).daysBetween(CivilDate(1901, 1, 1)), 365);
      expect(CivilDate(2000, 1, 1).daysBetween(CivilDate(2001, 1, 1)), 366);
    });

    test('stepping across 28 February lands correctly in both year kinds', () {
      expect(CivilDate(2024, 2, 28).addDays(1), CivilDate(2024, 2, 29));
      expect(CivilDate(2024, 2, 28).addDays(2), CivilDate(2024, 3, 1));
      expect(CivilDate(2026, 2, 28).addDays(1), CivilDate(2026, 3, 1));
    });
  });

  group('month and year boundaries', () {
    test('daysInMonth for every month of a leap and common year', () {
      const common = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      const leap = <int>[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        expect(CivilDate.daysInMonth(2026, m), common[m - 1]);
        expect(CivilDate.daysInMonth(2024, m), leap[m - 1]);
      }
    });

    test('crossing a year boundary', () {
      expect(CivilDate(2026, 12, 31).addDays(1), CivilDate(2027, 1, 1));
      expect(CivilDate(2027, 1, 1).addDays(-1), CivilDate(2026, 12, 31));
      expect(
        CivilDate(2026, 12, 31).daysBetween(CivilDate(2027, 1, 1)),
        1,
      );
    });

    test('every month end steps to the first of the next month', () {
      for (var year = 1999; year <= 2101; year++) {
        for (var m = 1; m <= 12; m++) {
          final last = CivilDate(year, m, CivilDate.daysInMonth(year, m));
          final next = last.addDays(1);
          expect(next.day, 1, reason: 'after $last');
          expect(next.month, m == 12 ? 1 : m + 1, reason: 'after $last');
          expect(next.year, m == 12 ? year + 1 : year, reason: 'after $last');
        }
      }
    });

    test('addMonths clamps rather than rolling over', () {
      expect(CivilDate(2026, 1, 31).addMonths(1), CivilDate(2026, 2, 28));
      expect(CivilDate(2024, 1, 31).addMonths(1), CivilDate(2024, 2, 29));
      expect(CivilDate(2026, 3, 31).addMonths(-1), CivilDate(2026, 2, 28));
      expect(CivilDate(2026, 5, 31).addMonths(1), CivilDate(2026, 6, 30));
      expect(CivilDate(2026, 1, 15).addMonths(12), CivilDate(2027, 1, 15));
      expect(CivilDate(2026, 1, 15).addMonths(-13), CivilDate(2024, 12, 15));
    });

    test('addMonths round-trips for day-of-month values that cannot clamp', () {
      for (var m = 1; m <= 12; m++) {
        final d = CivilDate(2026, m, 15);
        expect(d.addMonths(6).addMonths(-6), d);
      }
    });
  });

  group('daylight saving is structurally irrelevant', () {
    // CivilDate holds no time of day, so a DST transition cannot change a day
    // count. These cases pin real transition dates so the guarantee is
    // documented and would fail loudly if the representation ever changed to
    // something instant-based.
    test('US spring forward 2026-03-08 does not lose a day', () {
      final before = CivilDate(2026, 3, 7);
      final after = CivilDate(2026, 3, 9);
      expect(before.daysBetween(after), 2);
      expect(before.addDays(1), CivilDate(2026, 3, 8));
    });

    test('US fall back 2026-11-01 does not gain a day', () {
      final before = CivilDate(2026, 10, 31);
      final after = CivilDate(2026, 11, 2);
      expect(before.daysBetween(after), 2);
    });

    test('EU transitions 2026-03-29 and 2026-10-25', () {
      expect(
        CivilDate(2026, 3, 28).daysBetween(CivilDate(2026, 3, 30)),
        2,
      );
      expect(
        CivilDate(2026, 10, 24).daysBetween(CivilDate(2026, 10, 26)),
        2,
      );
    });

    test('a 28 day cycle spanning a transition is still 28 days', () {
      final start = CivilDate(2026, 2, 20);
      final next = start.addDays(28);
      expect(next, CivilDate(2026, 3, 20));
      expect(start.daysBetween(next), 28);
    });
  });

  group('ISO-8601 formatting and parsing', () {
    test('format is zero padded', () {
      expect(CivilDate(2026, 1, 2).toIso8601(), '2026-01-02');
      expect(CivilDate(2026, 12, 31).toIso8601(), '2026-12-31');
    });

    test('parse round-trips across the full sweep', () {
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d += 13) {
        final date = CivilDate.fromEpochDay(d);
        expect(CivilDate.parseIso8601(date.toIso8601()), date);
      }
    });

    test('parser rejects anything that is not strict YYYY-MM-DD', () {
      const bad = <String>[
        '2026-1-2',
        '2026/01/02',
        '2026-01-02T00:00:00',
        '2026-01-02Z',
        '20260102',
        '',
        'not a date',
        '2026-13-01',
        '2026-00-01',
        '2026-02-30',
      ];
      for (final value in bad) {
        expect(
          () => CivilDate.parseIso8601(value),
          anyOf(throwsFormatException, throwsArgumentError),
          reason: 'accepted $value',
        );
      }
    });
  });

  group('validation rejects impossible dates', () {
    test('month out of range', () {
      expect(() => CivilDate(2026, 0, 1), throwsArgumentError);
      expect(() => CivilDate(2026, 13, 1), throwsArgumentError);
    });

    test('day out of range for the month', () {
      expect(() => CivilDate(2026, 1, 0), throwsArgumentError);
      expect(() => CivilDate(2026, 1, 32), throwsArgumentError);
      expect(() => CivilDate(2026, 4, 31), throwsArgumentError);
      expect(() => CivilDate(2026, 2, 30), throwsArgumentError);
    });
  });

  group('ordering and equality', () {
    test('comparison operators agree with epoch day order', () {
      final a = CivilDate(2026, 3, 1);
      final b = CivilDate(2026, 3, 2);
      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(b > a, isTrue);
      expect(b >= a, isTrue);
      expect(a <= a, isTrue);
      expect(a >= a, isTrue);
      expect(a < a, isFalse);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), 0);
    });

    test('equality and hashCode are by value', () {
      expect(CivilDate(2026, 3, 1), CivilDate(2026, 3, 1));
      expect(CivilDate(2026, 3, 1).hashCode, CivilDate(2026, 3, 1).hashCode);
      expect(CivilDate(2026, 3, 1), isNot(CivilDate(2026, 3, 2)));
    });

    test('sorting a shuffled list of dates', () {
      final dates = <CivilDate>[
        CivilDate(2026, 5, 1),
        CivilDate(2024, 2, 29),
        CivilDate(2026, 1, 1),
        CivilDate(2025, 12, 31),
      ]..sort();
      expect(
        dates.map((d) => d.toIso8601()).toList(),
        <String>['2024-02-29', '2025-12-31', '2026-01-01', '2026-05-01'],
      );
    });

    test('isBetweenInclusive includes both endpoints', () {
      final from = CivilDate(2026, 3, 1);
      final to = CivilDate(2026, 3, 5);
      expect(from.isBetweenInclusive(from, to), isTrue);
      expect(to.isBetweenInclusive(from, to), isTrue);
      expect(CivilDate(2026, 3, 3).isBetweenInclusive(from, to), isTrue);
      expect(CivilDate(2026, 2, 28).isBetweenInclusive(from, to), isFalse);
      expect(CivilDate(2026, 3, 6).isBetweenInclusive(from, to), isFalse);
    });
  });

  group('weekday', () {
    test('known reference dates', () {
      // 1970-01-01 Thursday, 2000-01-01 Saturday, 2026-08-17 Monday.
      expect(CivilDate(1970, 1, 1).weekday, 4);
      expect(CivilDate(2000, 1, 1).weekday, 6);
      expect(CivilDate(2026, 8, 17).weekday, 1);
    });

    test('weekday cycles with period 7 and stays in 1..7', () {
      for (var d = _sweepStart.epochDay; d <= _sweepEnd.epochDay; d += 7) {
        final date = CivilDate.fromEpochDay(d);
        expect(date.weekday, inInclusiveRange(1, 7));
        expect(date.addDays(7).weekday, date.weekday);
      }
    });
  });

  group('DateTime boundary conversions', () {
    test('fromDateTime takes the local calendar day', () {
      final local = DateTime(2026, 3, 14, 23, 59, 59);
      expect(CivilDate.fromDateTime(local), CivilDate(2026, 3, 14));
    });

    test('toLocalMidnight then back is identity', () {
      for (
        var d = CivilDate(2020, 1, 1).epochDay;
        d <= CivilDate(2030, 12, 31).epochDay;
        d++
      ) {
        final date = CivilDate.fromEpochDay(d);
        expect(CivilDate.fromDateTime(date.toLocalMidnight()), date);
      }
    });
  });

  group('CivilDateRange', () {
    test('length counts inclusively', () {
      expect(
        CivilDateRange(
          CivilDate(2026, 3, 1),
          CivilDate(2026, 3, 1),
        ).lengthInDays,
        1,
      );
      expect(
        CivilDateRange(
          CivilDate(2026, 3, 1),
          CivilDate(2026, 3, 5),
        ).lengthInDays,
        5,
      );
    });

    test('contains matches the inclusive bounds', () {
      final range = CivilDateRange(
        CivilDate(2026, 3, 10),
        CivilDate(2026, 3, 14),
      );
      expect(range.contains(CivilDate(2026, 3, 10)), isTrue);
      expect(range.contains(CivilDate(2026, 3, 14)), isTrue);
      expect(range.contains(CivilDate(2026, 3, 9)), isFalse);
      expect(range.contains(CivilDate(2026, 3, 15)), isFalse);
    });

    test('an inverted range is rejected', () {
      expect(
        () => CivilDateRange(CivilDate(2026, 3, 5), CivilDate(2026, 3, 1)),
        throwsArgumentError,
      );
    });

    test('equality is by value', () {
      expect(
        CivilDateRange(CivilDate(2026, 3, 1), CivilDate(2026, 3, 5)),
        CivilDateRange(CivilDate(2026, 3, 1), CivilDate(2026, 3, 5)),
      );
    });
  });
}
