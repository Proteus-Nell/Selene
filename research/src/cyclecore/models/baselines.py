"""Trivial predictors the Bayesian filter must beat to justify its complexity.

If the filter cannot beat `median_of_n` on both point error *and* interval
coverage, the right move is to ship the arithmetic and delete the filter. These
are reported in every backtest for exactly that reason (docs/PLAN.md section 8).

They are point predictors with no notion of uncertainty, which is itself the
argument against shipping one: the product requires an interval, and these cannot
provide one.
"""

from __future__ import annotations

import math
from collections.abc import Sequence

__all__ = ["last_cycle", "mean_of_n", "median_of_n"]


def last_cycle(history: Sequence[int]) -> int | None:
    """Predict that the next cycle repeats the most recent one.

    Returns:
        The last observed length, or `None` with no history.
    """
    return history[-1] if history else None


def mean_of_n(history: Sequence[int], n: int) -> int | None:
    """Predict the mean of the last `n` cycles, rounded to whole days.

    Args:
        history: Observed lengths, oldest first.
        n: Window size.

    Returns:
        The rounded mean, or `None` with no history.
    """
    window = _window(history, n)
    if not window:
        return None
    return math.floor(sum(window) / len(window) + 0.5)


def median_of_n(history: Sequence[int], n: int) -> int | None:
    """Predict the median of the last `n` cycles, rounded to whole days.

    The strongest of the three baselines, because a median shrugs off the one
    mis-logged 60 day pseudo-cycle that wrecks a mean.

    Args:
        history: Observed lengths, oldest first.
        n: Window size.

    Returns:
        The rounded median, or `None` with no history.
    """
    window = _window(history, n)
    if not window:
        return None
    ordered = sorted(window)
    middle = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[middle]
    return math.floor((ordered[middle - 1] + ordered[middle]) / 2 + 0.5)


def _window(history: Sequence[int], n: int) -> list[int]:
    if n <= 0:
        raise ValueError(f"n must be positive, got {n}")
    return list(history[-n:])
