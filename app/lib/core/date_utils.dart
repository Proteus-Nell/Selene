/// Calendar date arithmetic.
///
/// Defines the timezone-naive date type the whole app counts in, plus the
/// inclusive range built on it. Every operation is integer arithmetic on a day
/// number, so there is no hour for a daylight-saving transition to shift.
///
/// Includes:
///     - CivilDate: A year, month and day, stored as one integer.
///     - CivilDateRange: An inclusive span of those days.
library;

import 'package:meta/meta.dart';

/// Civil date: a year, a month and a day, with no time of day and no
/// timezone.
///
/// This is the canonical date type across the whole app. When someone says "my
/// period started on the 14th" they mean a calendar day in their own local
/// reckoning, not an instant on a global timeline. Storing instants instead
/// makes cycle lengths shift under daylight-saving transitions and travel,
/// which risk R7 in `docs/PLAN.md` rates as the highest-probability
/// correctness bug in this project.
///
/// Internally a [CivilDate] is exactly one integer: [epochDay], the number of
/// days since 1970-01-01. Every operation is integer arithmetic, so [addDays]
/// and [daysBetween] are exact inverses by construction, and because there is
/// no hour there is no daylight saving to get wrong. Correctness here is
/// structural rather than merely tested.
///
/// The conversions are Howard Hinnant's `days_from_civil` and
/// `civil_from_days`, which are exact for the proleptic Gregorian calendar.
///
/// Attributes:
///     epochDay (int): Days elapsed since 1970-01-01, negative for earlier
///         dates. The only stored field.
@immutable
final class CivilDate implements Comparable<CivilDate> {
  /// Create a date from its calendar components.
  ///
  /// Rejects a date that does not exist rather than silently rolling it into
  /// the next month the way [DateTime] does. Silent rollover is how a mistyped
  /// log becomes a wrong cycle length that nobody notices.
  ///
  /// Args:
  ///     year (int): The calendar year. May be negative.
  ///     month (int): The month, 1..12.
  ///     day (int): The day of the month, 1..31 depending on the month.
  ///
  /// Throws:
  ///     ArgumentError: If the components do not form a real date, so
  ///         2026-02-30 is refused.
  factory CivilDate(int year, int month, int day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1..12');
    }
    final maxDay = daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw ArgumentError.value(
        day,
        'day',
        'must be 1..$maxDay for $year-$month',
      );
    }
    return CivilDate.fromEpochDay(_daysFromCivil(year, month, day));
  }

  /// Create a date directly from a count of days since 1970-01-01.
  ///
  /// Args:
  ///     epochDay (int): Days since 1970-01-01. Negative for earlier dates.
  const CivilDate.fromEpochDay(this.epochDay);

  /// Parse a strict `YYYY-MM-DD` string.
  ///
  /// Deliberately stricter than [DateTime.parse]: no time component, no
  /// timezone suffix, no leniency. Import and export use this format, so a
  /// permissive parser here would let malformed files through.
  ///
  /// Args:
  ///     value (String): The candidate date string.
  ///
  /// Throws:
  ///     FormatException: If [value] is not exactly `YYYY-MM-DD`.
  ///     ArgumentError: If it parses but names a date that does not exist.
  factory CivilDate.parseIso8601(String value) {
    final match = RegExp(r'^(-?\d{4,})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('expected strict YYYY-MM-DD', value);
    }
    return CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Create the local calendar day containing an instant.
  ///
  /// One of only two boundary points where [DateTime] meets [CivilDate]; the
  /// other is [toLocalMidnight]. Keep those boundaries thin: everything above
  /// them should deal in [CivilDate] only.
  ///
  /// Args:
  ///     instant (DateTime): The instant to place. Converted to local time
  ///         first if it is in UTC.
  ///
  /// Returns:
  ///     CivilDate: The local calendar day [instant] falls in.
  factory CivilDate.fromDateTime(DateTime instant) {
    final local = instant.isUtc ? instant.toLocal() : instant;
    return CivilDate(local.year, local.month, local.day);
  }

  /// Days elapsed since 1970-01-01. Negative for earlier dates.
  final int epochDay;

  /// Report whether a year is a leap year in the proleptic Gregorian
  /// calendar.
  ///
  /// Args:
  ///     year (int): The year to test.
  ///
  /// Returns:
  ///     bool: True when the year has a 29 February.
  static bool isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  /// Return the number of days in a month, accounting for leap years.
  ///
  /// Args:
  ///     year (int): The calendar year, which decides February's length.
  ///     month (int): The month, 1..12.
  ///
  /// Returns:
  ///     int: Days in that month, 28..31.
  ///
  /// Throws:
  ///     ArgumentError: If [month] is outside 1..12.
  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1..12');
    }
    if (month == 2 && isLeapYear(year)) return 29;
    const lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return lengths[month - 1];
  }

  /// The calendar year.
  int get year => _civil.year;

  /// The calendar month, 1..12.
  int get month => _civil.month;

  /// The day of the month, 1..31.
  int get day => _civil.day;

  /// ISO-8601 weekday: 1 is Monday through 7 is Sunday.
  ///
  /// Epoch day 0 (1970-01-01) was a Thursday, hence the offset of 3.
  int get weekday => (epochDay + 3) % 7 + 1;

  /// The components of this date, recomputed from [epochDay] on each read.
  ({int year, int month, int day}) get _civil => _civilFromDays(epochDay);

  /// Return this date shifted by a number of days.
  ///
  /// Exact: `d.addDays(n).daysBetween(d) == -n` for every `d` and `n`.
  ///
  /// Args:
  ///     days (int): Days to move. Negative values move backwards.
  ///
  /// Returns:
  ///     CivilDate: The shifted date.
  CivilDate addDays(int days) => CivilDate.fromEpochDay(epochDay + days);

  /// Return the number of days from this date forward to another.
  ///
  /// The exact inverse of [addDays].
  ///
  /// Args:
  ///     other (CivilDate): The date to count to.
  ///
  /// Returns:
  ///     int: Positive when [other] is later, negative when earlier, zero
  ///     when equal.
  int daysBetween(CivilDate other) => other.epochDay - epochDay;

  /// Return this date shifted by a number of months, clamping the day.
  ///
  /// 2026-01-31 plus one month is 2026-02-28, not 2026-03-03. Clamping is the
  /// behaviour a calendar UI needs; rolling over surprises people.
  ///
  /// Args:
  ///     months (int): Months to move. Negative values move backwards.
  ///
  /// Returns:
  ///     CivilDate: The shifted date, with the day clamped to the length of
  ///     the target month.
  CivilDate addMonths(int months) {
    final zeroBased = year * 12 + (month - 1) + months;
    final targetYear = zeroBased >= 0
        ? zeroBased ~/ 12
        : -(((-zeroBased) + 11) ~/ 12);
    final targetMonth = zeroBased - targetYear * 12 + 1;
    final clampedDay = day <= daysInMonth(targetYear, targetMonth)
        ? day
        : daysInMonth(targetYear, targetMonth);
    return CivilDate(targetYear, targetMonth, clampedDay);
  }

  /// Return local midnight at the start of this calendar day.
  ///
  /// The second of the two [DateTime] boundary points. Note that on a
  /// spring-forward day in some timezones local midnight may not exist as a
  /// wall-clock instant; [DateTime] normalises that, which is precisely why
  /// the rest of the app never round-trips through this method.
  ///
  /// Returns:
  ///     DateTime: Local midnight, in the device's current timezone.
  DateTime toLocalMidnight() => DateTime(year, month, day);

  /// Return the strict `YYYY-MM-DD` form. The storage and export format.
  ///
  /// Returns:
  ///     String: The date, zero-padded, with a leading minus for negative
  ///     years.
  String toIso8601() {
    final y = year.abs().toString().padLeft(4, '0');
    final sign = year < 0 ? '-' : '';
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$sign$y-$m-$d';
  }

  /// Report whether this date falls in an inclusive range.
  ///
  /// Args:
  ///     from (CivilDate): First day of the range, inclusive.
  ///     to (CivilDate): Last day of the range, inclusive.
  ///
  /// Returns:
  ///     bool: True when this date is within the range at either end.
  bool isBetweenInclusive(CivilDate from, CivilDate to) =>
      epochDay >= from.epochDay && epochDay <= to.epochDay;

  @override
  int compareTo(CivilDate other) => epochDay.compareTo(other.epochDay);

  /// Whether this date is strictly before [other].
  bool operator <(CivilDate other) => epochDay < other.epochDay;

  /// Whether this date is before or equal to [other].
  bool operator <=(CivilDate other) => epochDay <= other.epochDay;

  /// Whether this date is strictly after [other].
  bool operator >(CivilDate other) => epochDay > other.epochDay;

  /// Whether this date is after or equal to [other].
  bool operator >=(CivilDate other) => epochDay >= other.epochDay;

  @override
  bool operator ==(Object other) =>
      other is CivilDate && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() => toIso8601();
}

/// Civil date range: an inclusive span of calendar days.
///
/// Used for predicted windows, where both ends are days the prediction covers
/// rather than a half-open interval.
///
/// Attributes:
///     start (CivilDate): First day of the range, inclusive.
///     end (CivilDate): Last day of the range, inclusive.
@immutable
final class CivilDateRange {
  /// Create a range covering both endpoints.
  ///
  /// Args:
  ///     start (CivilDate): First day, inclusive.
  ///     end (CivilDate): Last day, inclusive. Must not precede [start].
  ///
  /// Throws:
  ///     ArgumentError: If [end] precedes [start]. An inverted window is
  ///         always a bug rather than an empty result.
  CivilDateRange(this.start, this.end) {
    if (end < start) {
      throw ArgumentError('end ($end) precedes start ($start)');
    }
  }

  /// First day of the range, inclusive.
  final CivilDate start;

  /// Last day of the range, inclusive.
  final CivilDate end;

  /// Number of days covered. A single-day range has a length of 1.
  int get lengthInDays => start.daysBetween(end) + 1;

  /// Report whether a date falls within this range.
  ///
  /// Args:
  ///     date (CivilDate): The day to test.
  ///
  /// Returns:
  ///     bool: True when [date] is within the range at either end.
  bool contains(CivilDate date) => date.isBetweenInclusive(start, end);

  @override
  bool operator ==(Object other) =>
      other is CivilDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start.toIso8601()}..${end.toIso8601()}';
}

/// Convert a civil date to days since 1970-01-01.
///
/// Howard Hinnant's `days_from_civil`, exact for every proleptic Gregorian
/// date. The era arithmetic shifts the year so that March starts it, which is
/// what removes February's leap day from the middle of the calculation.
///
/// Args:
///     year (int): The calendar year.
///     month (int): The month, 1..12.
///     day (int): The day of the month.
///
/// Returns:
///     int: Days since 1970-01-01, negative for earlier dates.
int _daysFromCivil(int year, int month, int day) {
  final y = year - (month <= 2 ? 1 : 0);
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yearOfEra = y - era * 400; // 0..399
  final dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) ~/ 5 + day - 1;
  final dayOfEra =
      yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra - 719468; // 146097 days per 400-year era
}

/// Convert days since 1970-01-01 back to a civil date.
///
/// Inverse of [_daysFromCivil], and exact over the same range.
///
/// Args:
///     epochDay (int): Days since 1970-01-01.
///
/// Returns:
///     ({int year, int month, int day}): The calendar components.
({int year, int month, int day}) _civilFromDays(int epochDay) {
  final z = epochDay + 719468; // shift the epoch to 0000-03-01
  final era = (z >= 0 ? z : z - 146096) ~/ 146097;
  final dayOfEra = z - era * 146097; // 0..146096
  final yearOfEra =
      (dayOfEra - dayOfEra ~/ 1460 + dayOfEra ~/ 36524 - dayOfEra ~/ 146096) ~/
      365; // 0..399
  final y = yearOfEra + era * 400;
  final dayOfYear =
      dayOfEra - (365 * yearOfEra + yearOfEra ~/ 4 - yearOfEra ~/ 100);
  final mp = (5 * dayOfYear + 2) ~/ 153; // 0..11, March-based
  final d = dayOfYear - (153 * mp + 2) ~/ 5 + 1;
  final m = mp + (mp < 10 ? 3 : -9); // back to a January-based month
  return (year: y + (m <= 2 ? 1 : 0), month: m, day: d);
}
