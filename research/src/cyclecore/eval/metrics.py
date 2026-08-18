"""Evaluation metrics, with calibration treated as the primary one.

The ordering here is a deliberate product decision. A model with 1.5 day mean
absolute error and 60% empirical coverage on its nominal 80% interval is *worse*
for this app than one with 2.0 day error and 79% coverage, because the interval is
what the user is shown and what they act on. See docs/PLAN.md section 8.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

import numpy as np

__all__ = [
    "CalibrationReport",
    "absolute_errors",
    "empirical_coverage",
    "mean_absolute_error",
    "median_absolute_error",
    "summarise_calibration",
]


@dataclass(frozen=True, slots=True)
class CalibrationReport:
    """Point accuracy and interval calibration together.

    Attributes:
        n: Number of evaluated predictions.
        mae_days: Mean absolute error in days.
        median_ae_days: Median absolute error in days.
        coverage_50: Fraction of actuals inside the nominal 50% interval.
        coverage_80: Fraction inside the nominal 80% interval.
        mean_width_50: Mean width of the 50% interval, in days.
        mean_width_80: Mean width of the 80% interval, in days.
    """

    n: int
    mae_days: float
    median_ae_days: float
    coverage_50: float
    coverage_80: float
    mean_width_50: float
    mean_width_80: float

    def coverage_error(self, nominal: float) -> float:
        """Absolute deviation of empirical coverage from `nominal`."""
        empirical = self.coverage_50 if nominal == 0.50 else self.coverage_80
        return abs(empirical - nominal)


def absolute_errors(actual: Sequence[int], predicted: Sequence[int]) -> np.ndarray:
    """Return elementwise absolute errors in days."""
    if len(actual) != len(predicted):
        raise ValueError(f"length mismatch: {len(actual)} actual vs {len(predicted)} predicted")
    if not actual:
        raise ValueError("cannot compute errors over an empty sequence")
    return np.abs(np.asarray(actual, dtype=np.int64) - np.asarray(predicted, dtype=np.int64))


def mean_absolute_error(actual: Sequence[int], predicted: Sequence[int]) -> float:
    """Mean absolute error in days."""
    return float(absolute_errors(actual, predicted).mean())


def median_absolute_error(actual: Sequence[int], predicted: Sequence[int]) -> float:
    """Median absolute error in days. More robust than the mean to one bad user."""
    return float(np.median(absolute_errors(actual, predicted)))


def empirical_coverage(actual: Sequence[int], lower: Sequence[int], upper: Sequence[int]) -> float:
    """Fraction of actuals falling inside the inclusive interval `[lower, upper]`.

    Inclusive on both ends, because the intervals are whole-day windows shown to
    the user: a period starting on the last day of the predicted window did land
    inside it.
    """
    if not (len(actual) == len(lower) == len(upper)):
        raise ValueError("actual, lower and upper must be the same length")
    if not actual:
        raise ValueError("cannot compute coverage over an empty sequence")
    a = np.asarray(actual, dtype=np.int64)
    lo = np.asarray(lower, dtype=np.int64)
    hi = np.asarray(upper, dtype=np.int64)
    return float(np.mean((a >= lo) & (a <= hi)))


def summarise_calibration(
    actual: Sequence[int],
    predicted: Sequence[int],
    lower_50: Sequence[int],
    upper_50: Sequence[int],
    lower_80: Sequence[int],
    upper_80: Sequence[int],
) -> CalibrationReport:
    """Build a full report from parallel sequences of predictions and outcomes."""
    widths_50 = np.asarray(upper_50, dtype=np.int64) - np.asarray(lower_50, dtype=np.int64) + 1
    widths_80 = np.asarray(upper_80, dtype=np.int64) - np.asarray(lower_80, dtype=np.int64) + 1
    return CalibrationReport(
        n=len(actual),
        mae_days=mean_absolute_error(actual, predicted),
        median_ae_days=median_absolute_error(actual, predicted),
        coverage_50=empirical_coverage(actual, lower_50, upper_50),
        coverage_80=empirical_coverage(actual, lower_80, upper_80),
        mean_width_50=float(widths_50.mean()),
        mean_width_80=float(widths_80.mean()),
    )
