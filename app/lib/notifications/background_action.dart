/// Background notification action.
///
/// Handles the one-tap log action when the app is not running. Android
/// delivers that tap to a fresh isolate with none of the app's state in it, so
/// everything it needs is rebuilt here from scratch.
///
/// Includes:
///     - handleBackgroundNotificationResponse: The isolate entry point.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';

/// Handle the one-tap log action when the app is not running.
///
/// This is the whole point of the action: the notification arrives in the
/// morning, the user taps "Log period" from the lock screen, and the day is
/// recorded without the app ever coming to the foreground. Android delivers
/// that tap to a **fresh isolate** with none of the app's state in it: no
/// providers, no open database, no localisations. Everything it needs is
/// rebuilt here from scratch.
///
/// Annotated `vm:entry-point` because nothing in the app calls it: the
/// platform looks it up by a handle stored at initialize time, and without the
/// annotation the compiler would strip it out of the release build.
///
/// Steps:
///     1. Ignore anything that is not the log action.
///     2. Bring up the plugin bindings this isolate lacks.
///     3. Open the database without recovery, giving up if it is damaged.
///     4. Mark today through the same repository the UI uses.
///
/// Args:
///     response (NotificationResponse): What the platform delivered.
@pragma('vm:entry-point')
Future<void> handleBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  if (response.actionId != logPeriodActionId) return;

  // The isolate starts with no plugin bindings, and the database directory
  // comes from one (path_provider).
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();

  const clock = SystemClock();
  // The same open, the same integrity check and the same migration the app
  // performs, with recovery declined. See openAppDatabaseWithoutRecovery for
  // why this isolate must not quarantine a damaged file. Null means the day
  // goes unlogged, and the next foreground launch deals with the damage in the
  // open, where there is a screen to say so on.
  final database = await openAppDatabaseWithoutRecovery(
    directory: await defaultDatabaseDirectory(),
  );
  if (database == null) return;

  try {
    await CycleRepository(
      database: database,
      clock: clock,
    ).markPeriodStart(clock.today());
  } on Object {
    // A background write is a convenience, never the only way in. Anything
    // that goes wrong here is recoverable by opening the app and tapping the
    // same thing, so it must not take the isolate down.
    return;
  } finally {
    await database.close();
  }
}
