import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';

/// Handles the one-tap log action when the app is not running.
///
/// This is the whole point of the action: the notification arrives in the
/// morning, the user taps "Log period" from the lock screen, and the day is
/// recorded without the app ever coming to the foreground. Android delivers
/// that tap to a **fresh isolate** with none of the app's state in it — no
/// providers, no open database, no localisations — so everything it needs is
/// rebuilt here from scratch.
///
/// Annotated `vm:entry-point` because nothing in the app calls it: the platform
/// looks it up by a handle stored at initialize time, and without the
/// annotation the compiler would strip it out of the release build.
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
  final file = File(
    p.join((await defaultDatabaseDirectory()).path, databaseFileName),
  );
  // Deliberately not `openAppDatabase`: that recovers from a damaged file by
  // moving it aside, which is the right call when a person is watching and can
  // be told, and the wrong one to make invisibly from a background isolate. If
  // the file is missing or unreadable, this does nothing and the next launch
  // handles it in the open, where the UI can say what happened.
  if (!file.existsSync()) return;

  AppDatabase? database;
  try {
    database = AppDatabase(createQueryExecutor(file));
    await CycleRepository(
      database: database,
      clock: clock,
    ).markPeriodStart(clock.today());
  } on Object {
    // A background write is a convenience, never the only way in. Anything that
    // goes wrong here is recoverable by opening the app and tapping the same
    // thing, so it must not crash the isolate.
    return;
  } finally {
    await database?.close();
  }
}
