import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

/// Locates a committed artifact from wherever the test happens to be run.
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
    'could not find $relativePath from ${Directory.current.path}',
  );
}

/// A valid priors document, as a mutable tree the failure tests can damage.
Map<String, Object?> validDocument() =>
    jsonDecode(
          findArtifact('artifacts/priors/priors_v1.json').readAsStringSync(),
        )!
        as Map<String, Object?>;

PriorsLoadFailure failureFrom(Map<String, Object?> document) {
  final result = ModelPriors.fromJson(document);
  expect(result.isErr, isTrue, reason: 'expected $document to be refused');
  return result.errorOrNull!;
}

void main() {
  final artifact = findArtifact('artifacts/priors/priors_v1.json');

  group('the generated constants and the artifact', () {
    // This pair of tests is the checksum guard AND-07 asks for. Regenerating
    // the priors without re-running tools/scripts/gen_priors_dart.py fails
    // here, rather than silently shipping an app whose model no longer matches
    // the artifact the golden vectors were built from (ADR-0002).
    test('agree, field for field', () {
      final parsed = ModelPriors.parse(artifact.readAsStringSync());
      expect(parsed.isOk, isTrue, reason: '${parsed.errorOrNull}');
      expect(parsed.valueOrNull, bundledPriors);
    });

    test('agree on the recorded SHA-256', () {
      expect(
        sha256.convert(artifact.readAsBytesSync()).toString(),
        priorsArtifactSha256,
        reason:
            'artifacts/priors/priors_v1.json has changed. Run '
            '`python3 tools/scripts/gen_priors_dart.py` and commit the result.',
      );
    });
  });

  group('the shipped values', () {
    test('are the ones the model documentation describes', () {
      expect(bundledPriors.schemaVersion, 1);
      expect(bundledPriors.filterPriors.studentTDf, 4);
      expect(bundledPriors.quantiles.df, bundledPriors.filterPriors.studentTDf);
      expect(bundledPriors.personalisation.minCycles, 5);
      expect(bundledPriors.confidenceThresholds.highBelowDays, 4);
      expect(bundledPriors.confidenceThresholds.mediumBelowDays, 8);
      expect(bundledPriors.confidenceThresholds.lowBelowDays, 14);
    });

    test('centre the prior near a 29 day cycle', () {
      expect(bundledPriors.filterPriors.logMeanCenter, closeTo(3.3673, 1e-4));
      expect(bundledPriors.filterPriors.minObsVar, greaterThan(0));
    });

    test('put the tightest grid point at the observation variance floor', () {
      // Not a coincidence worth breaking: the smallest obs_sd the search can
      // choose squares to exactly min_obs_var, so personalisation cannot ask
      // for a tighter interval than the floor already allows.
      final smallest = bundledPriors.personalisation.obsSdGrid.first;
      expect(
        smallest * smallest,
        closeTo(bundledPriors.filterPriors.minObsVar, 1e-15),
      );
    });

    test('list both grids in increasing order', () {
      for (final grid in <List<double>>[
        bundledPriors.personalisation.obsSdGrid,
        bundledPriors.personalisation.driftSdGrid,
      ]) {
        for (var i = 1; i < grid.length; i++) {
          expect(grid[i], greaterThan(grid[i - 1]));
        }
      }
    });
  });

  group('QuantileTable', () {
    test('looks up every level', () {
      final quantiles = bundledPriors.quantiles;
      expect(quantiles[QuantileLevel.p50], 0);
      // Symmetric to within a bit, but not exactly: SciPy computes each tail
      // separately offline, so p10 and -p90 differ in the last place. That is
      // why the table ships both rather than the port negating one to get the
      // other, and why the golden comparison is a tolerance rather than
      // equality.
      expect(
        quantiles[QuantileLevel.p10],
        closeTo(-quantiles[QuantileLevel.p90], 1e-15),
      );
      expect(quantiles[QuantileLevel.p25], -quantiles[QuantileLevel.p75]);
      expect(
        quantiles[QuantileLevel.p90],
        greaterThan(quantiles[QuantileLevel.p75]),
      );
    });

    test('uses the wire names the artifacts use', () {
      expect(
        QuantileLevel.values.map((l) => l.wireName).toList(),
        <String>['p10', 'p25', 'p50', 'p75', 'p90'],
      );
    });
  });

  group('loading refuses', () {
    // The headline requirement: an unknown schema version is refused, never
    // read hopefully. Fields can change meaning between versions, and a
    // plausible-looking wrong prediction is worse than a visible failure
    // (docs/PLAN.md 5.3).
    test('an unknown schema version', () {
      final failure = failureFrom(validDocument()..['schema_version'] = 2);
      expect(failure.error, PriorsLoadError.unsupportedSchemaVersion);
      expect(failure.field, 'schema_version');
      expect(failure.message, contains('2'));
    });

    test('a schema version of the wrong type', () {
      final failure = failureFrom(validDocument()..['schema_version'] = '1');
      expect(failure.error, PriorsLoadError.wrongType);
    });

    test('a missing section', () {
      final failure = failureFrom(validDocument()..remove('filter_priors'));
      expect(failure.error, PriorsLoadError.missingField);
      expect(failure.field, 'filter_priors');
    });

    test('a missing scalar', () {
      final document = validDocument();
      (document['filter_priors']! as Map<String, Object?>).remove('obs_var');
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.missingField);
      expect(failure.field, 'obs_var');
    });

    test('a non-positive variance', () {
      final document = validDocument();
      (document['filter_priors']! as Map<String, Object?>)['drift_var'] = 0;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 'drift_var');
    });

    test('a quantile table computed for the wrong degrees of freedom', () {
      // The nastiest silent failure available: every interval would be
      // mis-scaled and nothing else would look wrong.
      final document = validDocument();
      (document['t_quantiles']! as Map<String, Object?>)['df'] = 7;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 't_quantiles.df');
    });

    test('quantiles that do not increase', () {
      final document = validDocument();
      final values =
          (document['t_quantiles']! as Map<String, Object?>)['values']!
              as Map<String, Object?>;
      values['p90'] = -2;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 't_quantiles.values');
    });

    test('an empty search grid', () {
      final document = validDocument();
      (document['personalisation']! as Map<String, Object?>)['obs_sd_grid'] =
          <Object?>[];
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 'obs_sd_grid');
    });

    test('a grid entry that is not a positive number', () {
      final document = validDocument();
      (document['personalisation']! as Map<String, Object?>)['drift_sd_grid'] =
          <Object?>[0.01, -0.02];
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 'drift_sd_grid[1]');
    });

    test('a minimum history of zero cycles', () {
      final document = validDocument();
      (document['personalisation']! as Map<String, Object?>)['min_cycles'] = 0;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 'personalisation.min_cycles');
    });

    test('confidence thresholds that do not increase', () {
      final document = validDocument();
      (document['confidence_thresholds_days']!
              as Map<String, Object?>)['medium_below'] =
          3;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.field, 'confidence_thresholds_days');
    });

    test('a section that is not an object', () {
      final failure = failureFrom(validDocument()..['filter_priors'] = 5);
      expect(failure.error, PriorsLoadError.wrongType);
      expect(failure.field, 'filter_priors');
      expect(failure.message, contains('expected an object'));
    });

    test('a scalar that is not a number', () {
      final document = validDocument();
      (document['filter_priors']! as Map<String, Object?>)['obs_var'] = 'wide';
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.wrongType);
      expect(failure.message, contains('expected a number'));
    });

    test('a value that is not finite', () {
      // Not reachable through jsonDecode, which has no way to spell infinity,
      // but fromJson is public and a future asset pipeline could hand it one.
      final document = validDocument();
      (document['filter_priors']! as Map<String, Object?>)['log_mean_center'] =
          double.infinity;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.invalidValue);
      expect(failure.message, contains('finite'));
    });

    test('a grid that is not an array', () {
      final document = validDocument();
      (document['personalisation']! as Map<String, Object?>)['obs_sd_grid'] =
          0.02;
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.wrongType);
      expect(failure.message, contains('expected an array'));
    });

    test('a grid entry that is not a number', () {
      final document = validDocument();
      (document['personalisation']! as Map<String, Object?>)['drift_sd_grid'] =
          <Object?>[0.01, 'wide'];
      final failure = failureFrom(document);
      expect(failure.error, PriorsLoadError.wrongType);
      expect(failure.field, 'drift_sd_grid[1]');
    });

    test('text that is not JSON at all', () {
      final result = ModelPriors.parse('not json');
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.error, PriorsLoadError.malformedJson);
    });

    test('JSON that is not an object', () {
      final result = ModelPriors.parse('[1, 2, 3]');
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.error, PriorsLoadError.wrongType);
      expect(result.errorOrNull!.field, '<root>');
    });
  });

  group('value semantics', () {
    test('priors compare by value all the way down', () {
      final parsed = ModelPriors.parse(artifact.readAsStringSync())
          .valueOrNull!;
      expect(parsed, bundledPriors);
      expect(parsed.hashCode, bundledPriors.hashCode);
      expect(parsed.filterPriors, bundledPriors.filterPriors);
      expect(parsed.quantiles, bundledPriors.quantiles);
      expect(parsed.personalisation, bundledPriors.personalisation);
      expect(parsed.confidenceThresholds, bundledPriors.confidenceThresholds);
    });

    test('withVariances changes only the two per-user variances', () {
      final base = bundledPriors.filterPriors;
      final tuned = base.withVariances(obsVar: 0.01, driftVar: 0.002);
      expect(tuned.obsVar, 0.01);
      expect(tuned.driftVar, 0.002);
      expect(tuned.logMeanCenter, base.logMeanCenter);
      expect(tuned.logMeanVar, base.logMeanVar);
      expect(tuned.studentTDf, base.studentTDf);
      expect(tuned.minObsVar, base.minObsVar);
      expect(tuned, isNot(base));
      expect(
        base.withVariances(obsVar: base.obsVar, driftVar: base.driftVar),
        base,
      );
    });

    test('failures compare by value and describe themselves', () {
      const failure = PriorsLoadFailure(
        PriorsLoadError.missingField,
        'obs_var',
        'required field is absent',
      );
      expect(
        failure,
        const PriorsLoadFailure(
          PriorsLoadError.missingField,
          'obs_var',
          'required field is absent',
        ),
      );
      expect(failure.hashCode, isNotNull);
      expect(failure.toString(), contains('missingField'));
      expect(failure.toString(), contains('obs_var'));
    });

    test('types print enough to debug a failing expectation', () {
      expect(bundledPriors.toString(), contains('schemaVersion: 1'));
      expect(bundledPriors.filterPriors.toString(), contains('obsVar'));
      expect(bundledPriors.quantiles.toString(), contains('p50'));
      expect(
        bundledPriors.personalisation.toString(),
        contains('minCycles: 5'),
      );
      expect(
        bundledPriors.confidenceThresholds.toString(),
        contains('lowBelowDays: 14'),
      );
    });
  });
}
