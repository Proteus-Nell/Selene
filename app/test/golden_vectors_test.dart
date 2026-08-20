// Cross-runtime conformance test (DECISIONS.md ADR-0002).
//
// `research/src/cyclecore/models/bayes_filter.py` is the reference and
// `app/lib/domain/predict/` is the port. This test replays every case in
// `artifacts/golden/predictor_cases_v1.json` through the Dart implementation
// and asserts it reproduces the Python output: floats to the tolerance the
// artifact itself declares, day counts and confidence classes exactly.
//
// If this fails, the port is wrong. That is the standing rule, and it is worth
// restating here because the temptation when a golden test fails is to widen
// the tolerance.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/personalize.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

/// The golden artifact, found by walking up from the working directory.
///
/// `flutter test` runs from `app/`, but the same file is reachable from the
/// repository root, and a test that only works from one of them is a trap for
/// whoever next runs it from an IDE.
File findArtifact(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'could not find $relativePath from ${Directory.current.path}. The golden '
    'vectors are produced by the Python task PY-A: run '
    '`uv run cyclecore export-golden` in research/.',
  );
}

Map<String, Object?> readJsonObject(File file) =>
    jsonDecode(file.readAsStringSync())! as Map<String, Object?>;

Map<String, Object?> objectAt(Map<String, Object?> json, String key) =>
    json[key]! as Map<String, Object?>;

List<Object?> listAt(Map<String, Object?> json, String key) =>
    json[key]! as List<Object?>;

double doubleAt(Map<String, Object?> json, String key) =>
    (json[key]! as num).toDouble();

int intAt(Map<String, Object?> json, String key) => json[key]! as int;

String stringAt(Map<String, Object?> json, String key) => json[key]! as String;

List<int> intsAt(Map<String, Object?> json, String key) =>
    listAt(json, key).map((v) => v! as int).toList();

List<double> doublesAt(Map<String, Object?> json, String key) =>
    listAt(json, key).map((v) => (v! as num).toDouble()).toList();

void main() {
  final golden = readJsonObject(
    findArtifact('artifacts/golden/predictor_cases_v1.json'),
  );
  final tolerance = doubleAt(golden, 'float_tolerance');
  final cases = listAt(golden, 'cases').cast<Map<String, Object?>>();

  group('golden artifact', () {
    test('is a schema version this build understands', () {
      expect(intAt(golden, 'schema_version'), 1);
      expect(
        ModelPriors.supportedSchemaVersions,
        contains(intAt(golden, 'schema_version')),
      );
    });

    test('declares the 1e-9 tolerance the contract specifies', () {
      expect(tolerance, 1e-9);
    });

    test('covers the edge cases ADR-0002 requires', () {
      final names = cases.map((c) => stringAt(c, 'name')).toList();
      expect(names, contains('cold_start_no_cycles'));
      expect(names, contains('single_cycle_28'));
      expect(names, contains('single_outlier_late'));
      expect(names, contains('merged_cycle_from_missed_log'));
      expect(names, contains('edited_history_one_value_changed'));
      expect(names, contains('irregular_history'));
      // The 90 day gap case is the merged cycle; assert the value itself so a
      // rename cannot quietly drop the coverage.
      final merged = cases.firstWhere(
        (c) => stringAt(c, 'name') == 'merged_cycle_from_missed_log',
      );
      expect(intsAt(merged, 'cycle_lengths'), contains(90));
      expect(names, hasLength(cases.length));
      expect(
        names.toSet(),
        hasLength(names.length),
        reason: 'names are unique',
      );
    });
  });

  // The port has to run the same constants the reference ran, or every case
  // below would be comparing two different models. Regenerating priors_v1.json
  // without regenerating the golden vectors fails here.
  group('bundled priors match the ones the reference used', () {
    final used = objectAt(golden, 'priors_used');
    final priors = bundledPriors.filterPriors;

    test('filter priors', () {
      expect(priors.logMeanCenter, doubleAt(used, 'log_mean_center'));
      expect(priors.logMeanVar, doubleAt(used, 'log_mean_var'));
      expect(priors.obsVar, doubleAt(used, 'obs_var'));
      expect(priors.driftVar, doubleAt(used, 'drift_var'));
      expect(priors.studentTDf, doubleAt(used, 'student_t_df'));
      expect(priors.minObsVar, doubleAt(used, 'min_obs_var'));
    });

    test('quantile table', () {
      final quantiles = objectAt(golden, 't_quantiles');
      for (final level in QuantileLevel.values) {
        expect(
          bundledPriors.quantiles[level],
          doubleAt(quantiles, level.wireName),
          reason: level.wireName,
        );
      }
    });

    test('personalisation grid', () {
      final personalisation = objectAt(golden, 'personalisation');
      expect(
        bundledPriors.personalisation.minCycles,
        intAt(personalisation, 'min_cycles'),
      );
      expect(
        bundledPriors.personalisation.obsSdGrid,
        doublesAt(personalisation, 'obs_sd_grid'),
      );
      expect(
        bundledPriors.personalisation.driftSdGrid,
        doublesAt(personalisation, 'drift_sd_grid'),
      );
    });
  });

  for (final testCase in cases) {
    final name = stringAt(testCase, 'name');
    final lengths = intsAt(testCase, 'cycle_lengths');

    group('golden case $name', () {
      // Carried into the artifact by the exporter so a future reader knows what
      // a case defends against before deleting it. Printed on failure.
      final why = stringAt(testCase, 'why');

      final refit = Personalize.refitUser(
        lengths,
        bundledPriors.filterPriors,
        bundledPriors.personalisation,
      );
      final states = BayesFilter.filterSequence(lengths, refit.priors);
      final forecast = BayesFilter.forecast(states.last, refit.priors);

      test('refit selects the same grid point', () {
        final expected = objectAt(testCase, 'refit');
        expect(refit.personalised, expected['personalised'], reason: why);
        expect(refit.nCycles, intAt(expected, 'n_cycles'), reason: why);
        expect(
          refit.obsSd,
          closeTo(doubleAt(expected, 'obs_sd'), tolerance),
          reason: why,
        );
        expect(
          refit.driftSd,
          closeTo(doubleAt(expected, 'drift_sd'), tolerance),
          reason: why,
        );
      });

      test('every intermediate state matches', () {
        final expected = listAt(
          testCase,
          'states',
        ).cast<Map<String, Object?>>();
        expect(states, hasLength(expected.length), reason: why);
        for (var i = 0; i < expected.length; i++) {
          expect(
            states[i].nObs,
            intAt(expected[i], 'n_obs'),
            reason: '$why (state $i)',
          );
          expect(
            states[i].mean,
            closeTo(doubleAt(expected[i], 'mean'), tolerance),
            reason: '$why (state $i mean)',
          );
          expect(
            states[i].variance,
            closeTo(doubleAt(expected[i], 'var'), tolerance),
            reason: '$why (state $i var)',
          );
        }
      });

      test('forecast matches', () {
        final expected = objectAt(testCase, 'forecast');
        expect(
          forecast.mean,
          closeTo(doubleAt(expected, 'mean'), tolerance),
          reason: why,
        );
        expect(
          forecast.variance,
          closeTo(doubleAt(expected, 'var'), tolerance),
          reason: why,
        );
        expect(
          forecast.scale,
          closeTo(doubleAt(expected, 'scale'), tolerance),
          reason: why,
        );
      });

      test('log-scale quantiles match', () {
        final expected = objectAt(testCase, 'log_quantiles');
        for (final level in QuantileLevel.values) {
          expect(
            BayesFilter.predictiveQuantile(
              forecast,
              bundledPriors.quantiles[level],
            ),
            closeTo(doubleAt(expected, level.wireName), tolerance),
            reason: '$why (${level.wireName})',
          );
        }
      });

      // Day counts are compared exactly, not to a tolerance. `floor(x + 0.5)`
      // is integer-valued, so any disagreement here is a real rounding-mode bug
      // rather than float noise.
      test('day windows match exactly', () {
        final expected = objectAt(testCase, 'day_windows');
        final windows = Intervals.windowsFromForecast(
          forecast,
          bundledPriors.quantiles,
        );
        expect(windows.medianDays, intAt(expected, 'median'), reason: why);
        expect(windows.lo50, intAt(expected, 'lo50'), reason: why);
        expect(windows.hi50, intAt(expected, 'hi50'), reason: why);
        expect(windows.lo80, intAt(expected, 'lo80'), reason: why);
        expect(windows.hi80, intAt(expected, 'hi80'), reason: why);
        expect(windows.width50, intAt(expected, 'width50'), reason: why);
        expect(windows.width80, intAt(expected, 'width80'), reason: why);
        expect(windows.isCoherent, isTrue, reason: why);
      });

      test('confidence class matches', () {
        final windows = Intervals.windowsFromForecast(
          forecast,
          bundledPriors.quantiles,
        );
        final confidence = Intervals.confidenceClass(
          windows.width80,
          bundledPriors.confidenceThresholds,
        );
        expect(
          confidence.wireName,
          stringAt(testCase, 'confidence'),
          reason: why,
        );
      });

      // The pipeline entry point the app actually calls must agree with the
      // step-by-step path asserted above. Without this, `forHistory` could
      // refit or order its steps differently and every other test would still
      // pass.
      test('Intervals.forHistory reproduces the same result end to end', () {
        final prediction = Intervals.forHistory(lengths, bundledPriors);
        final expectedWindows = objectAt(testCase, 'day_windows');
        expect(
          prediction.windows.medianDays,
          intAt(expectedWindows, 'median'),
          reason: why,
        );
        expect(
          prediction.windows.lo80,
          intAt(expectedWindows, 'lo80'),
          reason: why,
        );
        expect(
          prediction.windows.hi80,
          intAt(expectedWindows, 'hi80'),
          reason: why,
        );
        expect(
          prediction.confidence.wireName,
          stringAt(testCase, 'confidence'),
          reason: why,
        );
        expect(prediction.state, states.last, reason: why);
        expect(prediction.refit.obsSd, refit.obsSd, reason: why);
        expect(prediction.refit.driftSd, refit.driftSd, reason: why);
      });
    });
  }
}
