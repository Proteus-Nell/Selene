import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/app.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/scheduler.dart';
import 'package:period_tracker/routing/router.dart';

/// The file a damaged database was moved aside to, if that happened on this
/// launch.
///
/// Null on a normal start. When it is set, the user's history is in that file
/// and the app is running on an empty database, so the UI must say so and offer
/// an import rather than looking like it deleted everything
/// (`docs/PLAN.md` 5.5).
final Provider<File?> quarantinedDatabaseProvider = Provider<File?>(
  (ref) => null,
);

/// Starts the app.
///
/// The three outcomes of opening the database are all handled here, because two
/// of them are not errors to log and move past: one means the user's data needs
/// recovering, and the other means this build must not write to the file at
/// all.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const clock = SystemClock();
  final logger = RingLogger(clock: clock)..info(LogEvent.appStarted);

  final outcome = await openAppDatabase(
    directory: await defaultDatabaseDirectory(),
    clock: clock,
    logger: logger,
  );

  switch (outcome) {
    case DatabaseRefusedNewerSchema(
      :final storedVersion,
      :final supportedVersion,
    ):
      runApp(
        UnreadableDataApp(
          storedVersion: storedVersion,
          supportedVersion: supportedVersion,
        ),
      );
    case DatabaseOpened(:final database):
      runApp(
        await buildAppScope(database: database, clock: clock, logger: logger),
      );
    case DatabaseRecoveredFromCorruption(
      :final database,
      :final quarantinedFile,
    ):
      runApp(
        await buildAppScope(
          database: database,
          clock: clock,
          logger: logger,
          quarantined: quarantinedFile,
        ),
      );
  }
}

/// Wraps the app in a [ProviderScope] carrying the opened database.
///
/// Exposed so a widget test can build the same tree over an in-memory database
/// instead of duplicating the override list and drifting from it.
Future<Widget> buildAppScope({
  required AppDatabase database,
  required Clock clock,
  required RingLogger logger,
  File? quarantined,
}) async {
  // Read once here rather than watching: it changes exactly once per install,
  // and the screen that changes it navigates explicitly.
  final onboarded = await database.settingsDao.readBool(
    SettingKey.onboardingComplete,
    orElse: false,
  );

  return ProviderScope(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(clock),
      loggerProvider.overrideWithValue(logger),
      onboardingCompleteProvider.overrideWithValue(onboarded),
      quarantinedDatabaseProvider.overrideWithValue(quarantined),
      // The gateway defaults to a no-op so no widget test ever schedules a
      // real notification. This is the one place that must replace it, and
      // `notifications_test.dart` asserts that it does: a silently no-op
      // notification system looks exactly like a working one until someone
      // needs a reminder.
      notificationGatewayProvider.overrideWith(
        (ref) => buildNotificationGateway(clock: clock, database: database),
      ),
    ],
    child: const PeriodTrackerApp(),
  );
}

/// Builds the plugin-backed gateway used by the shipped app.
///
/// The one-tap action is wired here: it writes the log through the same
/// repository the UI uses, so the validation and the invalidation are the same
/// whether the entry came from a lock-screen button or from a tap in the app.
NotificationGateway buildNotificationGateway({
  required Clock clock,
  required AppDatabase database,
}) {
  return LocalNotificationGateway(
    plugin: FlutterLocalNotificationsPlugin(),
    clock: clock,
    onAction: (actionId) {
      if (actionId != logPeriodActionId) return;
      unawaited(
        CycleRepository(database: database, clock: clock).upsert(
          DayLog(date: clock.today(), flow: FlowIntensity.medium),
        ),
      );
    },
  );
}
