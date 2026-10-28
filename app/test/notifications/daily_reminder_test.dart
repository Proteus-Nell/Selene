// What the gateway hands Android for a medicine reminder, and for the
// late-period check-in (ADR-0025).
//
// The scheduler's tests stop at the gateway's interface, and the plugin stops
// at a method channel. Between the two is what decides whether a reminder set
// for 08:00 still goes off at 08:00 once the clocks change: the zone it is
// scheduled in, by name, and the time on the clock. So the channel is answered
// here, as Android would answer it, and what crosses it is read back.
//
// The other half is Kotlin, which no test here runs: the plugin's Android side
// repeats a daily notification at the same time on the clock in the zone it
// is handed by name (`getNextFireDateMatchingDateTimeComponents`), and
// `MainActivity` answers the time zone channel (`main_activity_test.dart`).

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/notification_plan.dart';

/// The plugin's channel, as its Android implementation names it.
const MethodChannel _plugin = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

String _medicineTitle(String medicine) => 'Time for $medicine';

String _medicineBody(String time) => 'The reminder you set for $time.';

String _formatTime(ReminderTime time) => time.wire;

const NotificationCopy _copy = NotificationCopy(
  channelPredictionsName: 'Predictions',
  channelPredictionsDescription: 'd',
  channelRemindersName: 'Logging reminders',
  channelRemindersDescription: 'd',
  channelMedicinesName: 'Medicine reminders',
  channelMedicinesDescription: 'd',
  genericTitle: 'Selene',
  genericBody: 'Open the app.',
  windowOpeningTitle: 'Soon',
  windowOpeningBody: 'From 10 July to 16 July.',
  likelyStartedTitle: 'Has it started?',
  likelyStartedBody: 'Nothing logged yet.',
  nudgeTitle: 'Nothing logged',
  nudgeBody: 'No hurry.',
  lateNoticeTitle: 'Later than expected',
  lateNoticeBody: 'The expected range has passed.',
  logAction: 'Started today',
  medicineTitle: _medicineTitle,
  medicineBody: _medicineBody,
  formatTime: _formatTime,
);

const DailyReminder _pill = DailyReminder(
  id: 2000,
  medicine: 'PILL',
  time: ReminderTime(8, 0),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the plugin sent Android, in order.
  late List<MethodCall> sent;

  setUp(() {
    sent = <MethodCall>[];
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      sent.add(call);
      return call.method == 'initialize' ? true : null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(_plugin, null));

  LocalNotificationGateway gateway({String? zone = 'Europe/London'}) =>
      LocalNotificationGateway(
        plugin: FlutterLocalNotificationsPlugin(),
        clock: FixedClock(CivilDate(2026, 3, 28)),
        timeZoneName: () async => zone,
      );

  /// The one call named [method], as a map.
  Map<Object?, Object?> only(String method) =>
      sent.singleWhere((call) => call.method == method).arguments
          as Map<Object?, Object?>;

  Map<Object?, Object?> specifics(Map<Object?, Object?> call) =>
      call['platformSpecifics']! as Map<Object?, Object?>;

  /// Whether [call] offers the one-tap log action.
  bool offersLog(Map<Object?, Object?> call) =>
      ((specifics(call)['actions'] as List<Object?>?) ?? const <Object?>[]).any(
        (action) =>
            (action! as Map<Object?, Object?>)['id'] == logPeriodActionId,
      );

  group('a medicine reminder', () {
    test("is scheduled in the phone's zone, by name, at its time on the "
        'clock', () async {
      await gateway().scheduleDaily(_pill, copy: _copy, detailed: false);
      final call = only('zonedSchedule');
      expect(call['id'], 2000);
      expect(call['timeZoneName'], 'Europe/London');
      expect(call['scheduledDateTime'], '2026-03-28T08:00:00');
      // Every day at that time, not once.
      expect(call['matchDateTimeComponents'], DateTimeComponents.time.index);
    });

    test('goes out on its own channel, as a reminder', () async {
      await gateway().scheduleDaily(_pill, copy: _copy, detailed: false);
      final android = specifics(only('zonedSchedule'));
      expect(android['channelId'], NotificationChannelId.medicines.id);
      expect(android['channelName'], 'Medicine reminders');
      expect(android['category'], AndroidNotificationCategory.reminder.name);
      // Inexact, as every notification here is: no exact-alarm permission.
      expect(
        android['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
      );
    });

    test('without detail, names no medicine, and is hidden on a locked '
        'screen', () async {
      await gateway().scheduleDaily(_pill, copy: _copy, detailed: false);
      final call = only('zonedSchedule');
      expect(call['title'], 'Selene');
      expect('${call['title']} ${call['body']}', isNot(contains('PILL')));
      expect(call['body'], 'The reminder you set for 08:00.');
      expect(
        specifics(call)['visibility'],
        NotificationVisibility.secret.index,
      );
    });

    test('with detail, names the medicine', () async {
      await gateway().scheduleDaily(_pill, copy: _copy, detailed: true);
      final call = only('zonedSchedule');
      expect(call['title'], 'Time for PILL');
      expect(
        specifics(call)['visibility'],
        NotificationVisibility.private.index,
      );
    });

    test('keeps to UTC when the zone cannot be found, the same moment '
        'today', () async {
      await gateway(zone: null).scheduleDaily(
        _pill,
        copy: _copy,
        detailed: false,
      );
      final call = only('zonedSchedule');
      // Java knows the zone by this name too.
      expect(call['timeZoneName'], 'Etc/UTC');
      final local = DateTime(2026, 3, 28, 8).toUtc();
      expect(
        call['scheduledDateTime'],
        '2026-03-28T${local.hour.toString().padLeft(2, '0')}:00:00',
      );
    });
  });

  group('the zone', () {
    test('is found by the names Android gives it, old ones included', () {
      // Android still names some zones by names the time zone database keeps
      // only as aliases, India's among them.
      for (final name in <String>[
        'Europe/London',
        'America/Los_Angeles',
        'Asia/Calcutta',
        'Asia/Kolkata',
        'Europe/Kiev',
      ]) {
        expect(LocalNotificationGateway.zoneNamed(name)?.name, name);
      }
    });

    test('is none for no name, or one the database does not know', () {
      expect(LocalNotificationGateway.zoneNamed(null), isNull);
      expect(LocalNotificationGateway.zoneNamed('Not/A_Zone'), isNull);
    });

    test('carries the change of the clocks, so 08:00 stays 08:00', () {
      // The UK's clocks went forward on 29 March 2026, so 08:00 there was
      // 08:00 UTC the day before and 07:00 UTC that day.
      final london = LocalNotificationGateway.zoneNamed('Europe/London');
      for (final (date, utcHour) in <(CivilDate, int)>[
        (CivilDate(2026, 3, 28), 8),
        (CivilDate(2026, 3, 29), 7),
      ]) {
        final at = LocalNotificationGateway.dailyTimeFor(
          const ReminderTime(8, 0),
          today: date,
          zone: london,
        );
        expect((at.hour, at.minute), (8, 0));
        expect(at.toUtc().hour, utcHour);
      }
    });

    test('is asked of Android on the channel MainActivity answers', () async {
      const channel = MethodChannel(timeZoneChannelName);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'name');
        return 'Asia/Calcutta';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await platformTimeZoneName(), 'Asia/Calcutta');
    });

    test('is unknown, not an error, when nothing answers', () async {
      expect(await platformTimeZoneName(), isNull);
    });
  });

  group('the late-period check-in', () {
    test('carries the one-tap log action, as the likely-started notice '
        'does', () async {
      final plugin = gateway();
      for (final kind in NotificationKind.values) {
        await plugin.schedule(
          // Far ahead: the plugin refuses a one-off date before the real now.
          PlannedNotification(kind: kind, fireDate: CivilDate(2099, 4, 30)),
          copy: _copy,
          detailed: false,
        );
      }
      final withAction = <Object?>{
        for (final call in sent.where((c) => c.method == 'zonedSchedule'))
          if (offersLog(call.arguments as Map<Object?, Object?>))
            (call.arguments as Map<Object?, Object?>)['id'],
      };
      expect(withAction, <int>{
        NotificationKind.likelyStarted.id,
        NotificationKind.lateNotice.id,
      });
    });
  });

  test("a reschedule's cancel takes off the cycle's notices, showing or not, "
      'but only the medicine reminders still to come', () async {
    // The plugin's cancelAll takes shown notifications off the screen too, so
    // a reminder that had gone off and not been seen to would vanish whenever
    // the app was opened, which reschedules.
    await gateway().cancelAll();
    expect(sent.map((call) => call.method), isNot(contains('cancelAll')));
    expect(
      <Object?>{
        for (final call in sent.where((c) => c.method == 'cancel'))
          (call.arguments as Map<Object?, Object?>)['id'],
      },
      NotificationKind.values.map((kind) => kind.id).toSet(),
    );
    expect(sent.last.method, 'cancelAllPendingNotifications');
  });

  test('creates a channel for each kind of notification', () async {
    await gateway().initialize(_copy);
    final channels = <Object?>{
      for (final call in sent.where(
        (c) => c.method == 'createNotificationChannel',
      ))
        (call.arguments as Map<Object?, Object?>)['id'],
    };
    expect(
      channels,
      NotificationChannelId.values.map((channel) => channel.id).toSet(),
    );
  });
}
