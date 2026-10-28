// Cross-runtime conformance for windows moved forward once a period is late
// (DECISIONS.md ADR-0002, ADR-0016).
//
// `research/src/cyclecore/models/student_t.py` and `conditioned_windows` in
// `intervals.py` are the reference; `student_t.dart` and
// `Intervals.conditionedWindows` are the port. This replays
// `artifacts/golden/conditioned_cases_v1.json`: the distribution function and
// its inverse at fixed points, to the tolerance the artifact declares, and the
// moved windows for real histories, to the day.
//
// As with the other golden test, a failure here means the port is wrong.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';
import 'package:period_tracker/domain/predict/student_t.dart';

/// The artifact, found by walking up from the working directory, so the test
/// runs from `app/` and from the repository root alike.
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
    'could not find $relativePath from ${Directory.current.path}. Run '
    '`uv run cyclecore export-golden` in research/.',
  );
}

double doubleAt(Map<String, Object?> json, String key) =>
    (json[key]! as num).toDouble();

int intAt(Map<String, Object?> json, String key) => json[key]! as int;

Map<String, Object?> objectAt(Map<String, Object?> json, String key) =>
    json[key]! as Map<String, Object?>;

List<Map<String, Object?>> objectsAt(Map<String, Object?> json, String key) =>
    (json[key]! as List<Object?>).cast<Map<String, Object?>>();

void main() {
  final golden =
      jsonDecode(
            findArtifact(
              'artifacts/golden/conditioned_cases_v1.json',
            ).readAsStringSync(),
          )!
          as Map<String, Object?>;
  final tolerance = doubleAt(golden, 'float_tolerance');
  final df = doubleAt(golden, 'student_t_df');

  group('conditioned artifact', () {
    test('is the schema version this build understands', () {
      expect(intAt(golden, 'schema_version'), 1);
      expect(tolerance, 1e-9);
    });

    test('was built with the degrees of freedom the app ships', () {
      expect(df, bundledPriors.filterPriors.studentTDf);
    });

    test('covers days on both sides of a window opening', () {
      final cases = objectsAt(golden, 'cases');
      expect(cases.length, greaterThanOrEqualTo(25));
      final names = cases.map((c) => c['name']! as String).toSet();
      expect(names, hasLength(cases.length), reason: 'names are unique');
    });
  });

  group('the distribution function', () {
    for (final point in objectsAt(golden, 'cdf')) {
      final t = doubleAt(point, 't');
      test('at t = $t', () {
        expect(StudentT.cdf(t, df), closeTo(doubleAt(point, 'p'), tolerance));
      });
    }
  });

  group('its inverse', () {
    for (final point in objectsAt(golden, 'ppf')) {
      final p = doubleAt(point, 'p');
      test('at p = $p', () {
        expect(StudentT.ppf(p, df), closeTo(doubleAt(point, 't'), tolerance));
      });
    }

    test('refuses a level outside the open interval', () {
      expect(() => StudentT.ppf(0, df), throwsArgumentError);
      expect(() => StudentT.ppf(1, df), throwsArgumentError);
    });
  });

  for (final testCase in objectsAt(golden, 'cases')) {
    final name = testCase['name']! as String;
    test('conditioned case $name', () {
      final expected = objectAt(testCase, 'forecast');
      final fc = Forecast(
        mean: doubleAt(expected, 'mean'),
        variance: doubleAt(expected, 'var'),
      );
      final elapsed = intAt(testCase, 'elapsed_days');
      expect(
        StudentT.cdf((math.log(elapsed - 0.5) - fc.mean) / fc.scale, df),
        closeTo(doubleAt(testCase, 'below'), tolerance),
      );
      final windows = Intervals.conditionedWindows(fc, elapsed, df)!;
      final days = objectAt(testCase, 'day_windows');
      // Days exactly: `floor(x + 0.5)` is integer-valued, so a disagreement
      // is a real bug rather than float noise.
      expect(windows.medianDays, intAt(days, 'median'));
      expect(windows.lo50, intAt(days, 'lo50'));
      expect(windows.hi50, intAt(days, 'hi50'));
      expect(windows.lo80, intAt(days, 'lo80'));
      expect(windows.hi80, intAt(days, 'hi80'));
      expect(windows.isCoherent, isTrue);
      expect(windows.lo80, greaterThanOrEqualTo(elapsed));
    });
  }

  test('a day before the cycle started is refused', () {
    const fc = Forecast(mean: 3.33, variance: 0.0005);
    expect(() => Intervals.conditionedWindows(fc, 0, df), throwsArgumentError);
  });

  test('no window is drawn from no probability', () {
    // Only a forecast far narrower than the model ever produces gets here.
    const fc = Forecast(mean: 3.33, variance: 1e-12);
    expect(Intervals.conditionedWindows(fc, 60, df), isNull);
  });
}
