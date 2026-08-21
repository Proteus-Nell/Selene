// When the app is allowed to say something (AND-27, PLAN 6.2).
//
// The hint observes two things the user logged and points at a clinician. It
// never says why they coincide, because from two logged symptoms it cannot
// know. These tests are mostly about when it stays quiet, which is the harder
// half: a prompt that fires every cycle is a prompt the user learns to dismiss
// without reading, and that costs them the one time it would have mattered.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/nutrition_hint.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  final today = CivilDate.parseIso8601('2026-06-30');

  DayLog day(
    int daysAgo, {
    FlowIntensity flow = FlowIntensity.heavy,
    SymptomSeverity fatigue = SymptomSeverity.moderate,
  }) => DayLog(
    date: today.addDays(-daysAgo),
    flow: flow,
    symptoms: fatigue == SymptomSeverity.none
        ? const <Symptom, SymptomSeverity>{}
        : <Symptom, SymptomSeverity>{Symptom.energy: fatigue},
  );

  group('it stays quiet', () {
    test('with nothing logged', () {
      expect(
        NutritionHints.fatigueWithHeavyFlow(const <DayLog>[], today),
        isFalse,
      );
    });

    test('for a single heavy, tired day', () {
      // An ordinary period. Saying something here would mean saying something
      // every month.
      expect(
        NutritionHints.fatigueWithHeavyFlow(<DayLog>[day(3)], today),
        isFalse,
      );
    });

    test('one day short of the threshold', () {
      final logs = <DayLog>[
        for (var i = 0; i < NutritionHints.minCoincidences - 1; i++) day(i * 5),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('for heavy flow without fatigue', () {
      final logs = <DayLog>[
        for (var i = 0; i < 6; i++) day(i * 5, fatigue: SymptomSeverity.none),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('for fatigue without heavy flow', () {
      final logs = <DayLog>[
        for (var i = 0; i < 6; i++) day(i * 5, flow: FlowIntensity.light),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('when the two never fall on the same day', () {
      // The condition is coincidence, not co-occurrence in the same month.
      // Heavy days in one week and tired days in another are two separate
      // things the app has no business joining up.
      final logs = <DayLog>[
        for (var i = 0; i < 6; i++) day(i * 10, fatigue: SymptomSeverity.none),
        for (var i = 0; i < 6; i++) day(i * 10 + 5, flow: FlowIntensity.light),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('for mild fatigue', () {
      // Including mild would fire this for almost everyone, which is the same
      // as never firing it.
      final logs = <DayLog>[
        for (var i = 0; i < 6; i++) day(i * 5, fatigue: SymptomSeverity.mild),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('for a pattern that has stopped', () {
      // Outside the lookback. The hint describes how things are, not how they
      // were two years ago.
      final logs = <DayLog>[
        for (var i = 0; i < 6; i++)
          day(NutritionHints.lookbackDays + 10 + i * 5),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });

    test('for days that have not happened yet', () {
      final logs = <DayLog>[for (var i = 1; i <= 6; i++) day(-i * 5)];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isFalse);
    });
  });

  group('it speaks', () {
    test('when heavy flow and fatigue coincide often enough', () {
      final logs = <DayLog>[
        for (var i = 0; i < NutritionHints.minCoincidences; i++) day(i * 5),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isTrue);
    });

    test('counting severe fatigue as well as moderate', () {
      final logs = <DayLog>[
        for (var i = 0; i < NutritionHints.minCoincidences; i++)
          day(i * 5, fatigue: SymptomSeverity.severe),
      ];
      expect(NutritionHints.fatigueWithHeavyFlow(logs, today), isTrue);
    });

    test('and names the days it counted', () {
      // Exposed so this test can state which days it means, rather than
      // asserting a bool and hoping the count came from the right ones.
      final logs = <DayLog>[
        day(1),
        day(2, flow: FlowIntensity.light),
        day(3),
        day(NutritionHints.lookbackDays + 5),
        day(4),
      ];
      expect(
        NutritionHints.coincidingDays(logs, today),
        <CivilDate>[
          today.addDays(-1),
          today.addDays(-3),
          today.addDays(-4),
        ],
      );
    });
  });
}
