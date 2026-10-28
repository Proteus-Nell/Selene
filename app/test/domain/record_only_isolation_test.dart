// Temperature, cervical mucus and progesterone are recorded only (ADR-0020).
//
// They are fertility signs, which is exactly why they are kept away from the
// model. Read together, a temperature shift, egg-white mucus and a positive
// PdG strip are how fertility-awareness methods place ovulation, and the
// shortest path from there to a "fertile window" is one well-meaning line in
// the prediction code. Assumption A5 forbids this app from presenting one.
//
// So the guarantee has the same two halves as intercourse's:
//
//   * structural: the prediction and cycle layers cannot name the types or the
//     fields, which holds for code not written yet;
//   * behavioural: a history with every measurement recorded on every day
//     predicts exactly what the same history without them predicts.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Every Dart file under [directory].
List<File> _dartFilesIn(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

/// Every name that would let code read a measurement.
final List<RegExp> _names = <RegExp>[
  for (final name in <String>[
    'CervicalMucus',
    'PdgStripResult',
    'ProgesteroneUnit',
    'basalTemperatureCelsius',
    'cervicalMucus',
    'pdgStrip',
    'progesteroneValue',
    'progesteroneUnit',
    'hasMeasurements',
  ])
    RegExp('\\b$name\\b'),
];

List<String> _offendersIn(String directory) => <String>[
  for (final file in _dartFilesIn(directory))
    if (_names.any((name) => name.hasMatch(file.readAsStringSync()))) file.path,
];

void main() {
  test('the prediction layer cannot name a measurement', () {
    final offenders = _offendersIn('lib/domain/predict');
    expect(
      offenders,
      isEmpty,
      reason:
          'The prediction model now mentions a recorded-only measurement. '
          'These are fertility signs, and assumption A5 forbids this app from '
          'presenting a fertile window or a safe day. If this is deliberate it '
          'needs a new ADR and a rewritten A5, not a passing test.\n'
          '${offenders.join("\n")}',
    );
  });

  test('neither can the cycle code, which places the phases', () {
    // Segmentation feeds the filter, and the phases on the calendar and the
    // opt-in ovulation estimate live here too. An estimate refined by a
    // temperature shift is the fertile window by another name.
    final offenders = _offendersIn('lib/domain/cycles');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test(
    'a history with every measurement predicts what it would without',
    () async {
      final clock = FixedClock.iso('2026-06-30');
      Future<String> predictionFor({required bool measured}) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final cycles = CycleRepository(database: db, clock: clock);
        var start = clock.today().addDays(-6 * 29 - 3);
        final logs = <DayLog>[];
        for (var cycle = 0; cycle < 7; cycle++) {
          for (var day = 0; day < 29 && logs.length < 6 * 29 + 4; day++) {
            final date = start.addDays(day);
            if (date > clock.today()) break;
            final bleeding = day < 4;
            final base = DayLog(
              date: date,
              flow: bleeding ? FlowIntensity.medium : FlowIntensity.none,
            );
            if (measured) {
              logs.add(
                base.copyWith(
                  basalTemperatureCelsius: day > 14 ? 36.9 : 36.4,
                  cervicalMucus: day == 13
                      ? CervicalMucus.eggWhite
                      : CervicalMucus.sticky,
                  pdgStrip: day > 18
                      ? PdgStripResult.positive
                      : PdgStripResult.negative,
                  progesteroneValue: day == 21 ? 15.2 : null,
                  progesteroneUnit: day == 21 ? ProgesteroneUnit.ngPerMl : null,
                ),
              );
            } else if (bleeding) {
              logs.add(base);
            }
          }
          start = start.addDays(29);
        }
        await db.dayLogDao.saveAll(logs);
        final result = await PredictionRepository(
          database: db,
          cycles: cycles,
        ).current();
        return result.toString();
      }

      final without = await predictionFor(measured: false);
      final withEvery = await predictionFor(measured: true);
      expect(withEvery, without);
      expect(without, contains('Prediction('));
    },
  );

  test('a day with only a measurement is kept, not deleted as empty', () {
    // Otherwise the editor would accept the entry and then discard it on
    // write, which the user would see as the app forgetting what they told it.
    final day = DayLog(date: CivilDate.parseIso8601('2026-06-01'));
    expect(day.isEmpty, isTrue);
    expect(day.copyWith(basalTemperatureCelsius: 36.5).isEmpty, isFalse);
    expect(day.copyWith(cervicalMucus: CervicalMucus.dry).isEmpty, isFalse);
    expect(day.copyWith(pdgStrip: PdgStripResult.negative).isEmpty, isFalse);
    expect(
      day
          .copyWith(
            progesteroneValue: 1,
            progesteroneUnit: ProgesteroneUnit.nmolPerL,
          )
          .isEmpty,
      isFalse,
    );
  });

  test('a blood test value cannot be made without its unit', () {
    expect(
      () => DayLog(
        date: CivilDate.parseIso8601('2026-06-01'),
        progesteroneValue: 12,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
