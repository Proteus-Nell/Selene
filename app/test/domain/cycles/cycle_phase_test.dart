// Where in the cycle a day falls (AND-25, ADR-0007).
//
// The rules are stated here as examples rather than fixtures because they are
// judgement calls about what the app is entitled to claim, not arithmetic that
// speaks for itself. Two of them carry the weight:
//
//   * The day count and the phase name are withheld independently. The app can
//     nearly always say what day of the cycle it is — that is subtraction on a
//     date the user logged — while having no basis at all for naming a phase.
//   * A phase is never named without a prediction to anchor the luteal
//     boundary to, and the boundary is never published as a date or called
//     ovulation.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  CivilDate d(String iso) => CivilDate.parseIso8601(iso);

  /// Bleeding days from [start], inclusive, at a real bleeding intensity.
  List<DayLog> period(String start, {int days = 5}) {
    final from = d(start);
    return <DayLog>[
      for (var i = 0; i < days; i++)
        DayLog(date: from.addDays(i), flow: FlowIntensity.medium),
    ];
  }

  group('with nothing logged', () {
    test('there is no day and no phase', () {
      final position = CyclePhases.on(date: d('2026-03-01'), logs: const []);
      expect(position.dayOfCycle, isNull);
      expect(position.phase, isNull);
    });

    test('spotting alone does not start a cycle', () {
      // Segmentation treats spotting as not bleeding, and this has to agree
      // with it: a phase strip that started counting on a spotting day would
      // contradict the cycle list on the next screen.
      final position = CyclePhases.on(
        date: d('2026-03-05'),
        logs: <DayLog>[
          DayLog(date: d('2026-03-01'), flow: FlowIntensity.spotting),
        ],
      );
      expect(position.dayOfCycle, isNull);
      expect(position.phase, isNull);
    });
  });

  group('during bleeding', () {
    test('is the period phase, without needing a prediction', () {
      // The only phase read straight off what the user logged, and so the only
      // one the app can always name.
      final position = CyclePhases.on(
        date: d('2026-03-03'),
        logs: period('2026-03-01'),
      );
      expect(position.phase, CyclePhase.period);
      expect(position.dayOfCycle, 3);
    });

    test('the first day is day one, not day zero', () {
      final position = CyclePhases.on(
        date: d('2026-03-01'),
        logs: period('2026-03-01'),
      );
      expect(position.dayOfCycle, 1);
    });
  });

  group('after bleeding, with a prediction', () {
    final logs = period('2026-03-01');
    final predicted = d('2026-03-29');

    test('the last fourteen days before it are luteal', () {
      final position = CyclePhases.on(
        date: d('2026-03-16'),
        logs: logs,
        predictedStart: predicted,
      );
      expect(position.phase, CyclePhase.luteal);
    });

    test('the day before that is still follicular', () {
      // The boundary is exactly lutealPhaseDays before the predicted start,
      // and the test pins both sides of it rather than one.
      final boundary = predicted.addDays(-CyclePhases.lutealPhaseDays);
      expect(
        CyclePhases.on(
          date: boundary,
          logs: logs,
          predictedStart: predicted,
        ).phase,
        CyclePhase.luteal,
      );
      expect(
        CyclePhases.on(
          date: boundary.addDays(-1),
          logs: logs,
          predictedStart: predicted,
        ).phase,
        CyclePhase.follicular,
      );
    });

    test('counting from the last period, not from the prediction', () {
      final position = CyclePhases.on(
        date: d('2026-03-20'),
        logs: logs,
        predictedStart: predicted,
      );
      expect(position.dayOfCycle, 20);
    });
  });

  group('what is withheld', () {
    test('no prediction means no phase, but the day still counts', () {
      // The separation that matters. Withholding the day count along with the
      // phase would cost the user a fact the app is certain of.
      final position = CyclePhases.on(
        date: d('2026-03-20'),
        logs: period('2026-03-01'),
      );
      expect(position.phase, isNull);
      expect(position.dayOfCycle, 20);
    });

    test('an overdue period is not luteal', () {
      // The prediction has already passed, so the cycle has outrun the model.
      // Naming those days luteal would assert something about a cycle the app
      // can no longer describe.
      final position = CyclePhases.on(
        date: d('2026-04-05'),
        logs: period('2026-03-01'),
        predictedStart: d('2026-03-29'),
      );
      expect(position.phase, isNull);
      expect(position.dayOfCycle, 36);
    });

    test('once the trail goes cold, nothing is claimed at all', () {
      // Not "day 340 of your cycle". That is a gap, not a cycle day, and the
      // threshold is the same one the log screen uses to say welcome back, so
      // the two screens cannot disagree about whether a cycle is in progress.
      final position = CyclePhases.on(
        date: d('2026-03-01').addDays(CycleRules.lostTrackAfterDays + 1),
        logs: period('2026-03-01'),
      );
      expect(position.dayOfCycle, isNull);
      expect(position.phase, isNull);
    });

    test('asking about a past day gives that day, not today', () {
      // Two cycles logged; a question about a day inside the first must not be
      // answered from the second.
      final logs = <DayLog>[...period('2026-01-01'), ...period('2026-01-29')];
      final position = CyclePhases.on(date: d('2026-01-10'), logs: logs);
      expect(position.dayOfCycle, 10);
    });
  });

  group('the ovulation estimate', () {
    final logs = period('2026-03-01');
    final predicted = d('2026-03-29');

    test('is absent unless it is asked for', () {
      // Default off at the lowest level, not only in the UI. Forgetting to ask
      // has to be the safe outcome — docs/PLAN.md 6.2.
      final position = CyclePhases.on(
        date: d('2026-03-16'),
        logs: logs,
        predictedStart: predicted,
      );
      expect(position.ovulationEstimate, isNull);
    });

    test('is a range and never a single day', () {
      // A point estimate reads as a fact. This is a population average applied
      // to someone whose actual ovulation the app cannot observe — no
      // temperature, no LH, no ultrasound.
      final position = CyclePhases.on(
        date: d('2026-03-16'),
        logs: logs,
        predictedStart: predicted,
        withOvulationEstimate: true,
      );
      final range = position.ovulationEstimate!;
      expect(range.lengthInDays, greaterThan(1));
      expect(
        range.lengthInDays,
        CyclePhases.ovulationSpreadDays * 2 + 1,
      );
    });

    test('sits around the follicular-luteal boundary', () {
      final position = CyclePhases.on(
        date: d('2026-03-16'),
        logs: logs,
        predictedStart: predicted,
        withOvulationEstimate: true,
      );
      final boundary = predicted.addDays(-CyclePhases.lutealPhaseDays);
      expect(position.ovulationEstimate!.contains(boundary), isTrue);
    });

    test('is never produced without a prediction to anchor it', () {
      final position = CyclePhases.on(
        date: d('2026-03-16'),
        logs: logs,
        withOvulationEstimate: true,
      );
      expect(position.ovulationEstimate, isNull);
    });
  });
}
