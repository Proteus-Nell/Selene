// Conditions: recorded, displayed, and kept away from the model (AND-26).
//
// The claim ADR-0010 makes is unusual for a feature, so it is worth restating
// where it is enforced: the app asks the user for information it has decided in
// advance not to act on. That is not an oversight. The shipped priors were
// fitted with no condition strata, so making the filter behave differently for
// PCOS would be inventing calibration and presenting it as a measurement — the
// specific kind of confident wrongness this whole project is organised against.
//
// The single exception withholds a prediction rather than making a different
// one, and needs no new arithmetic to do it.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/prediction.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late CycleRepository cycles;
  late ConditionRepository conditions;
  late PredictionRepository predictions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock.iso('2026-06-30');
    cycles = CycleRepository(database: db, clock: clock);
    conditions = ConditionRepository(database: db, clock: clock);
    predictions = PredictionRepository(database: db, cycles: cycles);
  });

  tearDown(() => db.close());

  /// Logs [lengths.length] + 1 period starts, the last ending today.
  Future<void> logHistory(List<int> lengths) async {
    final total = lengths.fold<int>(0, (sum, l) => sum + l);
    var start = clock.today().addDays(-total);
    for (final length in lengths) {
      await cycles.logPeriod(CivilDateRange(start, start.addDays(4)));
      start = start.addDays(length);
    }
    await cycles.logPeriod(CivilDateRange(start, start.addDays(4)));
  }

  group('recording', () {
    test('a condition starts open-ended', () async {
      final record = await conditions.add(
        condition: Condition.pcos,
        start: CivilDate.parseIso8601('2026-01-01'),
      );
      expect(record.end, isNull);
      expect(record.isActiveOn(clock.today()), isTrue);
    });

    test('the same condition can be recorded twice over a life', () async {
      // Someone can start the pill, stop, and start again years later, and both
      // spans are true. A natural key on the condition would force the second
      // to overwrite the first and take the interpretation of those older
      // cycles with it.
      await conditions.add(
        condition: Condition.hormonalContraceptionCombined,
        start: CivilDate.parseIso8601('2019-03-01'),
        end: CivilDate.parseIso8601('2021-06-01'),
      );
      await conditions.add(
        condition: Condition.hormonalContraceptionCombined,
        start: CivilDate.parseIso8601('2025-01-01'),
      );
      expect(await conditions.all(), hasLength(2));
    });

    test('ending one keeps it rather than deleting it', () async {
      // The whole reason this is a span and not a flag. "I was on the pill for
      // those six cycles" stays true after stopping, and a flag loses it the
      // moment it is switched off.
      final record = await conditions.add(
        condition: Condition.breastfeeding,
        start: CivilDate.parseIso8601('2026-01-01'),
      );
      await conditions.end(
        id: record.id,
        end: CivilDate.parseIso8601('2026-05-01'),
      );

      final stored = (await conditions.all()).single;
      expect(stored.end, CivilDate.parseIso8601('2026-05-01'));
      expect(stored.start, CivilDate.parseIso8601('2026-01-01'));
      expect(stored.isActiveOn(clock.today()), isFalse);
      expect(
        stored.covers(CivilDate.parseIso8601('2026-03-01')),
        isTrue,
        reason: 'the span it covered was lost when it ended',
      );
    });

    test('one ended by mistake can be reopened', () async {
      final record = await conditions.add(
        condition: Condition.perimenopause,
        start: CivilDate.parseIso8601('2026-01-01'),
      );
      await conditions.end(id: record.id, end: clock.today());
      await conditions.reopen(record.id);
      expect((await conditions.all()).single.end, isNull);
    });

    test('a mistyped one is really deleted', () async {
      final record = await conditions.add(
        condition: Condition.other,
        start: clock.today(),
      );
      await conditions.remove(record.id);
      expect(await conditions.all(), isEmpty);
    });
  });

  group('dates that cannot be true', () {
    test('a future start is clamped to today', () async {
      // A future-dated row is almost always a wrong device clock, and it would
      // make "currently active" depend on a day that has not happened.
      final record = await conditions.add(
        condition: Condition.pcos,
        start: clock.today().addDays(30),
      );
      expect(record.start, clock.today());
    });

    test('an end before the start is clamped to the start', () async {
      // An inverted span makes every overlap count that reads it wrong, with
      // nothing on screen to indicate it.
      final record = await conditions.add(
        condition: Condition.pcos,
        start: CivilDate.parseIso8601('2026-03-01'),
      );
      await conditions.end(
        id: record.id,
        end: CivilDate.parseIso8601('2026-01-01'),
      );
      expect((await conditions.all()).single.end, record.start);
    });
  });

  group('an active pregnancy', () {
    test('withholds the prediction instead of forecasting one', () async {
      await logHistory(<int>[28, 28, 28, 28, 28, 28]);
      expect(await predictions.current(), isA<Predicted>());

      await conditions.add(
        condition: Condition.pregnancy,
        start: clock.today().addDays(-30),
      );

      final result = await predictions.current();
      expect(result, isA<SuppressedByCondition>());
      expect(
        (result as SuppressedByCondition).condition,
        Condition.pregnancy,
      );
    });

    test('does not take the user history with it', () async {
      // Withholding a prediction must never also withhold what the user
      // themselves logged. A pregnancy ends, and those cycles are still theirs.
      await logHistory(<int>[28, 29, 28, 30, 28, 29]);
      await conditions.add(
        condition: Condition.pregnancy,
        start: clock.today().addDays(-30),
      );

      final result = await predictions.current() as SuppressedByCondition;
      expect(result.statistics.completedCycles, greaterThan(0));
      expect(result.statistics.medianLengthDays, greaterThan(0));
    });

    test('once ended, predictions come back', () async {
      await logHistory(<int>[28, 28, 28, 28, 28, 28]);
      final record = await conditions.add(
        condition: Condition.pregnancy,
        start: clock.today().addDays(-30),
      );
      expect(await predictions.current(), isA<SuppressedByCondition>());

      await conditions.end(id: record.id, end: clock.today().addDays(-1));
      expect(await predictions.current(), isA<Predicted>());
    });

    test('a past pregnancy does not suppress anything', () async {
      await logHistory(<int>[28, 28, 28, 28, 28, 28]);
      await conditions.add(
        condition: Condition.pregnancy,
        start: CivilDate.parseIso8601('2020-01-01'),
        end: CivilDate.parseIso8601('2020-10-01'),
      );
      expect(await predictions.current(), isA<Predicted>());
    });
  });

  group('every other condition', () {
    test('changes nothing about the prediction', () async {
      // The scope correction written into AND-26: an earlier draft had hormonal
      // contraception suppressing too. Only pregnancy does. Contraception often
      // removes true cycles entirely (PLAN 1081) and is the obvious next
      // candidate — it was considered and not chosen, so this test is what
      // stops it being added quietly.
      await logHistory(<int>[28, 29, 28, 30, 28, 29]);
      final before = await predictions.current();

      for (final condition in Condition.values) {
        if (condition.suppressesPrediction) continue;
        final record = await conditions.add(
          condition: condition,
          start: clock.today().addDays(-60),
        );
        expect(
          await predictions.current(),
          before,
          reason: '${condition.name} changed the prediction',
        );
        await conditions.remove(record.id);
      }
    });

    test('only pregnancy is marked as suppressing', () async {
      expect(
        Condition.values.where((c) => c.suppressesPrediction),
        <Condition>[Condition.pregnancy],
      );
    });
  });

  group('nothing reaches the filter', () {
    test('because its signature cannot accept one', () async {
      // The strongest form of this guarantee, and it is structural rather than
      // behavioural: BayesFilter.update takes a FilterState, an int and a
      // FilterPriors. There is no parameter a Condition could arrive through.
      // Scanned rather than asserted, so that adding one is what fails.
      final offenders = <String>[];
      for (final file
          in Directory('lib/domain/predict')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        // The type name at a word boundary, and the import that would bring it
        // in. Not a bare substring match on "condition": the word appears in
        // ordinary prose — "conditional", "preconditions" — and a guard that
        // fails on a comment is a guard someone eventually deletes.
        if (RegExp(r'\bCondition\b').hasMatch(source) ||
            source.contains('models/condition.dart')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'The prediction model now mentions conditions. ADR-0010 says it '
            'must not: the shipped priors have no condition strata, so any '
            'condition-specific behaviour here is invented calibration '
            'presented as a measurement. If this is deliberate, it needs a new '
            'ADR and a refitted priors artifact, not a passing test.\n'
            '${offenders.join("\n")}',
      );
    });

    test('and the same logs predict the same thing either way', () async {
      // The behavioural half. Recording every non-suppressing condition at once
      // must leave the prediction bit-identical, not merely similar.
      await logHistory(<int>[27, 31, 28, 30, 26, 29]);
      final clean = await predictions.current();

      for (final condition in Condition.values) {
        if (condition.suppressesPrediction) continue;
        await conditions.add(
          condition: condition,
          start: clock.today().addDays(-200),
        );
      }

      expect(await predictions.current(), clean);
    });
  });
}
