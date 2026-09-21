/// Per-user refit of the filter variances.
///
/// Searches a fixed grid for the observation and drift variances that best
/// explain one user's own history, so that interval width tracks how erratic
/// that person's cycles actually are rather than converging on a population
/// average.
///
/// Pipeline:
///     1. Refuse the search below the minimum history and hand back the
///        population values unchanged.
///     2. Otherwise score every grid point by out-of-sample log-likelihood.
///     3. Keep the first strictly-best point, so ties resolve to the tightest.
///
/// Includes:
///     - RefitResult: What the refit chose, and whether it ran at all.
///     - Personalize: The objective and the grid search.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// Refit result: the outcome of a per-user refit.
///
/// Always usable, including when personalisation was skipped: [priors] then
/// holds the population constants unchanged and [personalised] is false, which
/// is the state the UI must label as "not yet tuned to you" rather than pass
/// off as a prediction about this person.
///
/// Attributes:
///     priors (FilterPriors): The priors to run the filter with.
///     obsSd (double): Selected observation SD, on the log scale.
///     driftSd (double): Selected drift SD, on the log scale.
///     score (double): Partial log-likelihood at the selected point.
///     personalised (bool): Whether the grid search actually ran.
///     nCycles (int): How many observations were available.
@immutable
final class RefitResult {
  /// Creates a refit result.
  ///
  /// Args:
  ///     priors (FilterPriors): The priors to run the filter with.
  ///     obsSd (double): Selected observation SD, on the log scale.
  ///     driftSd (double): Selected drift SD, on the log scale.
  ///     score (double): Partial log-likelihood at the selected point.
  ///     personalised (bool): Whether the grid search actually ran.
  ///     nCycles (int): How many observations were available.
  const RefitResult({
    required this.priors,
    required this.obsSd,
    required this.driftSd,
    required this.score,
    required this.personalised,
    required this.nCycles,
  });

  /// The priors to run the filter with for this user.
  final FilterPriors priors;

  /// Selected observation standard deviation, on the log scale.
  final double obsSd;

  /// Selected drift standard deviation, on the log scale.
  final double driftSd;

  /// Partial log-likelihood at the selected grid point.
  ///
  /// Negative infinity when the refit did not run. Comparable across
  /// candidates that share the same degrees of freedom, and meaningless in
  /// absolute terms.
  final double score;

  /// Whether the grid search actually ran.
  final bool personalised;

  /// How many observations were available.
  final int nCycles;

  @override
  bool operator ==(Object other) =>
      other is RefitResult &&
      other.priors == priors &&
      other.obsSd == obsSd &&
      other.driftSd == driftSd &&
      other.score == score &&
      other.personalised == personalised &&
      other.nCycles == nCycles;

  @override
  int get hashCode =>
      Object.hash(priors, obsSd, driftSd, score, personalised, nCycles);

  @override
  String toString() =>
      'RefitResult(obsSd: $obsSd, driftSd: $driftSd, score: $score, '
      'personalised: $personalised, nCycles: $nCycles)';
}

/// Personalize: on-device refit of the observation and drift variances.
///
/// Port of `research/src/cyclecore/models/personalize.py`.
///
/// Why this is not optional
/// ------------------------
/// Without it the filter learns a user's *mean* and never their *variability*.
/// The predictive variance is `state.variance + driftVar + obsVar`, and
/// `obsVar` is a population constant, so `state.variance` shrinks with every
/// observation no matter how erratic the history is, and every user converges
/// to the same interval width.
///
/// Measured before this existed, on a 400-user backtest at a nominal 80%:
/// coverage was 90% for regular users and **41%** for irregular ones, pooling
/// to a reassuring 78%. That is the concrete reason this is part of Tier A
/// rather than a later enhancement, and the reason the calibration gate never
/// reports a pooled figure. See `docs/PLAN.md` section 8.
///
/// Portability
/// -----------
/// The objective drops every term of the Student-t log density that depends
/// only on the degrees of freedom:
///
/// ```text
/// log f(y) = C(v) - log(s) - ((v+1)/2) * log(1 + r^2 / v)
/// ```
///
/// `C(v)` holds the `lgamma` terms and is identical at every grid point
/// because `v` is fixed, so omitting it cannot change which point wins. What
/// remains is arithmetic and `log`. The search is a fixed grid rather than an
/// optimiser for the same reason: a grid is a loop with no convergence
/// behaviour, so the two runtimes cannot disagree about where it stopped.
abstract final class Personalize {
  /// Score a history by one-step-ahead predictive log-likelihood.
  ///
  /// Every term is genuinely out of sample: cycle `i` is scored under the
  /// state that has seen only the cycles before it. That is what stops the
  /// search collapsing the variances towards zero, which an in-sample fit
  /// would do.
  ///
  /// Args:
  ///     cycleLengths (`List<int>`): Observed lengths, oldest first.
  ///     priors (FilterPriors): The candidate priors being scored.
  ///
  /// Returns:
  ///     double: The log-likelihood, up to a constant that is identical at
  ///     every grid point. Comparable between candidates, meaningless alone.
  static double partialLogLikelihood(
    List<int> cycleLengths,
    FilterPriors priors,
  ) {
    final df = priors.studentTDf;
    final half = (df + 1.0) / 2.0;
    var total = 0.0;
    var state = BayesFilter.initialState(priors);
    for (final length in cycleLengths) {
      final fc = BayesFilter.forecast(state, priors);
      final scale = fc.scale;
      final residual = (math.log(length.toDouble()) - fc.mean) / scale;
      total +=
          -math.log(scale) - half * math.log(1.0 + residual * residual / df);
      state = BayesFilter.update(state, length, priors);
    }
    return total;
  }

  /// Pick the grid point that best explains this user's own history.
  ///
  /// The grids are iterated in the order they ship in, observation SD
  /// outermost, and the comparison is strictly greater, so ties resolve to the
  /// first and therefore tightest candidate. Both runtimes must make the same
  /// choice on a tie, and a tie is not hypothetical: two adjacent grid points
  /// can score identically on a short, perfectly regular history.
  ///
  /// Args:
  ///     cycleLengths (`List<int>`): Observed lengths, oldest first.
  ///     base (FilterPriors): The population priors to vary from.
  ///     config (Personalisation): The grids, and the minimum history.
  ///
  /// Returns:
  ///     RefitResult: The chosen point. Below [Personalisation.minCycles]
  ///     observations the population values in [base] are kept and
  ///     `personalised` is false, because with a shorter history the estimate
  ///     is dominated by noise and the interval width would swing between
  ///     cycles.
  static RefitResult refitUser(
    List<int> cycleLengths,
    FilterPriors base,
    Personalisation config,
  ) {
    if (cycleLengths.length < config.minCycles) {
      return RefitResult(
        priors: base,
        obsSd: math.sqrt(base.obsVar),
        driftSd: math.sqrt(base.driftVar),
        score: double.negativeInfinity,
        personalised: false,
        nCycles: cycleLengths.length,
      );
    }

    var bestScore = double.negativeInfinity;
    var bestObs = config.obsSdGrid.first;
    var bestDrift = config.driftSdGrid.first;
    for (final obsSd in config.obsSdGrid) {
      for (final driftSd in config.driftSdGrid) {
        final candidate = base.withVariances(
          obsVar: obsSd * obsSd,
          driftVar: driftSd * driftSd,
        );
        final score = partialLogLikelihood(cycleLengths, candidate);
        if (score > bestScore) {
          bestScore = score;
          bestObs = obsSd;
          bestDrift = driftSd;
        }
      }
    }

    return RefitResult(
      priors: base.withVariances(
        obsVar: bestObs * bestObs,
        driftVar: bestDrift * bestDrift,
      ),
      obsSd: bestObs,
      driftSd: bestDrift,
      score: bestScore,
      personalised: true,
      nCycles: cycleLengths.length,
    );
  }
}
