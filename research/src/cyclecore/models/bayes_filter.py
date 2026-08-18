"""Reference implementation of the Tier A on-device prediction model.

This module is the **contract**. `app/lib/domain/predict/bayes_filter.dart` is a
port of it, and `artifacts/golden/predictor_cases_v1.json` pins their agreement to
1e-9 on floats and to exact equality on day counts. See DECISIONS.md ADR-0002.

The model
---------
A local-level state-space model on the log of cycle length:

    level:        mu_i = mu_{i-1} + w_i,   w_i ~ Normal(0, drift_var)
    observation:  y_i  ~ StudentT(nu, mu_i, sqrt(obs_var))

Working in logs keeps lengths positive and makes variability multiplicative,
which matches how cycle variation actually behaves. The Student-t observation
with a small, fixed `nu` is what makes a single mis-logged 55 day cycle *widen*
the interval instead of dragging the mean, which a Gaussian would do.

Inference is a scalar Kalman filter with an IRLS reweighting step standing in for
the t-likelihood. That is deliberate, and it is the reason this module is
portable: the whole forward pass is add, subtract, multiply, divide, `log`,
`exp` and `sqrt`. There is **no special function** anywhere on the path from
observations to a predicted date.

Portability rules (violating any of these breaks the Dart port)
--------------------------------------------------------------
1. No `scipy` on the forward path. The Student-t **quantiles** needed for the
   predictive interval are constants, because `nu` is fixed: they are computed
   once by `export.priors_json` and shipped inside `priors_v1.json`. Dart reads
   them as data rather than computing them.
2. Rounding is always `floor(x + 0.5)`, never the language's `round`. Python's
   `round` is banker's rounding and Dart's `.round()` is half-away-from-zero, so
   using either would silently diverge on exact halves.
3. No `numpy` in the filter itself. Scalar floats only, so the arithmetic order
   is identical in both languages. `numpy` is fine in simulation and evaluation.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

__all__ = [
    "FilterPriors",
    "FilterState",
    "Forecast",
    "days_from_log",
    "filter_sequence",
    "forecast",
    "initial_state",
    "predictive_quantile",
    "update",
]


@dataclass(frozen=True, slots=True)
class FilterPriors:
    """Population-level constants the filter starts from.

    Fitted offline and shipped to the app as `priors_v1.json`. Every field is a
    plain float so the Dart side can hold the same values.

    Attributes:
        log_mean_center: Prior mean of the log-length level, `log(29)`-ish.
        log_mean_var: Prior variance of that level. Wide enough that roughly
            three observed cycles dominate it.
        obs_var: Within-user observation variance on the log scale.
        drift_var: Random-walk variance of the level between cycles.
        student_t_df: Degrees of freedom of the observation model. Fixed, which
            is what makes the predictive quantiles constants.
        min_obs_var: Floor on the effective observation variance, so a run of
            identical cycles cannot collapse the interval to zero width.
    """

    log_mean_center: float
    log_mean_var: float
    obs_var: float
    drift_var: float
    student_t_df: float
    min_obs_var: float


@dataclass(frozen=True, slots=True)
class FilterState:
    """Posterior over the log-length level after some number of observations.

    Attributes:
        mean: Posterior mean of the level.
        var: Posterior variance of the level.
        n_obs: How many cycle lengths have been folded in.
    """

    mean: float
    var: float
    n_obs: int


@dataclass(frozen=True, slots=True)
class Forecast:
    """One-step-ahead predictive distribution for the next log cycle length.

    Attributes:
        mean: Predictive mean on the log scale.
        var: Predictive variance on the log scale, including drift and
            observation noise.
    """

    mean: float
    var: float

    @property
    def scale(self) -> float:
        """Predictive standard deviation on the log scale."""
        return math.sqrt(self.var)


def initial_state(priors: FilterPriors) -> FilterState:
    """Return the prior state, before any cycle has been observed.

    This is what a brand-new user gets. It is a real, usable distribution, not a
    placeholder, which is why the app can always show something honest instead of
    an empty screen.
    """
    return FilterState(mean=priors.log_mean_center, var=priors.log_mean_var, n_obs=0)


def update(state: FilterState, cycle_length_days: int, priors: FilterPriors) -> FilterState:
    """Fold one observed cycle length into the posterior.

    Args:
        state: Posterior before this observation.
        cycle_length_days: Observed start-to-start length in whole days. Must be
            positive.
        priors: Population constants.

    Returns:
        The posterior after this observation.

    Raises:
        ValueError: If `cycle_length_days` is not positive, since `log` of a
            non-positive length is meaningless and silently returning NaN would
            poison every later prediction.
    """
    if cycle_length_days <= 0:
        raise ValueError(f"cycle_length_days must be positive, got {cycle_length_days}")

    y = math.log(float(cycle_length_days))

    # Predict: the level random-walks, so uncertainty grows before we look.
    mean_pred = state.mean
    var_pred = state.var + priors.drift_var

    # Standardised residual under a Gaussian observation of the same variance.
    residual = y - mean_pred
    var_gauss = var_pred + priors.obs_var
    r_squared = (residual * residual) / var_gauss

    # IRLS weight for a Student-t likelihood: (nu + 1) / (nu + r^2).
    # Pure arithmetic, no special functions. A large residual drives the weight
    # towards zero, which inflates the effective observation variance and so
    # down-weights the outlier instead of chasing it.
    weight = (priors.student_t_df + 1.0) / (priors.student_t_df + r_squared)
    obs_var_eff = max(priors.obs_var / weight, priors.min_obs_var)

    var_total = var_pred + obs_var_eff
    gain = var_pred / var_total

    return FilterState(
        mean=mean_pred + gain * residual,
        var=(1.0 - gain) * var_pred,
        n_obs=state.n_obs + 1,
    )


def filter_sequence(cycle_lengths: list[int], priors: FilterPriors) -> list[FilterState]:
    """Run the filter over a whole history.

    Returns:
        The prior state followed by the posterior after each observation, so the
        list has `len(cycle_lengths) + 1` entries. Returning every intermediate
        state is what lets the golden vectors pin the trajectory rather than only
        the endpoint, which is where a port is most likely to drift.
    """
    states = [initial_state(priors)]
    for length in cycle_lengths:
        states.append(update(states[-1], length, priors))
    return states


def forecast(state: FilterState, priors: FilterPriors) -> Forecast:
    """Return the one-step-ahead predictive distribution of log cycle length."""
    return Forecast(mean=state.mean, var=state.var + priors.drift_var + priors.obs_var)


def predictive_quantile(fc: Forecast, t_quantile: float) -> float:
    """Return a predictive quantile on the log scale.

    Args:
        fc: The predictive distribution.
        t_quantile: A Student-t quantile for the model's fixed degrees of
            freedom, taken from the shipped constants table. Passing it in rather
            than computing it is what keeps this function portable to Dart.
    """
    return fc.mean + t_quantile * fc.scale


def days_from_log(log_days: float) -> int:
    """Convert a log-scale value to a whole number of days.

    Uses `floor(x + 0.5)` rather than `round`. Python's `round` is banker's
    rounding and Dart's `.round()` is half-away-from-zero, so relying on either
    would make the two runtimes disagree on exact halves. See the portability
    rules in the module docstring.
    """
    return math.floor(math.exp(log_days) + 0.5)
