// The notification rules (AND-17, docs/PLAN.md 2.4.3).
//
// The planner is pure on purpose. Every rule in the 2.4.3 table is a date
// calculation, and the alternative to testing them here is discovering on a
// real phone that the nudge cap was off by a day.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/notifications/notification_plan.dart';

CivilDate day(String iso) => CivilDate.parseIso8601(iso);

final CivilDate today = day('2026-06-30');

Prediction predictionFrom(String start, String end, {String? median}) =>
    Prediction(
      medianStart: day(median ?? start),
      window50: CivilDateRange(day(start), day(end)),
      window80: CivilDateRange(day(start), day(end)),
      confidence: Confidence.medium,
      basis: const PredictionBasis(
        cyclesUsed: 6,
        medianLengthDays: 28,
        variabilityDays: 2,
        personalizedHyperparameters: true,
      ),
    );

PredictionResult predicted(String start, String end) =>
    PredictionResult.predicted(
      prediction: predictionFrom(start, end),
      statistics: const CycleStatistics(completedCycles: 6),
    );

List<PlannedNotification> planFor(
  PredictionResult result, {
  NotificationPreferences preferences = const NotificationPreferences(),
  CivilDate? lastLoggedDay,
}) => NotificationPlanner.plan(
  result: result,
  today: today,
  preferences: preferences,
  lastLoggedDay: lastLoggedDay,
);

Set<NotificationKind> kindsIn(List<PlannedNotification> planned) =>
    planned.map((p) => p.kind).toSet();

void main() {
  group('channels', () {
    test('separate the nudge from the predictions', () {
      // One channel for everything means a user annoyed by the nudge mutes the
      // predictions along with it (risk R15).
      expect(
        NotificationKind.loggingNudge.channel,
        NotificationChannelId.reminders,
      );
      for (final kind in <NotificationKind>[
        NotificationKind.windowOpening,
        NotificationKind.likelyStarted,
        NotificationKind.lateNotice,
      ]) {
        expect(kind.channel, NotificationChannelId.predictions);
      }
      expect(
        NotificationChannelId.values.map((c) => c.id).toSet(),
        hasLength(NotificationChannelId.values.length),
      );
    });

    test('give every kind its own id, so rescheduling replaces', () {
      final ids = NotificationKind.values.map((k) => k.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('with a predicted window', () {
    final result = predicted('2026-07-10', '2026-07-16');

    test('gives notice before the window opens, at the chosen lead', () {
      final planned = planFor(result);
      final opening = planned.firstWhere(
        (p) => p.kind == NotificationKind.windowOpening,
      );
      expect(opening.fireDate, day('2026-07-08'));

      final earlier = planFor(
        result,
        preferences: const NotificationPreferences(leadDays: 3),
      ).firstWhere((p) => p.kind == NotificationKind.windowOpening);
      expect(earlier.fireDate, day('2026-07-07'));
    });

    test('asks the day after the window opens, and again after it closes', () {
      final planned = planFor(result);
      expect(
        planned
            .firstWhere((p) => p.kind == NotificationKind.likelyStarted)
            .fireDate,
        day('2026-07-11'),
      );
      expect(
        planned
            .firstWhere((p) => p.kind == NotificationKind.lateNotice)
            .fireDate,
        day('2026-07-21'),
      );
    });

    test('schedules nothing in the past', () {
      final passed = predicted('2026-06-01', '2026-06-07');
      expect(planFor(passed), isEmpty);
    });

    test('is silent when its reminders and the check-in are both off', () {
      expect(
        planFor(
          result,
          preferences: const NotificationPreferences(
            predictionsEnabled: false,
            lateCheckInEnabled: false,
          ),
        ),
        isEmpty,
      );
    });

    test('keeps the late-period check-in when only the reminders before a '
        'period are off', () {
      // Two switches since ADR-0025: someone can want to hear only if a period
      // is late, and not before every one.
      expect(
        kindsIn(
          planFor(
            result,
            preferences: const NotificationPreferences(
              predictionsEnabled: false,
            ),
          ),
        ),
        <NotificationKind>{NotificationKind.lateNotice},
      );
    });

    test('leaves the late-period check-in out when it is off', () {
      expect(
        kindsIn(
          planFor(
            result,
            preferences: const NotificationPreferences(
              lateCheckInEnabled: false,
            ),
          ),
        ),
        <NotificationKind>{
          NotificationKind.windowOpening,
          NotificationKind.likelyStarted,
        },
      );
    });
  });

  group('with a window moved forward by a late period', () {
    // First expected 25 to 29 June. On the 30th nothing has been logged, so
    // the window shown has moved on to start today. The reminders belong to
    // the window first predicted: scheduled from the moved one, "likely
    // started" would fall due tomorrow every day, and the late notice would
    // move five days ahead of every day it was asked about.
    final moved = PredictionResult.predicted(
      prediction: predictionFrom('2026-06-30', '2026-07-04').copyWith(
        originalWindow80: CivilDateRange(day('2026-06-25'), day('2026-06-29')),
        daysLate: 1,
      ),
      statistics: const CycleStatistics(completedCycles: 6),
    );

    test('does not ask again whether it started', () {
      expect(
        kindsIn(planFor(moved)),
        isNot(contains(NotificationKind.likelyStarted)),
      );
      expect(
        kindsIn(planFor(moved)),
        isNot(contains(NotificationKind.windowOpening)),
      );
    });

    test('keeps the late notice where the first window put it', () {
      expect(
        planFor(
          moved,
        ).firstWhere((p) => p.kind == NotificationKind.lateNotice).fireDate,
        day('2026-07-04'),
      );
    });

    test('keeps it there once no range is given at all', () {
      final late = PredictionResult.laterThanExpected(
        expectedWindow80: CivilDateRange(day('2026-06-25'), day('2026-06-29')),
        daysLate: 1,
        statistics: const CycleStatistics(completedCycles: 6),
      );
      final planned = planFor(late);
      expect(kindsIn(planned), <NotificationKind>{NotificationKind.lateNotice});
      expect(planned.single.fireDate, day('2026-07-04'));
    });
  });

  group('with no window to talk about', () {
    test('says nothing at all', () {
      // Each of these is a state where the app has just told the user it
      // cannot support a window. A notification about one would contradict it.
      for (final result in <PredictionResult>[
        const PredictionResult.noData(),
        const PredictionResult.tooIrregular(
          statistics: CycleStatistics(completedCycles: 6),
        ),
        const PredictionResult.lostTrack(
          statistics: CycleStatistics(completedCycles: 6),
          daysSinceLastPeriod: 90,
        ),
        const PredictionResult.dataInconsistent(
          reason: DataInconsistency.clockWentBackwards,
        ),
      ]) {
        expect(planFor(result), isEmpty, reason: '$result');
      }
    });

    test('still uses the population prior when there is one', () {
      final result = PredictionResult.insufficientData(
        populationPrior: predictionFrom('2026-07-10', '2026-07-20'),
        cyclesLogged: 2,
      );
      expect(
        kindsIn(planFor(result)),
        contains(NotificationKind.windowOpening),
      );
    });
  });

  group('the logging nudge', () {
    test('is off unless the user turned it on', () {
      // The default in the 2.4.3 table, and the one that matters most: this is
      // the only notification that is neither a prediction nor actionable.
      const defaults = NotificationPreferences();
      expect(defaults.nudgeEnabled, isFalse);
      expect(
        planFor(
          const PredictionResult.noData(),
          lastLoggedDay: today.addDays(-20),
        ),
        isEmpty,
      );
    });

    test('fires seven days after the last log', () {
      final planned = planFor(
        const PredictionResult.noData(),
        preferences: const NotificationPreferences(nudgeEnabled: true),
        lastLoggedDay: today.addDays(-3),
      );
      expect(planned.single.kind, NotificationKind.loggingNudge);
      expect(planned.single.fireDate, today.addDays(4));
    });

    test('respects a hard cap of one per seven days', () {
      final planned = planFor(
        const PredictionResult.noData(),
        preferences: NotificationPreferences(
          nudgeEnabled: true,
          lastNudge: today.addDays(-1),
        ),
        lastLoggedDay: today.addDays(-3),
      );
      // Would have been today+4 on the silence rule alone; the cap pushes it
      // to six days after the last nudge, never closer.
      expect(planned.single.fireDate, today.addDays(6));
      expect(
        planned.single.fireDate.daysBetween(today.addDays(-1)).abs(),
        greaterThanOrEqualTo(NotificationPlanner.nudgeCapDays),
      );
    });

    test('stops once the app has admitted it lost track', () {
      // Past that point a nudge is not a reminder, it is nagging someone who
      // has stopped for a reason (2.4.1).
      expect(
        planFor(
          const PredictionResult.noData(),
          preferences: const NotificationPreferences(nudgeEnabled: true),
          lastLoggedDay: today.addDays(-CycleRules.lostTrackAfterDays - 1),
        ),
        isEmpty,
      );
    });

    test('says nothing when nothing has ever been logged', () {
      expect(
        planFor(
          const PredictionResult.noData(),
          preferences: const NotificationPreferences(nudgeEnabled: true),
        ),
        isEmpty,
      );
    });
  });

  group('missed reminders', () {
    test('are detected when their day passed while the app was closed', () {
      final scheduled = <CivilDate>[today.addDays(-2)];
      expect(
        NotificationPlanner.missedWhileClosed(
          fireDates: scheduled,
          lastOpened: today.addDays(-5),
          today: today,
        ),
        isTrue,
      );
      expect(
        NotificationPlanner.missedWhileClosed(
          fireDates: scheduled,
          lastOpened: today.addDays(-1),
          today: today,
        ),
        isFalse,
      );
    });

    test('are not reported on a first run', () {
      expect(
        NotificationPlanner.missedWhileClosed(
          fireDates: <CivilDate>[today],
          lastOpened: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('a freshly built plan can never contain a missed date', () {
      // The invariant that made the first version of this feature dead code:
      // every date `plan` produces is strictly after today, and a missed
      // reminder is by definition one whose date has already passed. Feeding
      // `missedWhileClosed` a plan built on this launch therefore always
      // answers no, which is why the scheduler compares against the schedule it
      // stored last time instead.
      final planned = planFor(
        predicted('2026-07-03', '2026-07-07'),
        preferences: const NotificationPreferences(nudgeEnabled: true),
        lastLoggedDay: today,
      );
      expect(planned, isNotEmpty, reason: 'nothing to check otherwise');
      for (final notification in planned) {
        expect(
          notification.fireDate > today,
          isTrue,
          reason:
              '${notification.kind} was planned for a date not in the '
              'future, which the planner must never do',
        );
      }
      expect(
        NotificationPlanner.missedWhileClosed(
          fireDates: planned.map((n) => n.fireDate).toList(),
          lastOpened: today.addDays(-30),
          today: today,
        ),
        isFalse,
      );
    });
  });

  group('medicine reminders', () {
    const pill = RecordedMedicine(key: 'pill.oral.rx', name: 'PILL');
    const iron = RecordedMedicine(key: 'iron.oral.otc', name: 'IRON');

    test('are one for each time set, medicine by medicine, earliest first', () {
      expect(
        NotificationPlanner.planMedicines(
          const <RecordedMedicine>[pill, iron],
          const <String, List<ReminderTime>>{
            'iron.oral.otc': <ReminderTime>[ReminderTime(13, 0)],
            'pill.oral.rx': <ReminderTime>[
              ReminderTime(8, 0),
              ReminderTime(20, 30),
            ],
          },
        ),
        const <DailyReminder>[
          DailyReminder(id: 2000, medicine: 'PILL', time: ReminderTime(8, 0)),
          DailyReminder(
            id: 2001,
            medicine: 'PILL',
            time: ReminderTime(20, 30),
          ),
          DailyReminder(id: 2002, medicine: 'IRON', time: ReminderTime(13, 0)),
        ],
      );
    });

    test("never take an id the cycle's notices use", () {
      // A shared id would let a medicine reminder replace a period notice on
      // the platform, or the other way round.
      final ids = NotificationKind.values.map((kind) => kind.id).toSet();
      expect(
        ids.every((id) => id < NotificationPlanner.firstMedicineReminderId),
        isTrue,
      );
    });

    test('are none for a medicine no longer recorded', () {
      expect(
        NotificationPlanner.planMedicines(
          const <RecordedMedicine>[iron],
          const <String, List<ReminderTime>>{
            'gone.oral.rx': <ReminderTime>[ReminderTime(8, 0)],
          },
        ),
        isEmpty,
      );
    });

    test('go out on a channel of their own', () {
      // So that muting the cycle's notices does not mute a medicine, nor the
      // other way round (risk R15).
      expect(NotificationChannelId.medicines.id, 'medicines');
      for (final kind in NotificationKind.values) {
        expect(kind.channel, isNot(NotificationChannelId.medicines));
      }
    });

    test('compare by value and print readably', () {
      const reminder = DailyReminder(
        id: 2000,
        medicine: 'PILL',
        time: ReminderTime(8, 0),
      );
      expect(
        reminder,
        const DailyReminder(
          id: 2000,
          medicine: 'PILL',
          time: ReminderTime(8, 0),
        ),
      );
      expect(
        reminder,
        isNot(
          const DailyReminder(
            id: 2001,
            medicine: 'PILL',
            time: ReminderTime(8, 0),
          ),
        ),
      );
      expect(reminder.hashCode, isNotNull);
      expect(reminder.toString(), contains('08:00'));
    });
  });

  group('PlannedNotification', () {
    test('compares by value and prints readably', () {
      final a = PlannedNotification(
        kind: NotificationKind.windowOpening,
        fireDate: today,
      );
      expect(
        a,
        PlannedNotification(
          kind: NotificationKind.windowOpening,
          fireDate: today,
        ),
      );
      expect(a.hashCode, isNotNull);
      expect(a.toString(), contains('windowOpening'));
      expect(
        a,
        isNot(
          PlannedNotification(
            kind: NotificationKind.lateNotice,
            fireDate: today,
          ),
        ),
      );
    });
  });
}
