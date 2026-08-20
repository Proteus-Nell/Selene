// The notification rules (AND-17, docs/PLAN.md 2.4.3).
//
// The planner is pure on purpose. Every rule in the 2.4.3 table is a date
// calculation, and the alternative to testing them here is discovering on a
// real phone that the nudge cap was off by a day.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
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

    test('is silent when predictions are switched off', () {
      expect(
        planFor(
          result,
          preferences: const NotificationPreferences(
            predictionsEnabled: false,
          ),
        ),
        isEmpty,
      );
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
          daysSinceLastLog: 90,
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
