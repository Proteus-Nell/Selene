// The scheduler and the copy rules (AND-17).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/notification_plan.dart';
import 'package:period_tracker/notifications/notification_sync.dart';
import 'package:period_tracker/notifications/scheduler.dart';

import '../features/harness.dart';

/// Records what it was asked to do, so the rules can be asserted without a
/// device.
class RecordingGateway implements NotificationGateway {
  final List<PlannedNotification> scheduled = <PlannedNotification>[];
  final List<bool> detailedFlags = <bool>[];
  final List<DailyReminder> daily = <DailyReminder>[];
  NotificationCopy? initialisedWith;
  int cancelCount = 0;
  int permissionRequests = 0;
  bool grantPermission = true;
  int exactRequests = 0;
  bool exactAllowed = false;

  @override
  Future<void> initialize(NotificationCopy copy) async =>
      initialisedWith = copy;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<bool> requestExactPermission() async {
    exactRequests++;
    return exactAllowed;
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    scheduled.clear();
    detailedFlags.clear();
    daily.clear();
  }

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {
    scheduled.add(notification);
    detailedFlags.add(detailed);
  }

  @override
  Future<void> scheduleDaily(
    DailyReminder reminder, {
    required NotificationCopy copy,
    required bool detailed,
  }) async => daily.add(reminder);

  @override
  Future<List<int>> pendingIds() async =>
      scheduled.map((s) => s.kind.id).toList();
}

String _medicineTitle(String medicine) => 'Time for $medicine';

String _medicineBody(String time) => 'The reminder you set for $time.';

String _formatTime(ReminderTime time) => time.wire;

Prediction predictionFrom(CivilDate start, CivilDate end) => Prediction(
  medianStart: start,
  window50: CivilDateRange(start, end),
  window80: CivilDateRange(start, end),
  confidence: Confidence.medium,
  basis: const PredictionBasis(
    cyclesUsed: 6,
    medianLengthDays: 28,
    variabilityDays: 2,
    personalizedHyperparameters: true,
  ),
);

void main() {
  late AppDatabase db;
  late RecordingGateway gateway;
  late NotificationScheduler scheduler;
  late CycleRepository cycles;

  final window = predictionFrom(
    testClock.today().addDays(10),
    testClock.today().addDays(16),
  );
  final result = PredictionResult.predicted(
    prediction: window,
    statistics: const CycleStatistics(completedCycles: 6),
  );

  late NotificationCopy copy;

  setUp(() async {
    db = memoryDatabase();
    gateway = RecordingGateway();
    cycles = CycleRepository(database: db, clock: testClock);
    scheduler = NotificationScheduler(
      gateway: gateway,
      database: db,
      cycles: cycles,
      clock: testClock,
    );
    copy = const NotificationCopy(
      channelPredictionsName: 'Predictions',
      channelPredictionsDescription: 'd',
      channelRemindersName: 'Reminders',
      channelRemindersDescription: 'd',
      channelMedicinesName: 'Medicines',
      channelMedicinesDescription: 'd',
      genericTitle: 'Selene',
      genericBody: 'Open the app.',
      windowOpeningTitle: 'A period is expected soon',
      windowOpeningBody: 'The window runs from 10 July to 16 July.',
      likelyStartedTitle: 'Has it started?',
      likelyStartedBody: 'Nothing logged yet.',
      nudgeTitle: 'Nothing logged',
      nudgeBody: 'No hurry.',
      lateNoticeTitle: 'The window has passed',
      lateNoticeBody: 'Nothing logged since it closed.',
      logAction: 'Started today',
      medicineTitle: _medicineTitle,
      medicineBody: _medicineBody,
      formatTime: _formatTime,
    );
  });

  tearDown(() => db.close());

  group('rescheduling', () {
    test('replaces everything rather than diffing', () async {
      await scheduler.reschedule(result, copy: copy);
      expect(gateway.cancelCount, 1);
      expect(gateway.scheduled, isNotEmpty);

      await scheduler.reschedule(result, copy: copy);
      // A stale reminder about a window the user has already moved is the same
      // class of bug the prediction cache exists to prevent, only louder.
      expect(gateway.cancelCount, 2);
    });

    test('schedules nothing for a state with no window', () async {
      await scheduler.reschedule(const PredictionResult.noData(), copy: copy);
      expect(gateway.scheduled, isEmpty);
      // The cancel still happened, so a window that has gone away takes its
      // notifications with it.
      expect(gateway.cancelCount, 1);
    });
  });

  group('lock-screen privacy', () {
    test('defaults to hiding detail, without the user opting out', () async {
      // Risk R16: a banner reading "your period is expected tomorrow", visible
      // to anyone glancing at the phone, is a real data leak, and it is the one
      // place this project's offline story would otherwise leak by default.
      await scheduler.reschedule(result, copy: copy);
      expect(gateway.detailedFlags, isNotEmpty);
      expect(gateway.detailedFlags.every((detailed) => !detailed), isTrue);
    });

    test('shows detail only after an explicit opt-in', () async {
      await db.settingsDao.writeBool(
        SettingKey.detailedNotifications,
        value: true,
      );
      await scheduler.reschedule(result, copy: copy);
      expect(gateway.detailedFlags.every((detailed) => detailed), isTrue);
    });

    test('says nothing about a cycle when detail is off', () {
      // The generic wording is what actually reaches the lock screen by
      // default, so it is the wording that matters most.
      //
      // The title is the app's own name, and that is as private as it can be:
      // Android puts the app name on every notification regardless, and hiding
      // the app's identity was considered and rejected as disproportionate
      // (ADR-0004, on stealth features). What must not appear is anything
      // about *this* cycle.
      expect(
        copy.titleFor(NotificationKind.windowOpening, detailed: false),
        copy.genericTitle,
      );

      for (final kind in NotificationKind.values) {
        final body = copy.bodyFor(kind, detailed: false).toLowerCase();
        for (final leak in <String>[
          'period',
          'cycle',
          'expected',
          'window',
          'started',
          'late',
        ]) {
          expect(
            body,
            isNot(contains(leak)),
            reason: '"$body" leaked "$leak"',
          );
        }
        // And every kind collapses to the same words, so the *choice* of
        // notification cannot be read off the lock screen either.
        expect(copy.bodyFor(kind, detailed: false), copy.genericBody);
        expect(copy.titleFor(kind, detailed: false), copy.genericTitle);
      }
    });
  });

  group('the permission request', () {
    test('waits until a cycle has actually been logged', () async {
      // Asking at first launch gets denied by reflex, and on Android 13+
      // re-asking after a denial is deliberately hard.
      expect(await scheduler.shouldRequestPermission(), isFalse);
      expect(await scheduler.requestPermissionIfEarned(), isFalse);
      expect(gateway.permissionRequests, 0);

      await cycles.upsert(
        DayLog(date: testClock.today(), flow: FlowIntensity.medium),
      );
      expect(await scheduler.shouldRequestPermission(), isTrue);
      expect(await scheduler.requestPermissionIfEarned(), isTrue);
      expect(gateway.permissionRequests, 1);
    });

    test('is asked when a medicine reminder is set, and counts as the one '
        'request', () async {
      // Someone who has just chosen a time to be reminded at has asked for a
      // notification, whether or not a cycle is logged yet.
      expect(await scheduler.requestPermissionForReminder(), isTrue);
      expect(gateway.permissionRequests, 1);
      expect(
        await db.settingsDao.readBool(
          SettingKey.notificationPermissionAsked,
          orElse: false,
        ),
        isTrue,
      );

      gateway.grantPermission = false;
      expect(await scheduler.requestPermissionForReminder(), isFalse);
    });

    test('does not count a symptom-only day as a logged cycle', () async {
      await cycles.upsert(
        DayLog(
          date: testClock.today(),
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.mild,
          },
        ),
      );
      expect(await scheduler.shouldRequestPermission(), isFalse);
    });
  });

  group('the exact-alarm request', () {
    test('is put once, and only where the answer would change something',
        () async {
      // A phone that already allows them, every one before Android 12
      // included, is not asked at all (ADR-0026).
      gateway.exactAllowed = true;
      expect(await scheduler.shouldRequestExactReminders(), isFalse);

      gateway.exactAllowed = false;
      expect(await scheduler.shouldRequestExactReminders(), isTrue);
      expect(await scheduler.requestExactReminders(), isFalse);
      expect(gateway.exactRequests, 1);
      // Asked, so not again by itself. Settings keeps offering it.
      expect(await scheduler.shouldRequestExactReminders(), isFalse);
      expect(
        await db.settingsDao.readBool(
          SettingKey.exactAlarmPermissionAsked,
          orElse: false,
        ),
        isTrue,
      );
    });

    test('can be recorded as asked without asking the platform', () async {
      // "Not now" must not open Android's settings screen, and must not come
      // back on the next reminder either.
      await scheduler.recordExactRemindersAsked();
      expect(gateway.exactRequests, 0);
      expect(await scheduler.shouldRequestExactReminders(), isFalse);
    });

    test('reports what the platform currently allows', () async {
      expect(await scheduler.exactRemindersAllowed(), isFalse);
      gateway.exactAllowed = true;
      expect(await scheduler.exactRemindersAllowed(), isTrue);
    });
  });

  group('the one-tap action', () {
    test('logs a period start without the app being opened', () async {
      // The highest-leverage item in the whole notification section: it
      // collapses the most common logging event to a single tap.
      await scheduler.handleAction(logPeriodActionId);
      final logs = await cycles.logs();
      expect(logs, hasLength(1));
      expect(logs.single.date, testClock.today());
      expect(logs.single.isBleedingDay, isTrue);
    });

    test('ignores an action it does not know', () async {
      await scheduler.handleAction('something_else');
      expect(await cycles.logs(), isEmpty);
    });
  });

  group('missed reminders', () {
    // Written against dates the planner could actually produce. The first
    // version of this test handed `checkForMissedReminder` a list containing a
    // date in the past, which `plan` never returns, so it passed while the
    // feature it covers could not fire in the app at all.
    test('are reported once the stored schedule has a date that passed', () async {
      NotificationScheduler at(int days) => NotificationScheduler(
        gateway: gateway,
        database: db,
        cycles: CycleRepository(database: db, clock: testClock.advanced(days)),
        clock: testClock.advanced(days),
      );

      // Day 0. A reminder is scheduled two days out; nothing has been missed,
      // and there is no previous visit to compare against.
      expect(
        await scheduler.checkForMissedReminder(<PlannedNotification>[
          PlannedNotification(
            kind: NotificationKind.windowOpening,
            fireDate: testClock.today().addDays(2),
          ),
        ]),
        isFalse,
      );
      expect(
        await db.settingsDao.readInt(
          SettingKey.lastOpenedEpochDay,
          orElse: -1,
        ),
        testClock.today().epochDay,
      );

      // Day 3. That date came and went while the app was closed. What answers
      // the question is the schedule stored on day 0 — nothing about the plan
      // being built now could, because every date in it is still in the future.
      expect(
        await at(3).checkForMissedReminder(const <PlannedNotification>[]),
        isTrue,
      );

      // And it is reported once. The visit is recorded and the stored schedule
      // replaced, so the next check has nothing left to report.
      expect(
        await at(3).checkForMissedReminder(const <PlannedNotification>[]),
        isFalse,
      );
    });

    test('reschedule leaves a schedule behind for the next launch', () async {
      // Without this the detection above has nothing to compare against on the
      // next launch, and quietly answers no for ever.
      final planned = await scheduler.reschedule(result, copy: copy);
      await scheduler.checkForMissedReminder(planned);
      expect(planned, isNotEmpty);
      expect(
        await db.settingsDao.raw(SettingKey.scheduledFireDays),
        planned.map((n) => n.fireDate.epochDay).join(','),
      );
    });
  });

  group('preferences', () {
    test('read the nudge as off unless it was turned on', () async {
      expect((await scheduler.preferences()).nudgeEnabled, isFalse);
      await db.settingsDao.writeBool(SettingKey.nudgeEnabled, value: true);
      expect((await scheduler.preferences()).nudgeEnabled, isTrue);
    });

    test('carry the last nudge date for the cap', () async {
      expect((await scheduler.preferences()).lastNudge, isNull);
      await scheduler.recordNudgeShown();
      expect((await scheduler.preferences()).lastNudge, testClock.today());
    });

    test('read the late-period check-in as the reminders before a period '
        'were set, until it is set itself', () async {
      // It came with those reminders before it had a switch of its own, so
      // nobody's notifications change on update (ADR-0025).
      expect((await scheduler.preferences()).lateCheckInEnabled, isTrue);
      await db.settingsDao.writeBool(SettingKey.reminderEnabled, value: false);
      expect((await scheduler.preferences()).lateCheckInEnabled, isFalse);

      await db.settingsDao.writeBool(
        SettingKey.lateCheckInEnabled,
        value: true,
      );
      final preferences = await scheduler.preferences();
      expect(preferences.predictionsEnabled, isFalse);
      expect(preferences.lateCheckInEnabled, isTrue);
    });
  });

  group('medicine reminders', () {
    const pill = RecordedMedicine(key: 'pill.oral.rx', name: 'PILL');

    Future<void> remind(List<ReminderTime> times) async {
      await db.settingsDao.writeRaw(
        SettingKey.recordedMedicines.wireName,
        MedicineListRepository.encode(const <RecordedMedicine>[pill]),
      );
      await MedicineListRepository(
        db.settingsDao,
      ).setReminders(pill.key, times);
    }

    test('are scheduled for every time set on a recorded medicine', () async {
      await remind(const <ReminderTime>[
        ReminderTime(20, 0),
        ReminderTime(8, 0),
      ]);
      await scheduler.reschedule(result, copy: copy);
      expect(gateway.daily, const <DailyReminder>[
        DailyReminder(id: 2000, medicine: 'PILL', time: ReminderTime(8, 0)),
        DailyReminder(id: 2001, medicine: 'PILL', time: ReminderTime(20, 0)),
      ]);
    });

    test('are rebuilt with everything else, never added twice', () async {
      await remind(const <ReminderTime>[ReminderTime(8, 0)]);
      await scheduler.reschedule(result, copy: copy);
      await scheduler.reschedule(result, copy: copy);
      expect(gateway.cancelCount, 2);
      expect(gateway.daily, hasLength(1));
    });

    test('do not depend on the cycle, its window or its switches', () async {
      // A medicine is taken whatever the prediction says, and turning off the
      // notices about a period is not turning off a medicine.
      await remind(const <ReminderTime>[ReminderTime(8, 0)]);
      await db.settingsDao.writeBool(SettingKey.reminderEnabled, value: false);
      await db.settingsDao.writeBool(
        SettingKey.lateCheckInEnabled,
        value: false,
      );
      await scheduler.reschedule(const PredictionResult.noData(), copy: copy);
      expect(gateway.scheduled, isEmpty);
      expect(gateway.daily, hasLength(1));
    });

    test('are not in the schedule the missed-reminder check keeps', () async {
      // They repeat every day, so every day the app was closed would read as
      // one missed.
      await remind(const <ReminderTime>[ReminderTime(8, 0)]);
      final planned = await scheduler.reschedule(
        const PredictionResult.noData(),
        copy: copy,
      );
      expect(planned, isEmpty);
      await scheduler.checkForMissedReminder(planned);
      expect(await db.settingsDao.raw(SettingKey.scheduledFireDays), isEmpty);
    });

    test('without detail, say only that they are yours and when', () {
      const reminder = DailyReminder(
        id: 2000,
        medicine: 'PILL',
        time: ReminderTime(8, 0),
      );
      expect(
        copy.medicineTitleFor(reminder, detailed: false),
        copy.genericTitle,
      );
      expect(copy.medicineBodyFor(reminder), isNot(contains('PILL')));
      expect(copy.medicineBodyFor(reminder), contains('08:00'));
      expect(copy.medicineTitleFor(reminder, detailed: true), contains('PILL'));
    });
  });

  group('the bootstrap', () {
    test('replaces the no-op gateway with a real one', () {
      // The default gateway does nothing, so that no widget test schedules a
      // real notification. That default is also indistinguishable from a
      // working notification system right up until someone needs a reminder,
      // which is why the shipped path is asserted to override it.
      final source = File('lib/main.dart').readAsStringSync();
      expect(source, contains('notificationGatewayProvider.overrideWith'));
      expect(source, contains('buildNotificationGateway'));
      expect(source, contains('logPeriodActionId'));
    });

    test('the no-op gateway really is inert', () async {
      const noop = NoopNotificationGateway();
      await noop.initialize(copy);
      await noop.cancelAll();
      await noop.schedule(
        PlannedNotification(
          kind: NotificationKind.windowOpening,
          fireDate: testClock.today(),
        ),
        copy: copy,
        detailed: true,
      );
      expect(await noop.pendingIds(), isEmpty);
      expect(await noop.requestPermission(), isFalse);
    });
  });

  group('the copy', () {
    testWidgets('never mentions pregnancy, and never a bare date', (
      tester,
    ) async {
      // A late period has many causes. Guessing at one of them is a diagnosis
      // and it is not the app's to make (docs/PLAN.md 6.2).
      await tester.pumpWidget(harness(const SizedBox(), database: db));
      final context = tester.element(find.byType(SizedBox));
      final real = buildNotificationCopy(context, result);

      final all = <String>[
        real.windowOpeningTitle,
        real.windowOpeningBody,
        real.likelyStartedTitle,
        real.likelyStartedBody,
        real.nudgeTitle,
        real.nudgeBody,
        real.lateNoticeTitle,
        real.lateNoticeBody,
        real.genericTitle,
        real.genericBody,
        real.medicineTitle('PILL'),
        real.medicineBody('08:00'),
      ].join(' ').toLowerCase();

      for (final forbidden in <String>[
        'pregnan',
        'safe day',
        'fertile',
        'ovulat',
        'streak',
      ]) {
        expect(all, isNot(contains(forbidden)), reason: 'copy said $forbidden');
      }

      // The window notice names a range, because a single date on a lock
      // screen claims a precision the model does not have.
      expect(real.windowOpeningBody, contains(' to '));
    });

    testWidgets('falls back to the generic body when there is no window', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const SizedBox(), database: db));
      final context = tester.element(find.byType(SizedBox));
      final none = buildNotificationCopy(
        context,
        const PredictionResult.noData(),
      );
      expect(none.windowOpeningBody, none.genericBody);
    });

    testWidgets("names every channel in the user's language", (tester) async {
      await tester.pumpWidget(harness(const SizedBox(), database: db));
      final context = tester.element(find.byType(SizedBox));
      final l10n = AppLocalizations.of(context);
      final real = buildNotificationCopy(context, result);
      expect(real.channelPredictionsName, l10n.notificationChannelPredictions);
      expect(real.channelRemindersName, l10n.notificationChannelReminders);
      expect(real.channelMedicinesName, l10n.notificationChannelMedicines);
    });

    testWidgets("writes a medicine reminder's time as the phone writes times", (
      tester,
    ) async {
      const reminder = DailyReminder(
        id: 2000,
        medicine: 'PILL',
        time: ReminderTime(20, 5),
      );
      await tester.pumpWidget(harness(const SizedBox(), database: db));
      final real = buildNotificationCopy(
        tester.element(find.byType(SizedBox)),
        result,
      );
      expect(real.medicineBodyFor(reminder), contains('8:05 PM'));
      expect(real.medicineBodyFor(reminder), isNot(contains('PILL')));
      expect(real.medicineTitleFor(reminder, detailed: true), contains('PILL'));
    });

    testWidgets('and on the 24-hour clock when the phone is set to it', (
      tester,
    ) async {
      // Set where the phone's setting arrives, as Flutter's own time picker
      // reads it.
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: const SizedBox(),
            ),
          ),
          database: db,
        ),
      );
      final real = buildNotificationCopy(
        tester.element(find.byType(SizedBox)),
        result,
      );
      expect(real.formatTime(const ReminderTime(20, 5)), '20:05');
    });
  });
}
