// When a scheduled reminder actually fires.
//
// The bug this pins was invisible everywhere a test could normally look. The
// code read `tz.TZDateTime.local(y, m, d, 9)`, which is exactly what the
// plugin's own examples show — but `initializeTimeZones()` leaves `tz.local`
// set to UTC, and only a platform plugin can supply the zone name that would
// change it. So every reminder was scheduled for 09:00 **UTC**: 01:00 in Los
// Angeles, 20:00 in Sydney, and the wrong day in Honolulu. The unit tests
// passed, the golden tests passed, and the on-device smoke run passed, because
// none of them waits for a notification to fire.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The instant the gateway schedules [date] for, expressed as UTC millis.
///
/// Calls the shipping code rather than restating it. An earlier draft of this
/// test recomputed the same expression locally, which would have agreed with
/// itself whatever the gateway did — the exact shape of the bug it is here to
/// catch.
int scheduledInstant(CivilDate date) =>
    LocalNotificationGateway.fireInstantFor(date).millisecondsSinceEpoch;

void main() {
  final date = CivilDate.parseIso8601('2026-07-10');

  test("a reminder is scheduled for 09:00 in the device's own time", () {
    // The plain Dart expression for "09:00 local on that date". Dart applies
    // the device's zone rules itself, which is the whole reason this needs no
    // timezone database and no extra plugin.
    final wanted = DateTime(date.year, date.month, date.day, 9);
    expect(scheduledInstant(date), wanted.millisecondsSinceEpoch);
  });

  test('the fire hour is a morning hour, not midnight', () {
    // A reminder that lands at 00:00, while the phone is face down on a bedside
    // table, has been spent for nothing.
    expect(LocalNotificationGateway.fireHour, inInclusiveRange(7, 11));
  });

  test('initializeTimeZones leaves tz.local as UTC, which is the trap', () {
    // Named explicitly so nobody "simplifies" the gateway back to
    // TZDateTime.local. Loading the database does not discover the device's
    // zone — it resets local to UTC — and only a platform plugin can supply the
    // IANA name that would change that. The app therefore never uses tz.local.
    tz_data.initializeTimeZones();
    expect(tz.local.name, 'Etc/UTC');

    final viaLocal = tz.TZDateTime.local(date.year, date.month, date.day, 9);
    expect(
      viaLocal.toUtc().hour,
      9,
      reason:
          'TZDateTime.local produced 09:00 UTC, which is 09:00 only for '
          'users who happen to live there',
    );
  });
}
