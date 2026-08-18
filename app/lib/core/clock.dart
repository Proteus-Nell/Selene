import 'package:period_tracker/core/date_utils.dart';

/// Source of the current date and time.
///
/// Everything that needs to know "now" takes a [Clock] rather than reading the
/// device clock directly. That keeps date-dependent logic deterministic under
/// test, which matters more here than in most apps: cycle prediction is
/// entirely date arithmetic, and a non-deterministic test suite cannot catch a
/// daylight-saving or timezone bug (risk R7 in `docs/PLAN.md`).
abstract interface class Clock {
  /// The current local calendar day.
  CivilDate today();

  /// The current instant in UTC. For log timestamps only.
  ///
  /// Never derive a [CivilDate] from this: use [today], which resolves the
  /// local calendar day. Going through UTC would put users west of Greenwich on
  /// the wrong day for part of every evening.
  DateTime nowUtc();
}

/// A [Clock] backed by the real device clock.
///
/// This file is the single place in `lib/` permitted to call [DateTime.now],
/// enforced by `tools/scripts/check_no_datetime_now.sh` in pre-commit and CI.
final class SystemClock implements Clock {
  /// Creates a clock that reads the device.
  const SystemClock();

  @override
  CivilDate today() => CivilDate.fromDateTime(DateTime.now());

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A [Clock] frozen at a fixed point, for tests.
///
/// Prefer this over faking at a higher level: a test that pins the date can
/// assert on exact predicted windows instead of on ranges.
final class FixedClock implements Clock {
  /// Creates a clock frozen at [date], with an optional explicit [instant].
  FixedClock(this.date, {DateTime? instant})
    : _instant = instant ?? DateTime.utc(date.year, date.month, date.day);

  /// Creates a clock frozen at the given ISO-8601 `YYYY-MM-DD` day.
  FixedClock.iso(String isoDate) : this(CivilDate.parseIso8601(isoDate));

  /// The calendar day this clock reports.
  final CivilDate date;

  final DateTime _instant;

  /// Returns a new clock advanced by [days], leaving this one unchanged.
  FixedClock advanced(int days) => FixedClock(
    date.addDays(days),
    instant: _instant.add(Duration(days: days)),
  );

  @override
  CivilDate today() => date;

  @override
  DateTime nowUtc() => _instant.toUtc();
}
