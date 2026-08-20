import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
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

  final NotificationGateway _gateway;
  final AppDatabase _database;
  final CycleRepository _cycles;
  final Clock _clock;
  final RingLogger? _logger;

  /// Reads the user's current preferences.
  Future<NotificationPreferences> preferences() async {
    final settings = _database.settingsDao;
    final lastNudge = await settings.readInt(
      SettingKey.lastNudgeEpochDay,
      orElse: -1,
    );
    return NotificationPreferences(
      predictionsEnabled: await settings.readBool(
        SettingKey.reminderEnabled,
        orElse: true,
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

  /// Rebuilds the schedule for [result], using [copy] for the wording.
  ///
  /// Called on every prediction change and every edit. Returns what was
  /// scheduled, so a test can assert the schedule rather than the side effect.
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
    return planned;
  }

  /// Creates the channels and prepares the platform.
  ///
  /// Takes the copy rather than holding it, because the body of a window
  /// notification names the predicted range, so the words change every time the
  /// prediction does. A cached copy would quietly announce last month's window.
  Future<void> prepare(NotificationCopy copy) => _gateway.initialize(copy);

  /// Whether the app should ask for notification permission yet.
  ///
  /// True only once a cycle has actually been logged. Asking at first launch
  /// gets denied by reflex, and on Android 13+ re-asking after a denial is
  /// deliberately hard, so the one request this app gets is spent at the moment
  /// the value is visible (`docs/PLAN.md` 2.4.3).
  Future<bool> shouldRequestPermission() async {
    final logs = await _cycles.logs();
    return logs.any((log) => log.isBleedingDay);
  }

  /// Asks for permission, if it is the right moment to.
  Future<bool> requestPermissionIfEarned() async {
    if (!await shouldRequestPermission()) return false;
    final granted = await _gateway.requestPermission();
    _logger?.info(
      LogEvent.notificationPermissionResolved,
      fields: <String, LogField>{'granted': LogField.flag(granted)},
    );
    return granted;
  }

  /// Whether a reminder fell due while the app was closed, and records the
  /// visit.
  ///
  /// The fallback for risk R12: OEM battery optimisers silently kill scheduled
  /// alarms on several manufacturers, so the app cannot assume what it
  /// scheduled arrived. When this returns true the UI shows the reminder in
  /// app instead.
  Future<bool> checkForMissedReminder(
    List<PlannedNotification> planned,
  ) async {
    final settings = _database.settingsDao;
    final stored = await settings.readInt(
      SettingKey.lastOpenedEpochDay,
      orElse: -1,
    );
    final today = _clock.today();
    await settings.writeInt(SettingKey.lastOpenedEpochDay, today.epochDay);

    final missed = NotificationPlanner.missedWhileClosed(
      planned: planned,
      lastOpened: stored < 0 ? null : CivilDate.fromEpochDay(stored),
      today: today,
    );
    if (missed) _logger?.warn(LogEvent.notificationMissed);
    return missed;
  }

  /// Records that the nudge fired today, for its one-per-seven-days cap.
  Future<void> recordNudgeShown() => _database.settingsDao.writeInt(
    SettingKey.lastNudgeEpochDay,
    _clock.today().epochDay,
  );

  /// Handles the one-tap action from a delivered notification.
  ///
  /// Writes the log without the app being opened, which is what makes the
  /// action worth having at all.
  Future<void> handleAction(String actionId) async {
    if (actionId != logPeriodActionId) return;
    await _cycles.upsert(
      DayLog(date: _clock.today(), flow: FlowIntensity.medium),
    );
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
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {}

  @override
  Future<List<int>> pendingIds() async => const <int>[];
}

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
