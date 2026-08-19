import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// Posterior over the log-length level after some number of observations.
///
/// Mirrors `FilterState` in `research/src/cyclecore/models/bayes_filter.py`.
/// The field is called [variance] rather than `var` only because `var` is a
/// Dart keyword; it is the same quantity.
@immutable
final class FilterState {
  /// Creates a state with [mean] and [variance] after [nObs] observations.
  const FilterState({
    required this.mean,
    required this.variance,
    required this.nObs,
  });

  /// Posterior mean of the level, on the log scale.
  final double mean;

  /// Posterior variance of the level, on the log scale.
  final double variance;

  /// How many cycle lengths have been folded in.
  final int nObs;

  @override
  bool operator ==(Object other) =>
      other is FilterState &&
      other.mean == mean &&
      other.variance == variance &&
      other.nObs == nObs;

  @override
  int get hashCode => Object.hash(mean, variance, nObs);

  @override
  String toString() =>
      'FilterState(mean: $mean, variance: $variance, nObs: $nObs)';
}

/// One-step-ahead predictive distribution for the next log cycle length.
@immutable
final class Forecast {
  /// Creates a forecast with predictive [mean] and [variance].
  const Forecast({required this.mean, required this.variance});

  /// Predictive mean on the log scale.
  final double mean;

  /// Predictive variance on the log scale, including drift and observation
  /// noise.
  final double variance;

  /// Predictive standard deviation on the log scale.
  double get scale => math.sqrt(variance);

  @override
  bool operator ==(Object other) =>
      other is Forecast && other.mean == mean && other.variance == variance;

  @override
  int get hashCode => Object.hash(mean, variance);

  @override
  String toString() => 'Forecast(mean: $mean, variance: $variance)';
}

/// The Tier A prediction model: a robust scalar Kalman filter on log cycle
/// length.
///
/// This is a **port**, not an original implementation. The reference is
/// `research/src/cyclecore/models/bayes_filter.py`, and
/// `artifacts/golden/predictor_cases_v1.json` pins the two to 1e-9 on floats
/// and to exact equality on day counts (DECISIONS.md ADR-0002). If the two ever
/// disagree, this file is the one that is wrong.
///
/// The model
/// ---------
/// A local-level state-space model on the log of cycle length:
///
/// ```text
/// level:        mu_i = mu_{i-1} + w_i,   w_i ~ Normal(0, driftVar)
/// observation:  y_i  ~ StudentT(nu, mu_i, sqrt(obsVar))
/// ```
///
/// Working in logs keeps lengths positive and makes variability multiplicative,
/// which matches how cycle variation actually behaves. The Student-t
/// observation with a small fixed `nu` is what makes a single mis-logged 55 day
/// cycle *widen* the interval instead of dragging the mean, which a Gaussian
/// would do.
///
/// Inference is a scalar Kalman filter with an IRLS reweighting step standing in
/// for the t-likelihood. That is what makes it portable: the whole forward pass
/// is add, subtract, multiply, divide, `log`, `exp` and `sqrt`, with **no
/// special function anywhere** on the path from observations to a predicted
/// date. The Student-t quantiles the interval needs are constants shipped in
/// `priors_v1.json`, because `nu` is fixed.
///
/// Two rules keep the port bit-comparable, and breaking either is silent:
///
/// 1. The arithmetic is written in exactly the reference's order and grouping.
///    Floating-point addition is not associative, so reordering a sum is a real
///    change.
/// 2. Rounding to whole days is always `floor(x + 0.5)`, never `.round()`.
///    Python's `round` is banker's rounding and Dart's `.round()` is
///    half-away-from-zero, so either would diverge on exact halves.
abstract final class BayesFilter {
  /// The prior state, before any cycle has been observed.
  ///
  /// This is what a brand-new user gets. It is a real, usable distribution
  /// rather than a placeholder, which is why the app can always show something
  /// honest instead of an empty screen.
  static FilterState initialState(FilterPriors priors) => FilterState(
    mean: priors.logMeanCenter,
    variance: priors.logMeanVar,
    nObs: 0,
  );

  /// Folds one observed [cycleLengthDays] into [state].
  ///
  /// Throws [ArgumentError] if the length is not positive. The log of a
  /// non-positive length is meaningless, and returning NaN would poison every
  /// later prediction instead of failing where the bad value entered.
  static FilterState update(
    FilterState state,
    int cycleLengthDays,
    FilterPriors priors,
  ) {
    if (cycleLengthDays <= 0) {
      throw ArgumentError.value(
        cycleLengthDays,
        'cycleLengthDays',
        'must be positive',
      );
    }

    final y = math.log(cycleLengthDays.toDouble());

    // Predict: the level random-walks, so uncertainty grows before we look.
    final meanPred = state.mean;
    final varPred = state.variance + priors.driftVar;

    // Standardised residual under a Gaussian observation of the same variance.
    final residual = y - meanPred;
    final varGauss = varPred + priors.obsVar;
    final rSquared = (residual * residual) / varGauss;

    // IRLS weight for a Student-t likelihood: (nu + 1) / (nu + r^2). Pure
    // arithmetic, no special functions. A large residual drives the weight
    // towards zero, which inflates the effective observation variance and so
    // down-weights the outlier instead of chasing it.
    final weight = (priors.studentTDf + 1.0) / (priors.studentTDf + rSquared);
    final obsVarEff = math.max(priors.obsVar / weight, priors.minObsVar);

    final varTotal = varPred + obsVarEff;
    final gain = varPred / varTotal;

    return FilterState(
      mean: meanPred + gain * residual,
      variance: (1.0 - gain) * varPred,
      nObs: state.nObs + 1,
    );
  }

  /// Runs the filter over a whole history, oldest first.
  ///
  /// Returns the prior state followed by the posterior after each observation,
  /// so the result has `cycleLengths.length + 1` entries. Returning every
  /// intermediate state is what lets the golden vectors pin the trajectory
  /// rather than only the endpoint, which is where a port is most likely to
  /// drift.
  static List<FilterState> filterSequence(
    List<int> cycleLengths,
    FilterPriors priors,
  ) {
    final states = <FilterState>[initialState(priors)];
    for (final length in cycleLengths) {
      states.add(update(states.last, length, priors));
    }
    return states;
  }

  /// The one-step-ahead predictive distribution of the next log cycle length.
  static Forecast forecast(FilterState state, FilterPriors priors) => Forecast(
    mean: state.mean,
    variance: state.variance + priors.driftVar + priors.obsVar,
  );

  /// A predictive quantile on the log scale.
  ///
  /// [tQuantile] is a Student-t quantile for the model's fixed degrees of
  /// freedom, taken from the shipped table. Passing it in rather than computing
  /// it is what keeps this function free of special functions.
  static double predictiveQuantile(Forecast fc, double tQuantile) =>
      fc.mean + tQuantile * fc.scale;

  /// Converts a log-scale value to a whole number of days.
  ///
  /// Uses `floor(x + 0.5)` rather than [num.round]. Dart rounds halves away
  /// from zero and Python rounds them to even, so relying on either language's
  /// rounding would make the two runtimes disagree on exact halves. See rule 2
  /// in the class documentation.
  static int daysFromLog(double logDays) => (math.exp(logDays) + 0.5).floor();
}
