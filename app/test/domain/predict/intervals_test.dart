import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

final ConfidenceThresholds thresholds = bundledPriors.confidenceThresholds;

void main() {
  group('confidenceClass', () {
    test('is decided by the width of the 80% window alone', () {
      expect(Intervals.confidenceClass(1, thresholds), ConfidenceClass.high);
      expect(Intervals.confidenceClass(3, thresholds), ConfidenceClass.high);
      expect(Intervals.confidenceClass(4, thresholds), ConfidenceClass.medium);
      expect(Intervals.confidenceClass(7, thresholds), ConfidenceClass.medium);
      expect(Intervals.confidenceClass(8, thresholds), ConfidenceClass.low);
      expect(Intervals.confidenceClass(13, thresholds), ConfidenceClass.low);
      expect(
        Intervals.confidenceClass(14, thresholds),
        ConfidenceClass.tooIrregular,
      );
      expect(
        Intervals.confidenceClass(60, thresholds),
        ConfidenceClass.tooIrregular,
      );
    });

    test('reads the thresholds it is given rather than baking them in', () {
      const strict = ConfidenceThresholds(
        highBelowDays: 2,
        mediumBelowDays: 3,
        lowBelowDays: 4,
      );
      expect(Intervals.confidenceClass(3, strict), ConfidenceClass.low);
      expect(
        Intervals.confidenceClass(4, strict),
        ConfidenceClass.tooIrregular,
      );
    });
  });

  group('ConfidenceClass', () {
    test('maps to the app-facing Confidence, except when it must not', () {
      expect(ConfidenceClass.high.toConfidence(), Confidence.high);
      expect(ConfidenceClass.medium.toConfidence(), Confidence.medium);
      expect(ConfidenceClass.low.toConfidence(), Confidence.low);
      // Null is the point: at this width no window may be shown at all, so
      // there is nothing to label. The caller has to build a
      // PredictionResult.tooIrregular instead.
      expect(ConfidenceClass.tooIrregular.toConfidence(), isNull);
    });

    test('carries the wire names the golden vectors use', () {
      expect(ConfidenceClass.tooIrregular.wireName, 'too_irregular');
      expect(
        ConfidenceClass.values.map((c) => c.wireName).toSet(),
        <String>{'high', 'medium', 'low', 'too_irregular'},
      );
    });
  });

  group('windows', () {
    test('nest around the median for every history', () {
      for (final history in <List<int>>[
        <int>[],
        <int>[28],
        <int>[28, 29],
        List<int>.filled(6, 28),
        <int>[27, 29, 28, 30, 28, 29],
        <int>[24, 35, 28, 42, 31, 26],
        <int>[28, 29, 90, 28],
        <int>[15, 15, 16, 15],
        <int>[26, 27, 28, 29, 30, 31, 32, 33],
      ]) {
        final windows = Intervals.forHistory(history, bundledPriors).windows;
        expect(windows.isCoherent, isTrue, reason: '$history -> $windows');
        expect(windows.width50, lessThanOrEqualTo(windows.width80));
        expect(windows.width50, greaterThanOrEqualTo(1));
        expect(windows.lo80, greaterThan(0));
      }
    });

    test('count both ends, so a one day window has width one', () {
      const windows = PredictionWindows(
        medianDays: 28,
        lo50: 28,
        hi50: 28,
        lo80: 27,
        hi80: 29,
      );
      expect(windows.width50, 1);
      expect(windows.width80, 3);
      expect(windows.isCoherent, isTrue);
    });

    test('report incoherence rather than hiding it', () {
      const inverted = PredictionWindows(
        medianDays: 28,
        lo50: 29,
        hi50: 27,
        lo80: 26,
        hi80: 30,
      );
      expect(inverted.isCoherent, isFalse);
    });

    test('compare by value', () {
      const a = PredictionWindows(
        medianDays: 28,
        lo50: 27,
        hi50: 29,
        lo80: 26,
        hi80: 30,
      );
      const b = PredictionWindows(
        medianDays: 28,
        lo50: 27,
        hi50: 29,
        lo80: 26,
        hi80: 30,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('80%: 26..30'));
    });
  });

  group('windowsFromState', () {
    test('agrees with going through the forecast explicitly', () {
      final state = BayesFilter.filterSequence(
        const [28, 29, 28],
        bundledPriors.filterPriors,
      ).last;
      expect(
        Intervals.windowsFromState(
          state,
          bundledPriors.filterPriors,
          bundledPriors.quantiles,
        ),
        Intervals.windowsFromForecast(
          BayesFilter.forecast(state, bundledPriors.filterPriors),
          bundledPriors.quantiles,
        ),
      );
    });
  });

  group('forHistory', () {
    test('gives a brand new user an honest population prediction', () {
      final prediction = Intervals.forHistory(const [], bundledPriors);
      expect(prediction.refit.personalised, isFalse);
      expect(prediction.refit.nCycles, 0);
      expect(prediction.state.nObs, 0);
      expect(prediction.windows.medianDays, 29);
      expect(prediction.windows.isCoherent, isTrue);
      // Wide, and labelled as such. A confident-looking window here would be
      // the app inventing knowledge it does not have.
      expect(prediction.confidence, ConfidenceClass.low);
    });

    test('carries the state the prediction cache will key on', () {
      const history = <int>[27, 29, 28, 30, 28, 29];
      final prediction = Intervals.forHistory(history, bundledPriors);
      expect(
        prediction.state,
        BayesFilter.filterSequence(history, prediction.refit.priors).last,
      );
      expect(
        prediction.forecast,
        BayesFilter.forecast(prediction.state, prediction.refit.priors),
      );
    });

    test('propagates an edit, which is what cache invalidation relies on', () {
      const before = <int>[27, 29, 28, 30, 28, 29];
      const after = <int>[27, 29, 28, 30, 28, 34];
      expect(
        Intervals.forHistory(before, bundledPriors),
        isNot(Intervals.forHistory(after, bundledPriors)),
      );
    });

    test('personalise: false reproduces the pre-refit behaviour', () {
      const history = <int>[26, 34, 26, 34, 26, 34];
      final population = Intervals.forHistory(
        history,
        bundledPriors,
        personalise: false,
      );
      final personalised = Intervals.forHistory(history, bundledPriors);

      expect(population.refit.personalised, isFalse);
      expect(population.refit.priors, bundledPriors.filterPriors);
      expect(population.refit.score, double.negativeInfinity);
      expect(population.refit.nCycles, history.length);
      // The defect this switch exists to demonstrate: without the refit a very
      // variable user is handed a window as tight as a regular user's.
      expect(
        population.windows.width80,
        lessThan(personalised.windows.width80),
      );
    });

    test('is a pure function of its inputs', () {
      const history = <int>[28, 29, 27, 30, 28, 29];
      expect(
        Intervals.forHistory(history, bundledPriors),
        Intervals.forHistory(history, bundledPriors),
      );
      expect(
        Intervals.forHistory(history, bundledPriors).hashCode,
        Intervals.forHistory(history, bundledPriors).hashCode,
      );
      expect(
        Intervals.forHistory(history, bundledPriors).toString(),
        contains('personalised: true'),
      );
    });
  });
}
