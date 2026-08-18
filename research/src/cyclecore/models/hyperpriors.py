"""Fitting the two free population variances (task PY-B).

What is fitted, and what is not
-------------------------------
The prior *centre* (`mean_cycle_days`) and the between-user spread
(`level_sd_log`) come from published summary statistics, in `PopulationConfig`.
They are not fitted here, deliberately: fitting them on the project's own
simulator would be circular, since the simulator is calibrated to those same
figures. Summary statistics are also the safest possible input because they
contain no individual records (docs/PLAN.md 6.1).

What *is* fitted is the pair `(obs_sd, drift_sd)`, by maximising the filter's own
one-step-ahead predictive likelihood across a population of histories. That is
empirical Bayes over exactly two parameters, so `scipy.optimize` is the right tool
and NUTS would be ceremony. It is also fully deterministic given a seed, which
matters because the output is a committed artifact.

If the hyperprior model ever becomes genuinely hierarchical, the `bayes` extra
(NumPyro, ArviZ) exists for that. It is not needed for two parameters.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass, replace

import numpy as np
from scipy import optimize, stats

from cyclecore.models.bayes_filter import FilterPriors, forecast, initial_state, update

__all__ = ["FitResult", "fit_variances", "population_log_likelihood"]


@dataclass(frozen=True, slots=True)
class FitResult:
    """Outcome of the variance fit.

    Attributes:
        obs_sd: Fitted within-user observation SD on the log scale.
        drift_sd: Fitted random-walk SD of the level.
        log_likelihood: Total one-step predictive log-likelihood at the optimum.
        n_sequences: How many histories were fitted against.
        n_observations: How many one-step predictions contributed.
        converged: Whether the optimiser reported success.
        iterations: Optimiser iteration count.
    """

    obs_sd: float
    drift_sd: float
    log_likelihood: float
    n_sequences: int
    n_observations: int
    converged: bool
    iterations: int


def population_log_likelihood(
    sequences: Sequence[Sequence[int]],
    priors: FilterPriors,
) -> tuple[float, int]:
    """Total one-step-ahead predictive log-likelihood across `sequences`.

    Every term is a genuine out-of-sample prediction: the density of cycle `i` is
    evaluated under the state that has seen only cycles before it. That is what
    makes maximising this quantity a defensible way to choose the variances rather
    than an in-sample fit that would drive them to zero.

    Args:
        sequences: One sequence of observed cycle lengths per user.
        priors: Constants, whose `obs_var` and `drift_var` are being evaluated.

    Returns:
        A pair of the summed log-likelihood and the number of terms in it.
    """
    total = 0.0
    count = 0
    for lengths in sequences:
        if len(lengths) < 2:
            continue
        state = initial_state(priors)
        for length in lengths:
            fc = forecast(state, priors)
            # Student-t density on the log scale. scipy is fine here: this is the
            # fitting path, which never runs on a device.
            total += float(
                stats.t.logpdf(
                    math.log(length),
                    df=priors.student_t_df,
                    loc=fc.mean,
                    scale=fc.scale,
                )
            )
            count += 1
            state = update(state, length, priors)
    if count == 0:
        raise ValueError("no sequence had at least two cycles, nothing to fit")
    return total, count


def fit_variances(
    sequences: Sequence[Sequence[int]],
    base: FilterPriors,
    *,
    obs_sd_bounds: tuple[float, float] = (0.015, 0.30),
    drift_sd_bounds: tuple[float, float] = (0.001, 0.10),
    max_iterations: int = 200,
) -> FitResult:
    """Fit `(obs_sd, drift_sd)` by maximum one-step predictive likelihood.

    Optimises in log space so the parameters stay strictly positive without the
    optimiser having to respect a hard boundary, and uses L-BFGS-B with numerical
    gradients, which is ample for a smooth two-parameter surface.

    Args:
        sequences: Observed cycle histories, one per user.
        base: Starting constants. `obs_var` and `drift_var` are overwritten by the
            fit; every other field is carried through unchanged.
        obs_sd_bounds: Search bounds for the observation SD.
        drift_sd_bounds: Search bounds for the drift SD.
        max_iterations: Optimiser iteration cap.

    Returns:
        The fitted result.
    """
    log_bounds = [
        (math.log(obs_sd_bounds[0]), math.log(obs_sd_bounds[1])),
        (math.log(drift_sd_bounds[0]), math.log(drift_sd_bounds[1])),
    ]

    def negative_log_likelihood(log_params: np.ndarray) -> float:
        obs_sd = math.exp(float(log_params[0]))
        drift_sd = math.exp(float(log_params[1]))
        candidate = replace(base, obs_var=obs_sd**2, drift_var=drift_sd**2)
        total, _ = population_log_likelihood(sequences, candidate)
        # Guard against a non-finite surface rather than letting the optimiser
        # wander into it and return a silently wrong optimum.
        return float("inf") if not math.isfinite(total) else -total

    start = np.array(
        [
            math.log(math.sqrt(base.obs_var)),
            math.log(math.sqrt(base.drift_var)),
        ]
    )
    result = optimize.minimize(
        negative_log_likelihood,
        start,
        method="L-BFGS-B",
        bounds=log_bounds,
        options={"maxiter": max_iterations},
    )

    obs_sd = math.exp(float(result.x[0]))
    drift_sd = math.exp(float(result.x[1]))
    fitted = replace(base, obs_var=obs_sd**2, drift_var=drift_sd**2)
    total, count = population_log_likelihood(sequences, fitted)

    return FitResult(
        obs_sd=obs_sd,
        drift_sd=drift_sd,
        log_likelihood=total,
        n_sequences=len(sequences),
        n_observations=count,
        converged=bool(result.success),
        iterations=int(result.nit),
    )
