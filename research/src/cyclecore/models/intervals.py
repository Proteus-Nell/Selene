"""Turning a predictive distribution into the day windows the app shows.

Split from `bayes_filter` because it has two halves with very different
portability rules:

* `student_t_quantiles` uses `scipy` and runs **offline only**. Its output is
  baked into `priors_v1.json` as a small table of constants.
* everything else is pure arithmetic over that table, and is ported to Dart.

That split is the whole reason the Dart port needs no special functions. See the
portability rules in `bayes_filter`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Final

from cyclecore.models.bayes_filter import (
    FilterPriors,
    FilterState,
    Forecast,
    days_from_log,
    filter_sequence,
    forecast,
    predictive_quantile,
)
from cyclecore.models.personalize import RefitResult, refit_user

__all__ = [
    "CONFIDENCE_HIGH_MAX_DAYS",
    "CONFIDENCE_LOW_MAX_DAYS",
    "CONFIDENCE_MEDIUM_MAX_DAYS",
    "QUANTILE_LEVELS",
    "PredictionWindows",
    "confidence_class",
    "student_t_quantiles",
    "windows_for_history",
    "windows_from_state",
]

QUANTILE_LEVELS: Final[dict[str, float]] = {
    "p10": 0.10,
    "p25": 0.25,
    "p50": 0.50,
    "p75": 0.75,
    "p90": 0.90,
}
"""The only quantiles the app needs: p25/p75 bound the 50% window and p10/p90 the
80% window. Keeping the set small and fixed is what makes shipping them as
constants practical."""

CONFIDENCE_HIGH_MAX_DAYS: Final[int] = 4
"""An 80% window narrower than this counts as high confidence."""

CONFIDENCE_MEDIUM_MAX_DAYS: Final[int] = 8
"""Below this, medium confidence."""

CONFIDENCE_LOW_MAX_DAYS: Final[int] = 14
"""Below this, low confidence. At or above it, refuse to give a narrow window."""


@dataclass(frozen=True, slots=True)
class PredictionWindows:
    """Predicted next cycle length and its windows, all in whole days.

    Attributes:
        median_days: Cycle length at the predictive median.
        lo50: Lower bound of the 50% window.
        hi50: Upper bound of the 50% window.
        lo80: Lower bound of the 80% window.
        hi80: Upper bound of the 80% window.
    """

    median_days: int
    lo50: int
    hi50: int
    lo80: int
    hi80: int

    @property
    def width80(self) -> int:
        """Width of the 80% window in days, counted inclusively."""
        return self.hi80 - self.lo80 + 1

    @property
    def width50(self) -> int:
        """Width of the 50% window in days, counted inclusively."""
        return self.hi50 - self.lo50 + 1

    @property
    def is_coherent(self) -> bool:
        """Whether the windows nest correctly around the median."""
        return self.lo80 <= self.lo50 <= self.median_days <= self.hi50 <= self.hi80


def student_t_quantiles(df: float) -> dict[str, float]:
    """Compute the Student-t quantiles for `df` degrees of freedom.

    **Offline only.** Imports `scipy` lazily so that importing this module does not
    pull `scipy` into a path that is meant to stay dependency-light, and so the
    boundary between the portable and non-portable halves is obvious at the call
    site.

    Args:
        df: Degrees of freedom. Must match `FilterPriors.student_t_df`, or the
            shipped table will not correspond to the shipped model.

    Returns:
        A mapping from level name to quantile, for every entry in
        `QUANTILE_LEVELS`.
    """
    from scipy import stats

    return {name: float(stats.t.ppf(p, df)) for name, p in QUANTILE_LEVELS.items()}


def windows_from_state(
    state: FilterState,
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> PredictionWindows:
    """Convert a posterior into day windows.

    Pure arithmetic over `t_quantiles`, so this function is the direct model for
    the Dart implementation.

    Args:
        state: Posterior over the log-length level.
        priors: Population constants.
        t_quantiles: The shipped quantile table.

    Returns:
        The predicted length and its windows, in whole days.
    """
    fc: Forecast = forecast(state, priors)
    return PredictionWindows(
        median_days=days_from_log(predictive_quantile(fc, t_quantiles["p50"])),
        lo50=days_from_log(predictive_quantile(fc, t_quantiles["p25"])),
        hi50=days_from_log(predictive_quantile(fc, t_quantiles["p75"])),
        lo80=days_from_log(predictive_quantile(fc, t_quantiles["p10"])),
        hi80=days_from_log(predictive_quantile(fc, t_quantiles["p90"])),
    )


def windows_for_history(
    cycle_lengths: list[int],
    base_priors: FilterPriors,
    t_quantiles: dict[str, float],
    *,
    personalise: bool = True,
) -> tuple[PredictionWindows, RefitResult]:
    """Full pipeline: history to prediction, exactly as the app runs it.

    Personalisation comes first, because the refit chooses the variances the
    filter then runs with. Skipping it makes the interval width independent of how
    variable the user actually is, which is the defect recorded in
    `tests/test_calibration.py`.

    Args:
        cycle_lengths: Observed lengths, oldest first.
        base_priors: Population constants.
        t_quantiles: Shipped quantile table.
        personalise: Set False to reproduce the pre-personalisation behaviour, for
            comparison in tests.

    Returns:
        The day windows and the refit result that produced them.
    """
    refit = (
        refit_user(cycle_lengths, base_priors)
        if personalise
        else RefitResult(
            priors=base_priors,
            obs_sd=base_priors.obs_var**0.5,
            drift_sd=base_priors.drift_var**0.5,
            score=float("-inf"),
            personalised=False,
            n_cycles=len(cycle_lengths),
        )
    )
    state = filter_sequence(cycle_lengths, refit.priors)[-1]
    return windows_from_state(state, refit.priors, t_quantiles), refit


def confidence_class(width80_days: int) -> str:
    """Classify confidence from the width of the 80% window.

    Returns:
        One of `high`, `medium`, `low` or `too_irregular`. The last is not an
        error: it is the state where the app shows statistics instead of a narrow
        window, and it must never be a dead end (risk R17).
    """
    if width80_days < CONFIDENCE_HIGH_MAX_DAYS:
        return "high"
    if width80_days < CONFIDENCE_MEDIUM_MAX_DAYS:
        return "medium"
    if width80_days < CONFIDENCE_LOW_MAX_DAYS:
        return "low"
    return "too_irregular"
