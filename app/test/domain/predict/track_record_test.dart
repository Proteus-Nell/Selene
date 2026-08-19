import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';
import 'package:period_tracker/domain/predict/track_record.dart';

TrackRecord? evaluate(List<int> lengths, {int recent = 5, int tolerance = 2}) =>
    SelfMetrics.evaluate(
      lengths,
      bundledPriors,
      recent: recent,
      toleranceDays: tolerance,
    );

void main() {
  group('with too little history', () {
    test('says nothing rather than inventing a score', () {
      // Scoring one or two cycles would report on the population prior, which
      // is not what the user is asking about.
      expect(evaluate(const <int>[]), isNull);
      expect(evaluate(const <int>[28]), isNull);
      expect(evaluate(const <int>[28, 28]), isNull);
      expect(evaluate(const <int>[28, 28, 28]), isNotNull);
    });
  });

  group('on a regular history', () {
    test('reports a good score honestly', () {
      final record = evaluate(List<int>.filled(10, 28))!;
      expect(record.predictions, 5);
      expect(record.withinTolerance, 5);
      expect(record.meanAbsoluteErrorDays, lessThan(1));
    });
  });

  group('on a variable history', () {
    test('reports a worse one, rather than flattering the model', () {
      // The counterweight to overclaiming only works if the number is allowed
      // to be bad (docs/PLAN.md 2.4.5).
      final regular = evaluate(List<int>.filled(10, 28))!;
      final variable = evaluate(const <int>[
        26,
        34,
        26,
        34,
        26,
        34,
        26,
        34,
        26,
        34,
      ])!;
      expect(
        variable.meanAbsoluteErrorDays,
        greaterThan(regular.meanAbsoluteErrorDays),
      );
      expect(variable.withinTolerance, lessThan(variable.predictions));
    });
  });

  group('the scoring', () {
    test(
      'is out of sample: each cycle is predicted from the ones before it',
      () {
        // If it scored in sample, appending a wildly different cycle would not
        // change the error on the cycles before it, and the last score would be
        // suspiciously good.
        final before = evaluate(const <int>[28, 28, 28, 28, 28, 28])!;
        final after = evaluate(const <int>[28, 28, 28, 28, 28, 28, 55])!;
        expect(
          after.meanAbsoluteErrorDays,
          greaterThan(before.meanAbsoluteErrorDays),
        );
      },
    );

    test('covers only the most recent predictions', () {
      // A rocky start should not follow the user around for ever.
      final record = evaluate(
        <int>[55, 20, 40, ...List<int>.filled(8, 28)],
        recent: 3,
      )!;
      expect(record.predictions, 3);
      expect(record.withinTolerance, 3);
    });

    test('honours the tolerance it is asked about', () {
      const lengths = <int>[28, 31, 28, 31, 28, 31, 28, 31];
      final strict = evaluate(lengths, tolerance: 0)!;
      final loose = evaluate(lengths, tolerance: 5)!;
      expect(
        loose.withinTolerance,
        greaterThanOrEqualTo(strict.withinTolerance),
      );
      expect(loose.toleranceDays, 5);
    });

    test('is deterministic', () {
      const lengths = <int>[27, 29, 28, 30, 28, 29, 28];
      expect(evaluate(lengths), evaluate(lengths));
      expect(evaluate(lengths).hashCode, evaluate(lengths).hashCode);
    });
  });

  group('TrackRecord', () {
    test('describes itself for a failure message', () {
      final record = evaluate(List<int>.filled(10, 28))!;
      expect(record.toString(), contains('within'));
      expect(record, isNot(evaluate(const <int>[26, 34, 26, 34, 26, 34])));
    });
  });
}
