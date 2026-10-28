/// Notification delivery.
///
/// The platform surface notifications go out through, behind an interface so
/// the scheduling rules can be tested without a device. The real
/// implementation is the only place `flutter_local_notifications` is touched.
///
/// Includes:
///     - NotificationCopy: The words a notification is delivered with.
///     - NotificationGateway: The interface the scheduler depends on.
///     - logPeriodActionId: The one-tap action's identifier.
///     - timeZoneChannelName: The channel Android names its time zone on.
///     - platformTimeZoneName: Asks it.
///     - LocalNotificationGateway: The real implementation.
library;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/notifications/notification_plan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notification copy: the words a notification is delivered with.
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
    required this.channelMedicinesName,
    required this.channelMedicinesDescription,
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
    required this.medicineTitle,
    required this.medicineBody,
    required this.formatTime,
  });

  /// Name of the predictions channel, as Android settings shows it.
  final String channelPredictionsName;

  /// Description of the predictions channel.
  final String channelPredictionsDescription;

  /// Name of the reminders channel.
  final String channelRemindersName;

  /// Description of the reminders channel.
  final String channelRemindersDescription;

  /// Name of the medicine reminders channel.
  final String channelMedicinesName;

  /// Description of the medicine reminders channel.
  final String channelMedicinesDescription;

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

  /// Title for a medicine reminder with detail, from the medicine's name.
  final String Function(String medicine) medicineTitle;

  /// Body for a medicine reminder, from the time it was set for as
  /// [formatTime] writes it. The same with detail or without, so it names
  /// neither the medicine nor anything about a cycle.
  final String Function(String time) medicineBody;

  /// Writes a reminder's time the way the phone writes times.
  final String Function(ReminderTime time) formatTime;

  /// Return the title for one kind of notification.
  ///
  /// Args:
  ///     kind (NotificationKind): Which notification is going out.
  ///     detailed (bool): Whether the user has opted into detail. False gives
  ///         the generic title, which says nothing about a cycle.
  ///
  /// Returns:
  ///     String: The title to deliver.
  String titleFor(NotificationKind kind, {required bool detailed}) {
    if (!detailed) return genericTitle;
    return switch (kind) {
      NotificationKind.windowOpening => windowOpeningTitle,
      NotificationKind.likelyStarted => likelyStartedTitle,
      NotificationKind.loggingNudge => nudgeTitle,
      NotificationKind.lateNotice => lateNoticeTitle,
    };
  }

  /// Return the body for one kind of notification.
  ///
  /// Args:
  ///     kind (NotificationKind): Which notification is going out.
  ///     detailed (bool): Whether the user has opted into detail. False gives
  ///         the generic body.
  ///
  /// Returns:
  ///     String: The body to deliver.
  String bodyFor(NotificationKind kind, {required bool detailed}) {
    if (!detailed) return genericBody;
    return switch (kind) {
      NotificationKind.windowOpening => windowOpeningBody,
      NotificationKind.likelyStarted => likelyStartedBody,
      NotificationKind.loggingNudge => nudgeBody,
      NotificationKind.lateNotice => lateNoticeBody,
    };
  }

  /// Return the title for a medicine reminder.
  ///
  /// Args:
  ///     reminder (DailyReminder): The reminder going out.
  ///     detailed (bool): Whether the user has opted into detail. False gives
  ///         the generic title, which does not name the medicine.
  ///
  /// Returns:
  ///     String: The title to deliver.
  String medicineTitleFor(DailyReminder reminder, {required bool detailed}) =>
      detailed ? medicineTitle(reminder.medicine) : genericTitle;

  /// Return the body for a medicine reminder.
  ///
  /// Not the generic body, even without detail: that one says to open the
  /// app to see what the notification is about, and the app has nothing to
  /// show for a reminder someone set themselves. This one says only that it
  /// is theirs, and its time (ADR-0025).
  ///
  /// Args:
  ///     reminder (DailyReminder): The reminder going out.
  ///
  /// Returns:
  ///     String: The body to deliver.
  String medicineBodyFor(DailyReminder reminder) =>
      medicineBody(formatTime(reminder.time));
}

/// Notification gateway: the platform surface notifications go through.
///
/// An interface so the scheduling rules can be tested without a device. The
/// real implementation is the only place `flutter_local_notifications` is
/// touched, which also keeps the plugin out of every other file's imports.
abstract interface class NotificationGateway {
  /// Prepare the platform and create the channels.
  ///
  /// Args:
  ///     copy (NotificationCopy): Supplies the channel names and
  ///         descriptions, which the system settings screen shows.
  Future<void> initialize(NotificationCopy copy);

  /// Ask for permission to post notifications.
  ///
  /// Called in context, never at launch.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether it was granted.
  Future<bool> requestPermission();

  /// Remove everything scheduled, and any notice about the cycle still
  /// showing.
  ///
  /// A medicine reminder that has gone off stays where it is until it is
  /// seen to: one that vanished whenever the app was opened could be the
  /// reason a dose was missed (ADR-0025).
  Future<void> cancelAll();

  /// Schedule one notification.
  ///
  /// Args:
  ///     notification (PlannedNotification): What to deliver, and when.
  ///     copy (NotificationCopy): Supplies the title and body.
  ///     detailed (bool): Whether the user has opted into detail.
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  });

  /// Schedule one medicine reminder, to repeat every day at its time.
  ///
  /// Args:
  ///     reminder (DailyReminder): What to deliver, and at what time of day.
  ///     copy (NotificationCopy): Supplies the title and body.
  ///     detailed (bool): Whether the user has opted into detail.
  Future<void> scheduleDaily(
    DailyReminder reminder, {
    required NotificationCopy copy,
    required bool detailed,
  });

  /// Read the ids currently scheduled, for tests and diagnostics.
  ///
  /// Returns:
  ///     `Future<List<int>>`: Every pending id, in platform order.
  Future<List<int>> pendingIds();
}

/// The identifier the one-tap log action reports back with.
///
/// The highest-leverage item in the whole notification section: it collapses
/// the most common logging event to a single tap, from the lock screen,
/// without launching the app.
const String logPeriodActionId = 'log_period_started';

/// The channel `MainActivity` answers with the phone's time zone.
///
/// `main_activity_test.dart` checks the Kotlin side answers on this name.
const String timeZoneChannelName =
    'io.github.proteusnell.period_tracker/time_zone';

/// Ask Android which time zone the phone is set to.
///
/// Returns:
///     `Future<String?>`: Its name in the time zone database, such as
///     `Europe/London`, or null when the platform cannot say.
Future<String?> platformTimeZoneName() async {
  try {
    return await const MethodChannel(
      timeZoneChannelName,
    ).invokeMethod<String>('name');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

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
    this.onBackgroundResponse,
    this.timeZoneName = platformTimeZoneName,
  });

  /// The platform plugin. Public so it can be an initializing formal; nothing
  /// else in the app imports the plugin at all.
  final FlutterLocalNotificationsPlugin plugin;

  /// The app's single source of "now".
  final Clock clock;

  /// Called when the user taps an action while the app is running.
  final void Function(String actionId)? onAction;

  /// Handles an action tap when the app process is not running.
  ///
  /// Must be a top-level or static function annotated with
  /// `@pragma('vm:entry-point')`: the platform stores a handle to it and looks
  /// it up from a fresh isolate, so a closure cannot be found again.
  final DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse;

  /// Asks which time zone the phone is set to, for the medicine reminders.
  final Future<String?> Function() timeZoneName;

  /// The hour of day notifications fire at.
  ///
  /// Morning, not midnight: a reminder that arrives while the phone is face
  /// down on a bedside table at 00:00 has been spent for nothing.
  static const int fireHour = 9;

  @override
  Future<void> initialize(NotificationCopy copy) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId;
        if (actionId != null) onAction?.call(actionId);
      },
      // Required for the log action to work at all. An action whose
      // `showsUserInterface` is false is delivered by broadcast to a *new*
      // isolate, and the plugin can only start one if a dispatcher handle was
      // stored here at initialize time. Without this the tap is received by the
      // platform, finds no callback, logs "Callback information could not be
      // retrieved", and does nothing. The app is almost never running at
      // 09:00, so that is the normal case rather than the edge case.
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
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
  Future<void> cancelAll() async {
    // Shown or still to come: one still showing once the prediction has moved
    // is about a window that is no longer the one predicted.
    for (final kind in NotificationKind.values) {
      await plugin.cancel(id: kind.id);
    }
    // Not the plugin's cancelAll, which would take a medicine reminder that
    // has gone off off the screen as well.
    await plugin.cancelAllPendingNotifications();
  }

  /// The exact instant [date] at [fireHour] falls on, for the platform.
  ///
  /// Built as an instant, in UTC, rather than as a wall-clock time in
  /// `tz.local`. `initializeTimeZones()` leaves `tz.local` set to UTC, which
  /// is what the timezone package does until `setLocalLocation` is called with
  /// a zone name only a platform plugin can supply, and the Android half of
  /// the plugin schedules by combining the wall-clock string with the zone
  /// name it is handed. A 09:00 built in `tz.local` therefore means 09:00 UTC:
  /// 01:00 in Los Angeles, 20:00 in Sydney, and the wrong day in Honolulu.
  ///
  /// Dart's own [DateTime] already applies the device's zone rules, DST
  /// included, for the date in question. Converting that instant to UTC keeps
  /// the right moment and needs no zone database and no extra dependency.
  ///
  /// Static and public so the arithmetic can be asserted directly: a test
  /// that recomputed it would agree with itself no matter what this shipped.
  ///
  /// Args:
  ///     date (CivilDate): The day the notification is for.
  ///
  /// Returns:
  ///     tz.TZDateTime: The firing instant, in UTC, at [fireHour] local.
  static tz.TZDateTime fireInstantFor(CivilDate date) => tz.TZDateTime.from(
    DateTime(date.year, date.month, date.day, fireHour),
    tz.UTC,
  );

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {
    final when = fireInstantFor(notification.fireDate);

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

  /// The zone named [name], from the time zone database.
  ///
  /// The whole database, aliases included, because Android still names some
  /// zones by their older names, `Asia/Calcutta` among them, which the
  /// smaller files leave out. Loaded the first time a medicine reminder is
  /// scheduled, and not before.
  ///
  /// Args:
  ///     name (String?): What [platformTimeZoneName] answered.
  ///
  /// Returns:
  ///     tz.Location?: The zone, or null when there is no name or the
  ///     database does not know it.
  static tz.Location? zoneNamed(String? name) {
    if (name == null) return null;
    if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// When a daily reminder at [time] is first scheduled for, from [today].
  ///
  /// In the phone's own zone when it is known, because Android repeats a
  /// daily notification at the same time on the clock in the zone it was
  /// scheduled in, and that is what keeps a reminder at 08:00 across a change
  /// of the clocks. The plugin moves the date on to the next time that comes
  /// round, so today's date serves even once today's time has passed.
  ///
  /// Without a zone, the same moment in UTC: right until the clocks next
  /// change, and put right again the next time the app reschedules.
  ///
  /// Args:
  ///     time (ReminderTime): The time of day it goes off.
  ///     today (CivilDate): The phone's date.
  ///     zone (tz.Location?): The phone's zone, or null when unknown.
  ///
  /// Returns:
  ///     tz.TZDateTime: The time to hand the platform.
  static tz.TZDateTime dailyTimeFor(
    ReminderTime time, {
    required CivilDate today,
    required tz.Location? zone,
  }) => zone == null
      ? tz.TZDateTime.from(
          DateTime(today.year, today.month, today.day, time.hour, time.minute),
          tz.UTC,
        )
      : tz.TZDateTime(
          zone,
          today.year,
          today.month,
          today.day,
          time.hour,
          time.minute,
        );

  @override
  Future<void> scheduleDaily(
    DailyReminder reminder, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {
    await plugin.zonedSchedule(
      id: reminder.id,
      title: copy.medicineTitleFor(reminder, detailed: detailed),
      body: copy.medicineBodyFor(reminder),
      scheduledDate: dailyTimeFor(
        reminder.time,
        today: clock.today(),
        zone: zoneNamed(await timeZoneName()),
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannelId.medicines.id,
          copy.channelMedicinesName,
          channelDescription: copy.channelMedicinesDescription,
          // So that a phone set to let reminders through Do Not Disturb lets
          // this one through.
          category: AndroidNotificationCategory.reminder,
          visibility: detailed
              ? NotificationVisibility.private
              : NotificationVisibility.secret,
        ),
      ),
      // Inexact, as the others are, so it can arrive a few minutes after its
      // time. The exact kind needs a permission the user grants in system
      // settings (see [schedule]).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<List<int>> pendingIds() async {
    final pending = await plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toList();
  }

  /// Build the platform details for one kind of notification.
  ///
  /// Args:
  ///     kind (NotificationKind): Which notification is going out.
  ///     copy (NotificationCopy): Supplies the action label.
  ///     detailed (bool): Whether the user has opted into detail.
  ///
  /// Returns:
  ///     NotificationDetails: The channel, importance and actions. The
  ///     logging nudge carries no action and the low-priority channel. The
  ///     likely-started notice and the late-period check-in carry the
  ///     one-tap log action.
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
        actions:
            kind == NotificationKind.likelyStarted ||
                kind == NotificationKind.lateNotice
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

  /// Build the Android channels this app posts to.
  ///
  /// Args:
  ///     copy (NotificationCopy): Supplies each channel's name and
  ///         description, which the system settings screen shows.
  ///
  /// Returns:
  ///     `List<AndroidNotificationChannel>`: One per
  ///     [NotificationChannelId].
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
        AndroidNotificationChannel(
          NotificationChannelId.medicines.id,
          copy.channelMedicinesName,
          description: copy.channelMedicinesDescription,
        ),
      ];
}
