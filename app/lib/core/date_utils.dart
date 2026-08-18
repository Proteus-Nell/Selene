import 'package:meta/meta.dart';

/// A timezone-naive calendar date: a year, a month and a day, with no time of
/// day and no timezone.
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
@immutable
final class CivilDate implements Comparable<CivilDate> {
  /// Creates a date from its [year], [month] (1..12) and [day] (1..31).
  ///
  /// Throws [ArgumentError] if the components do not form a real date, so
  /// 2026-02-30 is rejected rather than silently rolling into March the way
  /// [DateTime] does. Silent rollover is how a mistyped log becomes a wrong
  /// cycle length that nobody notices.
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

  /// Creates a date directly from a count of days since 1970-01-01.
  const CivilDate.fromEpochDay(this.epochDay);

  /// Parses a strict `YYYY-MM-DD` string.
  ///
  /// Deliberately stricter than [DateTime.parse]: no time component, no
  /// timezone suffix, no leniency. Import and export use this format, so a
  /// permissive parser here would let malformed files through.
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

  /// The local calendar day containing [instant].
  ///
  /// One of only two boundary points where [DateTime] meets [CivilDate]; the
  /// other is [toLocalMidnight]. Keep those boundaries thin: everything above
  /// them should deal in [CivilDate] only.
  factory CivilDate.fromDateTime(DateTime instant) {
    final local = instant.isUtc ? instant.toLocal() : instant;
    return CivilDate(local.year, local.month, local.day);
  }

  /// Days elapsed since 1970-01-01. Negative for earlier dates.
  final int epochDay;

  /// Whether [year] is a leap year in the proleptic Gregorian calendar.
  static bool isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  /// The number of days in [month] of [year], accounting for leap years.
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

  ({int year, int month, int day}) get _civil => _civilFromDays(epochDay);

  /// This date shifted by [days], which may be negative.
  ///
  /// Exact: `d.addDays(n).daysBetween(d) == -n` for every `d` and `n`.
  CivilDate addDays(int days) => CivilDate.fromEpochDay(epochDay + days);

  /// The number of days from this date forward to [other].
  ///
  /// Positive when [other] is later, negative when earlier, zero when equal.
  /// The exact inverse of [addDays].
  int daysBetween(CivilDate other) => other.epochDay - epochDay;

  /// This date shifted by [months], clamping the day to the target month.
  ///
  /// 2026-01-31 plus one month is 2026-02-28, not 2026-03-03. Clamping is the
  /// behaviour a calendar UI needs; rolling over surprises people.
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

  /// Local midnight at the start of this calendar day.
  ///
  /// The second of the two [DateTime] boundary points. Note that on a
  /// spring-forward day in some timezones local midnight may not exist as a
  /// wall-clock instant; [DateTime] normalises that, which is precisely why the
  /// rest of the app never round-trips through this method.
  DateTime toLocalMidnight() => DateTime(year, month, day);

  /// Strict `YYYY-MM-DD` representation. The storage and export format.
  String toIso8601() {
    final y = year.abs().toString().padLeft(4, '0');
    final sign = year < 0 ? '-' : '';
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$sign$y-$m-$d';
  }

  /// Whether this date falls in the inclusive range [from]..[to].
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

/// An inclusive span of calendar days, used for predicted windows.
@immutable
final class CivilDateRange {
  /// Creates a range from [start] to [end] inclusive.
  ///
  /// Throws [ArgumentError] if [end] precedes [start]; an inverted window is
  /// always a bug rather than an empty result.
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

  /// Whether [date] falls within this range.
  bool contains(CivilDate date) => date.isBetweenInclusive(start, end);

  @override
  bool operator ==(Object other) =>
      other is CivilDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start.toIso8601()}..${end.toIso8601()}';
}

/// Days since 1970-01-01 for a civil date. Exact for all Gregorian dates.
int _daysFromCivil(int year, int month, int day) {
  final y = year - (month <= 2 ? 1 : 0);
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yearOfEra = y - era * 400;
  final dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) ~/ 5 + day - 1;
  final dayOfEra =
      yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra - 719468;
}

/// Inverse of [_daysFromCivil].
({int year, int month, int day}) _civilFromDays(int epochDay) {
  final z = epochDay + 719468;
  final era = (z >= 0 ? z : z - 146096) ~/ 146097;
  final dayOfEra = z - era * 146097;
  final yearOfEra =
      (dayOfEra - dayOfEra ~/ 1460 + dayOfEra ~/ 36524 - dayOfEra ~/ 146096) ~/
      365;
  final y = yearOfEra + era * 400;
  final dayOfYear =
      dayOfEra - (365 * yearOfEra + yearOfEra ~/ 4 - yearOfEra ~/ 100);
  final mp = (5 * dayOfYear + 2) ~/ 153;
  final d = dayOfYear - (153 * mp + 2) ~/ 5 + 1;
  final m = mp + (mp < 10 ? 3 : -9);
  return (year: y + (m <= 2 ? 1 : 0), month: m, day: d);
}
