import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/notifications/notification_plan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The words a notification is delivered with.
///
/// Resolved from the localisations by the caller and passed in, so nothing
/// below this line needs a build context. It also means the copy rules are
/// checkable in a plain unit test rather than only through a widget.
@immutable
final class NotificationCopy {
  /// Creates a copy bundle.
  const NotificationCopy({
    required this.channelPredictionsName,
    required this.channelPredictionsDescription,
    required this.channelRemindersName,
    required this.channelRemindersDescription,
    required this.genericTitle,
    required this.genericBody,
    required this.windowOpeningTitle,
    required this.windowOpeningBody,
    required this.likelyStartedTitle,
    required this.likelyStartedBody,
    required this.nudgeTitle,
    required this.nudgeBody,
    required this.lateNoticeTitle,
    required this.lateNoticeBody,
    required this.logAction,
  });

  /// Name of the predictions channel, as Android settings shows it.
  final String channelPredictionsName;

  /// Description of the predictions channel.
  final String channelPredictionsDescription;

  /// Name of the reminders channel.
  final String channelRemindersName;

  /// Description of the reminders channel.
  final String channelRemindersDescription;

  /// Title used when detail is not wanted. Says nothing about a cycle.
  final String genericTitle;

  /// Body used when detail is not wanted.
  final String genericBody;

  /// Title for the window-opening notice.
  final String windowOpeningTitle;

  /// Body for the window-opening notice. Always a range, never a bare date.
  final String windowOpeningBody;

  /// Title for the likely-started notice.
  final String likelyStartedTitle;

  /// Body for the likely-started notice.
  final String likelyStartedBody;

  /// Title for the logging nudge.
  final String nudgeTitle;

  /// Body for the logging nudge. Neutral and factual.
  final String nudgeBody;

  /// Title for the late notice.
  final String lateNoticeTitle;

  /// Body for the late notice. Informational only, and never about pregnancy.
  final String lateNoticeBody;

  /// Label on the one-tap log action.
  final String logAction;

  /// The title for [kind], or the generic one when [detailed] is false.
  String titleFor(NotificationKind kind, {required bool detailed}) {
    if (!detailed) return genericTitle;
    return switch (kind) {
      NotificationKind.windowOpening => windowOpeningTitle,
      NotificationKind.likelyStarted => likelyStartedTitle,
      NotificationKind.loggingNudge => nudgeTitle,
      NotificationKind.lateNotice => lateNoticeTitle,
    };
  }

  /// The body for [kind], or the generic one when [detailed] is false.
  String bodyFor(NotificationKind kind, {required bool detailed}) {
    if (!detailed) return genericBody;
    return switch (kind) {
      NotificationKind.windowOpening => windowOpeningBody,
      NotificationKind.likelyStarted => likelyStartedBody,
      NotificationKind.loggingNudge => nudgeBody,
      NotificationKind.lateNotice => lateNoticeBody,
    };
  }
}

/// The platform surface notifications are delivered through.
///
/// An interface so the scheduling rules can be tested without a device. The
/// real implementation is the only place `flutter_local_notifications` is
/// touched, which also keeps the plugin out of every other file's imports.
abstract interface class NotificationGateway {
  /// Prepares the platform and creates the channels.
  Future<void> initialize(NotificationCopy copy);

  /// Asks for permission to post notifications.
  ///
  /// Returns whether it was granted. Called in context, never at launch.
  Future<bool> requestPermission();

  /// Removes everything currently scheduled.
  Future<void> cancelAll();

  /// Schedules [notification].
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  });

  /// The ids currently scheduled, for tests and diagnostics.
  Future<List<int>> pendingIds();
}

/// The identifier the one-tap log action reports back with.
///
/// The highest-leverage item in the whole notification section: it collapses
/// the most common logging event to a single tap, from the lock screen, without
/// launching the app.
const String logPeriodActionId = 'log_period_started';

/// A [NotificationGateway] backed by `flutter_local_notifications`.
///
/// Local only. There is no FCM, no token, and no network permission for one to
/// travel over.
final class LocalNotificationGateway implements NotificationGateway {
  /// Creates a gateway over [plugin], using [clock] for scheduling.
  LocalNotificationGateway({
    required this.plugin,
    required this.clock,
    this.onAction,
  });

  /// The platform plugin. Public so it can be an initializing formal; nothing
  /// else in the app imports the plugin at all.
  final FlutterLocalNotificationsPlugin plugin;

  /// The app's single source of "now".
  final Clock clock;

  /// Called when the user taps an action on a delivered notification.
  final void Function(String actionId)? onAction;

  /// The hour of day notifications fire at.
  ///
  /// Morning, not midnight: a reminder that arrives while the phone is face
  /// down on a bedside table at 00:00 has been spent for nothing.
  static const int fireHour = 9;

  @override
  Future<void> initialize(NotificationCopy copy) async {
    tz_data.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId;
        if (actionId != null) onAction?.call(actionId);
      },
    );

    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final channel in _channels(copy)) {
      await android.createNotificationChannel(channel);
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> cancelAll() => plugin.cancelAll();

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {
    final date = notification.fireDate;
    final when = tz.TZDateTime.local(
      date.year,
      date.month,
      date.day,
      fireHour,
    );

    await plugin.zonedSchedule(
      id: notification.kind.id,
      title: copy.titleFor(notification.kind, detailed: detailed),
      body: copy.bodyFor(notification.kind, detailed: detailed),
      scheduledDate: when,
      notificationDetails: _detailsFor(
        notification.kind,
        copy: copy,
        detailed: detailed,
      ),
      // Inexact, deliberately. Exact alarms need SCHEDULE_EXACT_ALARM, which
      // Android 14 restricts and which the user would have to grant in system
      // settings. A period reminder does not need to land on a specific minute,
      // so asking for that permission would be spending user trust on nothing.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<List<int>> pendingIds() async {
    final pending = await plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toList();
  }

  NotificationDetails _detailsFor(
    NotificationKind kind, {
    required NotificationCopy copy,
    required bool detailed,
  }) {
    final isNudge = kind == NotificationKind.loggingNudge;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        kind.channel.id,
        kind.channel == NotificationChannelId.predictions
            ? copy.channelPredictionsName
            : copy.channelRemindersName,
        channelDescription: kind.channel == NotificationChannelId.predictions
            ? copy.channelPredictionsDescription
            : copy.channelRemindersDescription,
        importance: isNudge ? Importance.low : Importance.defaultImportance,
        priority: isNudge ? Priority.low : Priority.defaultPriority,
        // The nudge is quiet by construction as well as by default: low
        // importance means no sound and no heads-up banner.
        // Secret unless the user has explicitly asked for detail. A banner
        // reading "your period is expected tomorrow", visible to anyone who
        // glances at the phone, is a real data leak, and it is the one place
        // this project's offline privacy story would otherwise leak by default
        // (risk R16).
        visibility: detailed
            ? NotificationVisibility.private
            : NotificationVisibility.secret,
        actions: kind == NotificationKind.likelyStarted
            ? <AndroidNotificationAction>[
                AndroidNotificationAction(
                  logPeriodActionId,
                  copy.logAction,
                  // showsUserInterface and cancelNotification both stay at
                  // their defaults, which are the behaviour wanted here: the
                  // action writes the log without launching the app, and the
                  // notification goes away once it has.
                ),
              ]
            : const <AndroidNotificationAction>[],
      ),
    );
  }

  List<AndroidNotificationChannel> _channels(NotificationCopy copy) =>
      <AndroidNotificationChannel>[
        AndroidNotificationChannel(
          NotificationChannelId.predictions.id,
          copy.channelPredictionsName,
          description: copy.channelPredictionsDescription,
        ),
        AndroidNotificationChannel(
          NotificationChannelId.reminders.id,
          copy.channelRemindersName,
          description: copy.channelRemindersDescription,
          importance: Importance.low,
        ),
      ];
}
