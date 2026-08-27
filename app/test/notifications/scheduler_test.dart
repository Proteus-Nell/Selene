// The scheduler and the copy rules (AND-17).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
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
  NotificationCopy? initialisedWith;
  int cancelCount = 0;
  int permissionRequests = 0;
  bool grantPermission = true;

  @override
  Future<void> initialize(NotificationCopy copy) async =>
      initialisedWith = copy;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> cancelAll() async => cancelCount++;

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
  Future<List<int>> pendingIds() async =>
      scheduled.map((s) => s.kind.id).toList();
}

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

    testWidgets("names both channels in the user's language", (tester) async {
      await tester.pumpWidget(harness(const SizedBox(), database: db));
      final context = tester.element(find.byType(SizedBox));
      final l10n = AppLocalizations.of(context);
      final real = buildNotificationCopy(context, result);
      expect(real.channelPredictionsName, l10n.notificationChannelPredictions);
      expect(real.channelRemindersName, l10n.notificationChannelReminders);
    });
  });
}
