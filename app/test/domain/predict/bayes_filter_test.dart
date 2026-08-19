import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

/// The population constants, unpersonalised. Tests that want to isolate the
/// filter use these directly so a grid refit cannot move the numbers underneath
/// them.
final FilterPriors priors = bundledPriors.filterPriors;

/// The same model with the robustness switched off.
///
/// The IRLS weight is `(nu + 1) / (nu + r^2)`, which tends to 1 as `nu` grows,
/// so a huge `nu` is exactly the Gaussian Kalman filter. Used as a
/// counterfactual: several of the claims below are only meaningful next to what
/// a non-robust port would have done.
final FilterPriors gaussianPriors = FilterPriors(
  logMeanCenter: priors.logMeanCenter,
  logMeanVar: priors.logMeanVar,
  obsVar: priors.obsVar,
  driftVar: priors.driftVar,
  studentTDf: 1000000000000,
  minObsVar: priors.minObsVar,
);

/// Posterior mean expressed back in days, which is easier to reason about.
double meanDays(FilterState state) => math.exp(state.mean);

FilterState stateAfter(List<int> lengths, [FilterPriors? p]) =>
    BayesFilter.filterSequence(lengths, p ?? priors).last;

void main() {
  group('initialState', () {
    test('is the population prior, with no observations folded in', () {
      final state = BayesFilter.initialState(priors);
      expect(state.mean, priors.logMeanCenter);
      expect(state.variance, priors.logMeanVar);
      expect(state.nObs, 0);
    });

    test('is a usable distribution, not a placeholder', () {
      // A brand new user must get something honest rather than an empty
      // screen, which is only possible because the prior is a real forecast.
      final fc = BayesFilter.forecast(BayesFilter.initialState(priors), priors);
      expect(meanDays(BayesFilter.initialState(priors)), closeTo(29, 0.001));
      expect(fc.variance, greaterThan(0));
      expect(fc.scale, closeTo(math.sqrt(fc.variance), 1e-15));
    });
  });

  group('update', () {
    test('rejects a non-positive cycle length rather than returning NaN', () {
      final state = BayesFilter.initialState(priors);
      expect(
        () => BayesFilter.update(state, 0, priors),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => BayesFilter.update(state, -3, priors),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('counts observations', () {
      var state = BayesFilter.initialState(priors);
      for (var i = 1; i <= 4; i++) {
        state = BayesFilter.update(state, 28, priors);
        expect(state.nObs, i);
      }
    });

    test('moves the level towards the observation', () {
      final higher = BayesFilter.update(
        BayesFilter.initialState(priors),
        34,
        priors,
      );
      final lower = BayesFilter.update(
        BayesFilter.initialState(priors),
        24,
        priors,
      );
      expect(meanDays(higher), greaterThan(29));
      expect(meanDays(lower), lessThan(29));
    });

    test('shrinks the posterior variance on an unsurprising observation', () {
      final before = BayesFilter.initialState(priors);
      final after = BayesFilter.update(before, 29, priors);
      expect(after.variance, lessThan(before.variance));
    });
  });

  group('filterSequence', () {
    test('returns the prior plus one state per observation', () {
      expect(BayesFilter.filterSequence(const [], priors), hasLength(1));
      expect(
        BayesFilter.filterSequence(const [28, 29, 30], priors),
        hasLength(4),
      );
    });

    test('leaves an empty history at the prior', () {
      expect(
        BayesFilter.filterSequence(const [], priors).single,
        BayesFilter.initialState(priors),
      );
    });

    test('is order sensitive, because the level drifts', () {
      final rising = stateAfter(const [26, 28, 30]);
      final falling = stateAfter(const [30, 28, 26]);
      expect(rising.mean, isNot(falling.mean));
      expect(meanDays(rising), greaterThan(meanDays(falling)));
    });
  });

  group('a perfectly regular history', () {
    test('collapses the posterior onto the observed length', () {
      // 28 exactly, from a prior centred on 29, and closer with every cycle.
      final six = stateAfter(List<int>.filled(6, 28));
      final fifty = stateAfter(List<int>.filled(50, 28));
      expect(meanDays(six), closeTo(28, 0.1));
      expect(meanDays(fifty), closeTo(28, 0.001));
      expect(
        (meanDays(fifty) - 28).abs(),
        lessThan((meanDays(six) - 28).abs()),
      );
      expect(fifty.variance, lessThan(six.variance));
    });

    test('narrows the forecast without ever collapsing it', () {
      // min_obs_var is what stops a run of identical cycles producing a
      // zero-width interval and a confidence the model has not earned.
      final widths = <double>[
        for (final n in <int>[1, 3, 6, 12, 50])
          BayesFilter.forecast(
            stateAfter(List<int>.filled(n, 28)),
            priors,
          ).scale,
      ];
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], lessThan(widths[i - 1]));
      }
      expect(widths.last, greaterThan(math.sqrt(priors.minObsVar)));
      expect(stateAfter(List<int>.filled(200, 28)).variance, greaterThan(0));
    });
  });

  group('a single outlier', () {
    // The whole reason for the Student-t observation model. A Gaussian port
    // passes every other test in this file and fails this group.
    final settled = List<int>.filled(6, 28);
    final withOutlier = <int>[...List<int>.filled(5, 28), 55];

    test('widens the posterior instead of dragging the mean', () {
      final normal = stateAfter(settled);
      final outlier = stateAfter(withOutlier);

      // A 55 day cycle is nearly twice the observed length, and it moves the
      // level by well under a day.
      expect((meanDays(outlier) - meanDays(normal)).abs(), lessThan(1));
      // What it does instead is stop the variance shrinking, which is the
      // model saying "I am less sure now", the honest response.
      expect(outlier.variance, greaterThan(normal.variance));
      expect(
        BayesFilter.forecast(outlier, priors).variance,
        greaterThan(BayesFilter.forecast(normal, priors).variance),
      );
    });

    test('a Gaussian observation model would do the opposite', () {
      final normal = stateAfter(settled, gaussianPriors);
      final outlier = stateAfter(withOutlier, gaussianPriors);

      // Six days of drag, from one mis-logged cycle.
      expect(meanDays(outlier) - meanDays(normal), greaterThan(5));
      // And not one bit less certain about it, because a Gaussian Kalman
      // gain does not depend on the residual at all.
      expect(outlier.variance, closeTo(normal.variance, 1e-12));
    });

    test('is down-weighted more the further out it is', () {
      final shifts = <double>[
        for (final length in <int>[30, 35, 45, 60, 90])
          (meanDays(stateAfter(<int>[...List<int>.filled(5, 28), length])) -
                  meanDays(stateAfter(settled)))
              .abs(),
      ];
      // The influence of an observation peaks and then falls away: a 90 day
      // reading moves the level less than a 35 day one does.
      expect(shifts.last, lessThan(shifts[1]));
    });
  });

  group('forecast', () {
    test('adds drift and observation noise to the level uncertainty', () {
      final state = stateAfter(const [28, 29, 28]);
      final fc = BayesFilter.forecast(state, priors);
      expect(fc.mean, state.mean);
      expect(fc.variance, state.variance + priors.driftVar + priors.obsVar);
      expect(fc.variance, greaterThan(state.variance));
    });
  });

  group('predictiveQuantile', () {
    test('is the mean shifted by the quantile in scale units', () {
      final fc = BayesFilter.forecast(stateAfter(const [28, 28, 28]), priors);
      final p50 = BayesFilter.predictiveQuantile(fc, 0);
      final p90 = BayesFilter.predictiveQuantile(
        fc,
        bundledPriors.quantiles[QuantileLevel.p90],
      );
      final p10 = BayesFilter.predictiveQuantile(
        fc,
        bundledPriors.quantiles[QuantileLevel.p10],
      );
      expect(p50, fc.mean);
      expect(p90, greaterThan(p50));
      expect(p10, lessThan(p50));
      // Symmetric, because the Student-t is.
      expect(p90 - p50, closeTo(p50 - p10, 1e-12));
    });
  });

  group('daysFromLog', () {
    test('converts a log-scale level back to whole days', () {
      expect(BayesFilter.daysFromLog(math.log(28)), 28);
      expect(BayesFilter.daysFromLog(math.log(1)), 1);
    });

    test('rounds to nearest, not towards zero', () {
      expect(BayesFilter.daysFromLog(math.log(28.4)), 28);
      expect(BayesFilter.daysFromLog(math.log(28.6)), 29);
      expect(BayesFilter.daysFromLog(math.log(27.51)), 28);
      // The exact half is `floor(x + 0.5)`, so it goes up. Pinned across the
      // two runtimes by the day counts in the golden vectors rather than here:
      // reaching an exact half through `exp` is not something a test can rely
      // on to the last bit.
    });
  });

  group('value types', () {
    test('states and forecasts compare by value', () {
      expect(
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3),
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3),
      );
      expect(
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3).hashCode,
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3).hashCode,
      );
      expect(
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3),
        isNot(const FilterState(mean: 1.5, variance: 0.2, nObs: 4)),
      );
      expect(
        const Forecast(mean: 1, variance: 0.25),
        const Forecast(mean: 1, variance: 0.25),
      );
      expect(const Forecast(mean: 1, variance: 0.25).scale, 0.5);
    });

    test('have readable toString output for failure messages', () {
      expect(
        const FilterState(mean: 1.5, variance: 0.2, nObs: 3).toString(),
        contains('nObs: 3'),
      );
      expect(
        const Forecast(mean: 1, variance: 4).toString(),
        contains('mean: 1'),
      );
    });
  });
}
