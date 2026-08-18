"""Per-user refit of the observation and drift variances.

Why this is not optional
------------------------
Without it the filter learns a user's *mean* and never their *variability*. The
predictive variance is `state.var + drift_var + obs_var`, and `obs_var` is a
population constant, so `state.var` shrinks with every observation no matter how
erratic the history is. Every user converges to the same interval width.

Measured consequence, before this module existed: 80% intervals covered 90% of
outcomes for regular users and 41% for irregular ones. The pooled figure was 78%
and looked fine. See `tests/test_calibration.py`.

So this is part of Tier A, not a later enhancement. It is what makes the app
honest for the people it otherwise serves worst.

Portability
-----------
The objective drops every term of the Student-t log density that depends only on
the degrees of freedom:

    log f(y) = C(v) - log(s) - ((v+1)/2) * log(1 + r^2 / v)

`C(v)` contains the `lgamma` terms and is identical at every grid point because
`v` is fixed, so omitting it does not change which point wins. What remains is
arithmetic and `log`, which the Dart port can do. That is the whole trick: no
special function ever runs on a device.

The search is a fixed grid rather than an optimiser, for the same reason. A grid
is a `for` loop with no convergence behaviour to reproduce, so the two runtimes
cannot disagree about where it stopped.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass, replace

from cyclecore.models.bayes_filter import FilterPriors, forecast, initial_state, update

__all__ = [
    "DEFAULT_DRIFT_SD_GRID",
    "DEFAULT_OBS_SD_GRID",
    "PERSONALIZE_MIN_CYCLES",
    "RefitResult",
    "partial_log_likelihood",
    "refit_user",
]

PERSONALIZE_MIN_CYCLES = 5
"""Completed cycles required before the refit runs.

Below this the estimate is dominated by noise and would swing the interval width
around alarmingly between cycles. The population values are used until then, and
the app labels that state as not yet personalised.
"""

DEFAULT_OBS_SD_GRID: tuple[float, ...] = (
    0.020,
    0.026,
    0.033,
    0.042,
    0.053,
    0.067,
    0.085,
    0.107,
    0.135,
    0.170,
    0.215,
    0.271,
    0.342,
)
"""Candidate within-user observation SDs, roughly geometric from 0.02 to 0.34.

Geometric rather than linear because the quantity is a scale: the difference
between 0.02 and 0.03 matters far more than between 0.30 and 0.31. Shipped as
explicit constants so Dart iterates the identical values instead of recomputing a
log-space range and rounding differently.
"""

DEFAULT_DRIFT_SD_GRID: tuple[float, ...] = (
    0.004,
    0.008,
    0.014,
    0.024,
    0.040,
    0.066,
    0.100,
)
"""Candidate drift SDs. Coarser than the observation grid because the data
identifies drift far less sharply, so a finer grid would only overfit."""


@dataclass(frozen=True, slots=True)
class RefitResult:
    """Outcome of a per-user refit.

    Attributes:
        priors: The priors to use for this user, personalised or not.
        obs_sd: Selected observation SD.
        drift_sd: Selected drift SD.
        score: Partial log-likelihood at the selected point.
        personalised: False when the history was too short and the population
            values were kept.
        n_cycles: How many observations were available.
    """

    priors: FilterPriors
    obs_sd: float
    drift_sd: float
    score: float
    personalised: bool
    n_cycles: int


def partial_log_likelihood(cycle_lengths: Sequence[int], priors: FilterPriors) -> float:
    """One-step-ahead predictive log-likelihood, up to a constant.

    Every term is genuinely out of sample: cycle `i` is scored under the state that
    has seen only the cycles before it. That is what stops the search collapsing
    the variances to zero, which an in-sample fit would do.

    Args:
        cycle_lengths: Observed lengths, oldest first.
        priors: Candidate constants.

    Returns:
        The summed partial log density. Comparable across candidates that share
        the same `student_t_df`, and meaningless in absolute terms.
    """
    df = priors.student_t_df
    half = (df + 1.0) / 2.0
    total = 0.0
    state = initial_state(priors)
    for length in cycle_lengths:
        fc = forecast(state, priors)
        scale = fc.scale
        residual = (math.log(float(length)) - fc.mean) / scale
        total += -math.log(scale) - half * math.log(1.0 + residual * residual / df)
        state = update(state, length, priors)
    return total


def refit_user(
    cycle_lengths: Sequence[int],
    base: FilterPriors,
    *,
    obs_sd_grid: Sequence[float] = DEFAULT_OBS_SD_GRID,
    drift_sd_grid: Sequence[float] = DEFAULT_DRIFT_SD_GRID,
    min_cycles: int = PERSONALIZE_MIN_CYCLES,
) -> RefitResult:
    """Pick the grid point that best explains this user's own history.

    Args:
        cycle_lengths: The user's observed lengths, oldest first.
        base: Population constants, used unchanged if the history is too short.
        obs_sd_grid: Candidate observation SDs.
        drift_sd_grid: Candidate drift SDs.
        min_cycles: Minimum history before personalising.

    Returns:
        The refit result, always usable even when personalisation was skipped.
    """
    if len(cycle_lengths) < min_cycles:
        return RefitResult(
            priors=base,
            obs_sd=math.sqrt(base.obs_var),
            drift_sd=math.sqrt(base.drift_var),
            score=float("-inf"),
            personalised=False,
            n_cycles=len(cycle_lengths),
        )

    best_score = float("-inf")
    best_obs = obs_sd_grid[0]
    best_drift = drift_sd_grid[0]
    # Deterministic iteration order, and strictly-greater comparison, so ties
    # resolve to the first (tightest) candidate in both runtimes.
    for obs_sd in obs_sd_grid:
        for drift_sd in drift_sd_grid:
            candidate = replace(base, obs_var=obs_sd * obs_sd, drift_var=drift_sd * drift_sd)
            score = partial_log_likelihood(cycle_lengths, candidate)
            if score > best_score:
                best_score = score
                best_obs = obs_sd
                best_drift = drift_sd

    return RefitResult(
        priors=replace(base, obs_var=best_obs * best_obs, drift_var=best_drift * best_drift),
        obs_sd=best_obs,
        drift_sd=best_drift,
        score=best_score,
        personalised=True,
        n_cycles=len(cycle_lengths),
    )
