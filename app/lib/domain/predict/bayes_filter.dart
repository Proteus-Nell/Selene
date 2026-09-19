/// Robust Bayesian filter over cycle length.
///
/// The Tier A prediction model: a scalar Kalman filter on the log of cycle
/// length, with an IRLS reweighting step standing in for a Student-t
/// observation. A port of the research implementation, pinned to it by the
/// golden vectors.
///
/// Pipeline:
///     1. Start from the population prior.
///     2. Fold each observed cycle length in, one at a time.
///     3. Forecast one step ahead from the resulting posterior.
///     4. Read a predictive quantile off that forecast, then convert it to
///        whole days.
///
/// Includes:
///     - FilterState: The posterior after some number of observations.
///     - Forecast: The one-step-ahead predictive distribution.
///     - BayesFilter: The filter itself.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// Filter state: the posterior over the log-length level.
///
/// Mirrors `FilterState` in `research/src/cyclecore/models/bayes_filter.py`.
/// The field is called [variance] rather than `var` only because `var` is a
/// Dart keyword; it is the same quantity.
///
/// Attributes:
///     mean (double): Posterior mean of the level, on the log scale.
///     variance (double): Posterior variance of the level, on the log scale.
///     nObs (int): How many cycle lengths have been folded in.
@immutable
final class FilterState {
  /// Creates a state with [mean] and [variance] after [nObs] observations.
  ///
  /// Args:
  ///     mean (double): Posterior mean of the level, on the log scale.
  ///     variance (double): Posterior variance, on the log scale.
  ///     nObs (int): How many cycle lengths have been folded in.
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

/// Forecast: the one-step-ahead predictive distribution for the next log
/// cycle length.
///
/// Wider than the [FilterState] it came from, because it carries drift and
/// observation noise on top of the level's own uncertainty.
///
/// Attributes:
///     mean (double): Predictive mean on the log scale.
///     variance (double): Predictive variance on the log scale, including
///         drift and observation noise.
@immutable
final class Forecast {
  /// Creates a forecast with predictive [mean] and [variance].
  ///
  /// Args:
  ///     mean (double): Predictive mean on the log scale.
  ///     variance (double): Predictive variance on the log scale.
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

/// Bayes filter: a robust scalar Kalman filter on log cycle length.
///
/// This is a **port**, not an original implementation. The reference is
/// `research/src/cyclecore/models/bayes_filter.py`, and
/// `artifacts/golden/predictor_cases_v1.json` pins the two to 1e-9 on floats
/// and to exact equality on day counts (DECISIONS.md ADR-0002). If the two
/// ever disagree, this file is the one that is wrong.
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
/// Working in logs keeps lengths positive and makes variability
/// multiplicative, which matches how cycle variation actually behaves. The
/// Student-t observation with a small fixed `nu` is what makes a single
/// mis-logged 55 day cycle *widen* the interval instead of dragging the mean,
/// which a Gaussian would do.
///
/// Inference is a scalar Kalman filter with an IRLS reweighting step standing
/// in for the t-likelihood. That is what makes it portable: the whole forward
/// pass is add, subtract, multiply, divide, `log`, `exp` and `sqrt`, with **no
/// special function anywhere** on the path from observations to a predicted
/// date. The Student-t quantiles the interval needs are constants shipped in
/// `priors_v1.json`, because `nu` is fixed.
///
/// Two rules keep the port bit-comparable, and breaking either is silent:
///
/// 1. The arithmetic is written in exactly the reference's order and grouping.
///    Floating-point addition is not associative, so reordering a sum is a
///    real change.
/// 2. Rounding to whole days is always `floor(x + 0.5)`, never `.round()`.
///    Python's `round` is banker's rounding and Dart's `.round()` is
///    half-away-from-zero, so either would diverge on exact halves.
abstract final class BayesFilter {
  /// Build the prior state, before any cycle has been observed.
  ///
  /// This is what a brand-new user gets. It is a real, usable distribution
  /// rather than a placeholder, which is why the app can always show something
  /// honest instead of an empty screen.
  ///
  /// Args:
  ///     priors (FilterPriors): The fitted population priors.
  ///
  /// Returns:
  ///     FilterState: The prior, with `nObs` of zero.
  static FilterState initialState(FilterPriors priors) => FilterState(
    mean: priors.logMeanCenter,
    variance: priors.logMeanVar,
    nObs: 0,
  );

  /// Fold one observed cycle length into the state.
  ///
  /// Steps:
  ///     1. Predict: let the level random-walk, so uncertainty grows.
  ///     2. Score the residual against a Gaussian of the same variance.
  ///     3. Reweight by the IRLS weight, which inflates the effective
  ///        observation variance for an outlier.
  ///     4. Apply the Kalman gain.
  ///
  /// Args:
  ///     state (FilterState): The posterior so far.
  ///     cycleLengthDays (int): The newly observed length. Must be positive.
  ///     priors (FilterPriors): The fitted population priors.
  ///
  /// Returns:
  ///     FilterState: The updated posterior, with `nObs` one higher.
  ///
  /// Throws:
  ///     ArgumentError: If the length is not positive. The log of a
  ///         non-positive length is meaningless, and returning NaN would
  ///         poison every later prediction instead of failing where the bad
  ///         value entered.
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
    final varPred = state.variance + priors.driftVar; // log scale

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

  /// Run the filter over a whole history, oldest first.
  ///
  /// Returning every intermediate state is what lets the golden vectors pin
  /// the trajectory rather than only the endpoint, which is where a port is
  /// most likely to drift.
  ///
  /// Args:
  ///     cycleLengths (`List<int>`): Observed lengths, oldest first.
  ///     priors (FilterPriors): The fitted population priors.
  ///
  /// Returns:
  ///     `List<FilterState>`: The prior followed by the posterior after each
  ///     observation, so `cycleLengths.length + 1` entries.
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

  /// Forecast the next log cycle length, one step ahead.
  ///
  /// Args:
  ///     state (FilterState): The posterior to forecast from.
  ///     priors (FilterPriors): The fitted population priors.
  ///
  /// Returns:
  ///     Forecast: The predictive distribution, widened by drift and
  ///     observation noise.
  static Forecast forecast(FilterState state, FilterPriors priors) => Forecast(
    mean: state.mean,
    variance: state.variance + priors.driftVar + priors.obsVar,
  );

  /// Read a predictive quantile off a forecast, on the log scale.
  ///
  /// `mean + tQuantile * scale`
  ///
  /// Args:
  ///     fc (Forecast): The predictive distribution.
  ///     tQuantile (double): A Student-t quantile for the model's fixed
  ///         degrees of freedom, taken from the shipped table. Passing it in
  ///         rather than computing it is what keeps this function free of
  ///         special functions.
  ///
  /// Returns:
  ///     double: The quantile, on the log scale.
  static double predictiveQuantile(Forecast fc, double tQuantile) =>
      fc.mean + tQuantile * fc.scale;

  /// Convert a log-scale value to a whole number of days.
  ///
  /// Uses `floor(x + 0.5)` rather than [num.round]. Dart rounds halves away
  /// from zero and Python rounds them to even, so relying on either language's
  /// rounding would make the two runtimes disagree on exact halves. See rule 2
  /// in the class documentation.
  ///
  /// Args:
  ///     logDays (double): A value on the log scale.
  ///
  /// Returns:
  ///     int: The corresponding whole number of days.
  static int daysFromLog(double logDays) => (math.exp(logDays) + 0.5).floor();
}
