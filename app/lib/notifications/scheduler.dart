/// Notification scheduling.
///
/// Keeps what the platform has queued in step with the current prediction, and
/// owns the permission request. Everything the platform knows about is
/// replaced on every reschedule, so there is no partial state to reconcile.
///
/// Includes:
///     - NotificationScheduler: Rescheduling, permission and the missed
///       reminder fallback.
///     - NoopNotificationGateway: The default, so no test can schedule a real
///       notification by forgetting an override.
///     - notificationPreferencesRevisionProvider: Forces a reschedule when a
///       preference changes rather than the prediction.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/notification_plan.dart';

/// Keeps the scheduled notifications in step with the prediction.
///
/// Everything the platform knows about is replaced on every reschedule, rather
/// than diffed. Diffing would be an optimisation over four notifications, and
/// the failure mode it buys is a stale reminder about a window the user has
/// already moved: the same class of bug the prediction cache exists to prevent,
/// only louder because it arrives on the lock screen.
class NotificationScheduler {
  /// Creates a scheduler.
  NotificationScheduler({
    required NotificationGateway gateway,
    required AppDatabase database,
    required CycleRepository cycles,
    required Clock clock,
    RingLogger? logger,
  }) : // An initializing formal would have to be `this._gateway` and the
       // rest, and Dart does not allow a named parameter to start with an
       // underscore.
       // ignore: prefer_initializing_formals
       _gateway = gateway,
       // ignore: prefer_initializing_formals, same reason as above
       _database = database,
       // ignore: prefer_initializing_formals, same reason as above
       _cycles = cycles,
       // ignore: prefer_initializing_formals, same reason as above
       _clock = clock,
       // ignore: prefer_initializing_formals, same reason as above
       _logger = logger;

  /// Where notifications are delivered.
  final NotificationGateway _gateway;

  /// Where the preferences are stored.
  final AppDatabase _database;

  /// Supplies the logs the permission and nudge rules read.
  final CycleRepository _cycles;

  /// The app's one clock.
  final Clock _clock;

  /// Records what was scheduled, never what was logged.
  final RingLogger? _logger;

  /// Read the user's current notification preferences.
  ///
  /// Returns:
  ///     `Future<NotificationPreferences>`: Every stored preference, with
  ///     the last nudge day defaulted to -1 when none has fired.
  Future<NotificationPreferences> preferences() async {
    final settings = _database.settingsDao;
    final lastNudge = await settings.readInt(
      SettingKey.lastNudgeEpochDay,
      orElse: -1,
    );
    final predictions = await settings.readBool(
      SettingKey.reminderEnabled,
      orElse: true,
    );
    return NotificationPreferences(
      predictionsEnabled: predictions,
      // Until it has a value of its own, as the predictions switch was set:
      // the check-in came with it before it had a switch (ADR-0025).
      lateCheckInEnabled: await settings.readBool(
        SettingKey.lateCheckInEnabled,
        orElse: predictions,
      ),
      // Off unless the user turned it on. Never defaulted true on a re-read.
      nudgeEnabled: await settings.readBool(
        SettingKey.nudgeEnabled,
        orElse: false,
      ),
      leadDays: await settings.readInt(
        SettingKey.reminderLeadDays,
        orElse: 2,
      ),
      lastNudge: lastNudge < 0 ? null : CivilDate.fromEpochDay(lastNudge),
    );
  }

  /// Rebuild the whole schedule for a prediction, and the medicine
  /// reminders with it.
  ///
  /// Called on every prediction change and every edit, and whenever a
  /// medicine reminder changes. The medicine reminders are rebuilt each time
  /// too, because cancelling is all or nothing, and because each run
  /// schedules them in the zone the phone is in now (ADR-0025).
  ///
  /// Args:
  ///     result (PredictionResult): What the model currently says.
  ///     copy (NotificationCopy): The wording to deliver with.
  ///
  /// Returns:
  ///     `Future<List<PlannedNotification>>`: What was scheduled about the
  ///     cycle, so a test can assert the schedule rather than the side
  ///     effect. Not the medicine reminders, which repeat every day and so
  ///     are never missed while the app is closed in the sense
  ///     [checkForMissedReminder] means.
  Future<List<PlannedNotification>> reschedule(
    PredictionResult result, {
    required NotificationCopy copy,
  }) async {
    final logs = await _cycles.logs();
    final planned = NotificationPlanner.plan(
      result: result,
      today: _clock.today(),
      preferences: await preferences(),
      lastLoggedDay: logs.isEmpty ? null : logs.last.date,
    );

    await _gateway.cancelAll();
    _logger?.info(LogEvent.notificationCancelled);

    final detailed = await _database.settingsDao.readBool(
      SettingKey.detailedNotifications,
      // Secret by default. The user opts in to detail; they do not opt out of
      // having their cycle on the lock screen (risk R16).
      orElse: false,
    );
    for (final notification in planned) {
      await _gateway.schedule(notification, copy: copy, detailed: detailed);
      _logger?.info(
        LogEvent.notificationScheduled,
        fields: <String, LogField>{'kind': LogField.state(notification.kind)},
      );
    }

    final medicines = MedicineListRepository(_database.settingsDao);
    final daily = NotificationPlanner.planMedicines(
      await medicines.read(),
      await medicines.reminders(),
    );
    for (final reminder in daily) {
      await _gateway.scheduleDaily(reminder, copy: copy, detailed: detailed);
    }
    if (daily.isNotEmpty) {
      // How many, and never which: a medicine's name is not for the log.
      _logger?.info(
        LogEvent.notificationScheduled,
        fields: <String, LogField>{'medicines': LogField.count(daily.length)},
      );
    }
    return planned;
  }

  /// Create the channels and prepare the platform.
  ///
  /// Takes the copy rather than holding it, because the body of a window
  /// notification names the predicted range, so the words change every time
  /// the prediction does. A cached copy would quietly announce last month's
  /// window.
  ///
  /// Args:
  ///     copy (NotificationCopy): Supplies the channel names.
  Future<void> prepare(NotificationCopy copy) => _gateway.initialize(copy);

  /// Report whether the app should ask for notification permission yet.
  ///
  /// Asking at first launch gets denied by reflex, and on Android 13+
  /// re-asking after a denial is deliberately hard, so the one request this
  /// app gets is spent at the moment the value is visible (`docs/PLAN.md`
  /// 2.4.3).
  ///
  /// Returns:
  ///     `Future<bool>`: True only once a cycle has actually been logged.
  Future<bool> shouldRequestPermission() async {
    final logs = await _cycles.logs();
    return logs.any((log) => log.isBleedingDay);
  }

  /// Ask for permission, if it is the right moment to.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether permission is now granted. False without
  ///     asking when it has not been earned yet.
  Future<bool> requestPermissionIfEarned() async {
    if (!await shouldRequestPermission()) return false;
    final granted = await _gateway.requestPermission();
    _logger?.info(
      LogEvent.notificationPermissionResolved,
      fields: <String, LogField>{'granted': LogField.flag(granted)},
    );
    return granted;
  }

  /// Ask for permission because a medicine reminder has just been set.
  ///
  /// The one other moment the request is in context: someone who has just
  /// chosen a time to be reminded at has asked for a notification. It counts
  /// as the one request, so the question after a first logged cycle is not
  /// put again on top of it. Android shows nothing when permission is
  /// already granted, or after it has been refused for good, and says which.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether notifications can now be posted.
  Future<bool> requestPermissionForReminder() async {
    await _database.settingsDao.writeBool(
      SettingKey.notificationPermissionAsked,
      value: true,
    );
    final granted = await _gateway.requestPermission();
    _logger?.info(
      LogEvent.notificationPermissionResolved,
      fields: <String, LogField>{'granted': LogField.flag(granted)},
    );
    return granted;
  }

  /// Whether a medicine reminder can currently be scheduled for its minute.
  ///
  /// Returns:
  ///     `Future<bool>`: What the platform says. False means the reminders
  ///     are scheduled roughly, and can arrive late (ADR-0026).
  Future<bool> exactRemindersAllowed() => _gateway.canScheduleExact();

  /// Whether to put the exact-alarm question to the user unprompted.
  ///
  /// Only once, and only while the answer would change something: a phone
  /// that already allows exact alarms, Android before 12 among them, is not
  /// asked at all. Settings keeps a row either way, so a no here is never
  /// final.
  ///
  /// Returns:
  ///     `Future<bool>`: True when it has not been asked and is not allowed.
  Future<bool> shouldRequestExactReminders() async {
    final asked = await _database.settingsDao.readBool(
      SettingKey.exactAlarmPermissionAsked,
      orElse: false,
    );
    if (asked) return false;
    return !await _gateway.canScheduleExact();
  }

  /// Ask for the exact-alarm permission, and record that it was asked.
  ///
  /// Android 14 and later answer by opening their own "Alarms and reminders"
  /// screen, so this completes only once the user comes back from it. The
  /// caller reschedules afterwards: what is already queued was queued
  /// inexactly, and nothing re-queues it on its own.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether exact reminders are now allowed.
  Future<bool> requestExactReminders() async {
    await _database.settingsDao.writeBool(
      SettingKey.exactAlarmPermissionAsked,
      value: true,
    );
    final granted = await _gateway.requestExactPermission();
    _logger?.info(
      LogEvent.notificationExactAlarmResolved,
      fields: <String, LogField>{'granted': LogField.flag(granted)},
    );
    return granted;
  }

  /// Record that the exact-alarm question has been put, without putting it.
  ///
  /// For a user who answered "not now": the prompt does not come back by
  /// itself, and the row in Settings is where it lives from then on.
  Future<void> recordExactRemindersAsked() => _database.settingsDao.writeBool(
    SettingKey.exactAlarmPermissionAsked,
    value: true,
  );

  /// Whether a reminder fell due while the app was closed, and records the
  /// visit.
  ///
  /// The fallback for risk R12: OEM battery optimisers silently kill scheduled
  /// alarms on several manufacturers, so the app cannot assume what it
  /// scheduled arrived. When this returns true the UI shows the reminder in
  /// app instead.
  /// Args:
  ///     planned (`List<PlannedNotification>`): The current schedule, used
  ///         only to record the stored fire dates for next time.
  ///
  /// Returns:
  ///     `Future<bool>`: True when a stored fire date fell between the last
  ///     visit and today, so the UI should show the reminder in app instead.
  Future<bool> checkForMissedReminder(
    List<PlannedNotification> planned,
  ) async {
    final settings = _database.settingsDao;
    final stored = await settings.readInt(
      SettingKey.lastOpenedEpochDay,
      orElse: -1,
    );
    // The schedule as it stood *before* this launch rebuilt it. Comparing
    // against [planned] instead would always answer no: every date the planner
    // produces is strictly after today, and a missed reminder is by definition
    // one whose date has passed.
    final previous = await _storedFireDates();
    final today = _clock.today();

    await settings.writeInt(SettingKey.lastOpenedEpochDay, today.epochDay);
    await settings.writeRaw(
      SettingKey.scheduledFireDays.wireName,
      planned.map((n) => n.fireDate.epochDay).join(','),
    );

    final missed = NotificationPlanner.missedWhileClosed(
      fireDates: previous,
      lastOpened: stored < 0 ? null : CivilDate.fromEpochDay(stored),
      today: today,
    );
    if (missed) _logger?.warn(LogEvent.notificationMissed);
    return missed;
  }

  /// The fire dates recorded by the previous reschedule.
  ///
  /// Tolerant of anything it cannot parse: a preference that cannot be read is
  /// worth defaulting, and the cost of getting this wrong is one missing
  /// banner, not a broken launch.
  /// Returns:
  ///     `Future<List<CivilDate>>`: The stored schedule, or an empty list
  ///     when nothing is stored or the value cannot be parsed.
  Future<List<CivilDate>> _storedFireDates() async {
    final raw = await _database.settingsDao.raw(SettingKey.scheduledFireDays);
    if (raw == null || raw.isEmpty) return const <CivilDate>[];
    return raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .map(CivilDate.fromEpochDay)
        .toList();
  }

  /// Records that the nudge fired today, for its one-per-seven-days cap.
  Future<void> recordNudgeShown() => _database.settingsDao.writeInt(
    SettingKey.lastNudgeEpochDay,
    _clock.today().epochDay,
  );

  /// Handle the one-tap action from a delivered notification.
  ///
  /// Writes the log without the app being opened, which is what makes the
  /// action worth having at all.
  ///
  /// Args:
  ///     actionId (String): What the platform reported. Anything other than
  ///         [logPeriodActionId] is ignored.
  Future<void> handleAction(String actionId) async {
    if (actionId != logPeriodActionId) return;
    await _cycles.markPeriodStart(_clock.today());
    _logger?.info(LogEvent.logEntryCreated);
  }
}

/// A gateway that does nothing.
///
/// The default, so that a widget test never schedules a real notification and
/// never has to remember an override to avoid one. The bootstrap replaces it
/// with the plugin-backed gateway, and `notifications_test.dart` asserts that
/// it does, because a silently no-op notification system would be indis-
/// tinguishable from a working one right up until a user needed a reminder.
final class NoopNotificationGateway implements NotificationGateway {
  /// Creates the no-op gateway.
  const NoopNotificationGateway();

  @override
  Future<void> initialize(NotificationCopy copy) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExact() async => false;

  @override
  Future<bool> requestExactPermission() async => false;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {}

  @override
  Future<void> scheduleDaily(
    DailyReminder reminder, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {}

  @override
  Future<List<int>> pendingIds() async => const <int>[];
}

/// Bumped whenever a notification preference changes.
///
/// Medicine reminders need no bump: `NotificationSync` watches them itself.
///
/// `NotificationSync` reschedules when the *prediction* changes, which is the
/// right trigger for almost everything. But turning reminders off, or moving
/// the lead days, changes nothing about the prediction. Without this, the
/// notification the user just switched off stays queued on the platform until
/// something unrelated happens to trigger a reschedule, and then arrives.
final StateProvider<int> notificationPreferencesRevisionProvider =
    StateProvider<int>((ref) => 0);

/// The notification gateway. Defaults to [NoopNotificationGateway].
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((ref) => const NoopNotificationGateway());

/// The scheduler, built over whatever gateway is in scope.
final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>(
      (ref) => NotificationScheduler(
        gateway: ref.watch(notificationGatewayProvider),
        database: ref.watch(appDatabaseProvider),
        cycles: ref.watch(cycleRepositoryProvider),
        clock: ref.watch(clockProvider),
        logger: ref.watch(loggerProvider),
      ),
    );
