/// Clock abstraction.
///
/// Supplies "now" to every part of the app that needs it, so date-dependent
/// logic can be frozen under test. Nothing outside this file reads the device
/// clock directly; `tools/scripts/check_no_datetime_now.sh` fails the build if
/// anything tries.
///
/// Includes:
///     - Clock: Interface returning the current day and instant.
///     - SystemClock: Clock backed by the real device clock.
///     - FixedClock: Clock frozen at one day, for tests.
library;

import 'package:period_tracker/core/date_utils.dart';

/// Source of the current date and time.
///
/// Everything that needs to know "now" takes a [Clock] rather than reading the
/// device clock directly. That keeps date-dependent logic deterministic under
/// test, which matters more here than in most apps: cycle prediction is
/// entirely date arithmetic, and a non-deterministic test suite cannot catch a
/// daylight-saving or timezone bug (risk R7 in `docs/PLAN.md`).
abstract interface class Clock {
  /// Return the current local calendar day.
  ///
  /// Returns:
  ///     CivilDate: Today, resolved in the device's local timezone.
  CivilDate today();

  /// Return the current instant, for log timestamps only.
  ///
  /// Never derive a [CivilDate] from this: use [today], which resolves the
  /// local calendar day. Going through UTC would put users west of Greenwich
  /// on the wrong day for part of every evening.
  ///
  /// Returns:
  ///     DateTime: The current instant, in UTC.
  DateTime nowUtc();
}

/// System clock, reading the real device clock.
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

/// Fixed clock, frozen at one calendar day.
///
/// Prefer this over faking at a higher level: a test that pins the date can
/// assert on exact predicted windows instead of on ranges.
///
/// Attributes:
///     date (CivilDate): The calendar day this clock reports.
///     _instant (DateTime): What [nowUtc] reports, defaulting to midnight UTC
///         on [date].
final class FixedClock implements Clock {
  /// Creates a clock frozen at [date].
  ///
  /// Args:
  ///     date (CivilDate): The day this clock reports as today.
  ///     instant (DateTime, optional): The instant [nowUtc] reports. Defaults
  ///         to midnight UTC on [date].
  FixedClock(this.date, {DateTime? instant})
    : _instant = instant ?? DateTime.utc(date.year, date.month, date.day);

  /// Creates a clock frozen at an ISO-8601 day.
  ///
  /// Args:
  ///     isoDate (String): The day, as `YYYY-MM-DD`.
  ///
  /// Throws:
  ///     FormatException: If [isoDate] is not a valid `YYYY-MM-DD` day.
  FixedClock.iso(String isoDate) : this(CivilDate.parseIso8601(isoDate));

  /// The calendar day this clock reports.
  final CivilDate date;

  /// What [nowUtc] reports. Midnight UTC on [date] unless one was supplied.
  final DateTime _instant;

  /// Return a copy of this clock moved forward by [days].
  ///
  /// This clock is left unchanged, so a test can hold several points on the
  /// same timeline at once.
  ///
  /// Args:
  ///     days (int): Days to advance. Negative values move backwards.
  ///
  /// Returns:
  ///     FixedClock: A new clock [days] later, with its instant moved to
  ///     match.
  FixedClock advanced(int days) => FixedClock(
    date.addDays(days),
    instant: _instant.add(Duration(days: days)),
  );

  @override
  CivilDate today() => date;

  @override
  DateTime nowUtc() => _instant.toUtc();
}
