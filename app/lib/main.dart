/// Application entry point and bootstrap.
///
/// Opens the database, handles the outcomes an open can have, and builds the
/// provider scope the app runs in. The scope builder is exposed so a widget
/// test builds the same tree over an in-memory database rather than
/// duplicating the override list.
///
/// Pipeline:
///     1. Open the database, quarantining a damaged file or refusing a newer
///        one.
///     2. Read the onboarding flag once.
///     3. Build the provider scope, overriding the notification gateway with
///        the plugin-backed one.
///
/// Includes:
///     - quarantinedDatabaseProvider: Where a damaged file was moved to.
///     - main: The entry point.
///     - buildAppScope: The scope, shared with the widget tests.
///     - buildNotificationGateway: The plugin-backed gateway.
library;

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
import 'package:period_tracker/data/db/database_key.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/notifications/background_action.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/scheduler.dart';
import 'package:period_tracker/routing/router.dart';

/// The file a damaged database was moved aside to, if that happened on this
/// launch.
///
/// Null on a normal start. When it is set, the user's history is in that file
/// and the app is running on an empty database, so the UI must say so and
/// offer an import rather than looking like it deleted everything
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
    keyStore: const KeystoreDatabaseKeyStore(),
    logger: logger,
  );

  switch (outcome) {
    case DatabaseKeyUnavailable():
      runApp(const KeyUnavailableApp());
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

/// Wrap the app in a [ProviderScope] carrying the opened database.
///
/// Exposed so a widget test can build the same tree over an in-memory database
/// instead of duplicating the override list and drifting from it.
///
/// Args:
///     database (AppDatabase): The opened database.
///     clock (Clock): The app's one clock.
///     logger (RingLogger): The in-memory log ring.
///     quarantined (File?, optional): Where a damaged file was moved to.
///         Defaults to null, which is the normal start.
///     notificationGateway (NotificationGateway?, optional): Replaces the
///         plugin-backed gateway. Defaults to null, which builds the real
///         one. A test passes the no-op back in, because the plugin has no
///         platform behind it off-device.
///
/// Returns:
///     `Future<Widget>`: The scope, wrapping [PeriodTrackerApp].
Future<Widget> buildAppScope({
  required AppDatabase database,
  required Clock clock,
  required RingLogger logger,
  File? quarantined,
  NotificationGateway? notificationGateway,
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
      // The provider's own default is a no-op, so no widget test can schedule
      // a real notification by forgetting an override. This is the one place
      // that replaces it with the plugin-backed gateway that ships, and
      // `notifications_test.dart` asserts that it does: a silently no-op
      // notification system looks exactly like a working one until someone
      // needs a reminder.
      //
      // A test driving this same bootstrap passes the no-op back in, because
      // the plugin has no platform behind it off-device, and a test that had
      // to avoid the real entry point would stop testing the thing that
      // ships.
      notificationGatewayProvider.overrideWith(
        (ref) =>
            notificationGateway ??
            buildNotificationGateway(clock: clock, database: database),
      ),
    ],
    child: const PeriodTrackerApp(),
  );
}

/// Build the plugin-backed gateway used by the shipped app.
///
/// The one-tap action is wired here: it writes the log through the same
/// repository the UI uses, so the validation and the invalidation are the same
/// whether the entry came from a lock-screen button or from a tap in the app.
///
/// Args:
///     clock (Clock): The app's one clock.
///     database (AppDatabase): Where the one-tap action writes.
///
/// Returns:
///     NotificationGateway: The gateway, with both response paths wired.
NotificationGateway buildNotificationGateway({
  required Clock clock,
  required AppDatabase database,
}) {
  return LocalNotificationGateway(
    plugin: FlutterLocalNotificationsPlugin(),
    clock: clock,
    // The app is usually not running when a reminder arrives, so this is the
    // path the log action actually takes; `onAction` below only covers a tap
    // while the app happens to be open.
    onBackgroundResponse: handleBackgroundNotificationResponse,
    onAction: (actionId) {
      if (actionId != logPeriodActionId) return;
      unawaited(
        CycleRepository(
          database: database,
          clock: clock,
        ).markPeriodStart(clock.today()),
      );
    },
  );
}
