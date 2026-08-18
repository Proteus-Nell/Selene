"""Typed configuration. Every tunable number lives here or in `configs/*.yaml`.

No magic constants in the model or export code. See docs/PLAN.md 5.2.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field

from cyclecore.models.bayes_filter import FilterPriors
from cyclecore.seeds import DEFAULT_SEED

__all__ = [
    "BacktestConfig",
    "FitConfig",
    "PopulationConfig",
    "Settings",
    "load_settings",
]


class PopulationConfig(BaseModel):
    """Population-level starting values for the filter priors.

    These are the one place in the project where an external number enters the
    model, so each carries its provenance. They come from *published summary
    statistics* rather than individual records, which is the safest possible
    input: no consent question arises because no person is represented. See
    docs/PLAN.md 6.1.
    """

    mean_cycle_days: float = Field(
        default=29.0,
        gt=10,
        lt=60,
        description=(
            "Population mean cycle length in days. Bull et al., npj Digital "
            "Medicine 2019, report roughly 29.3 days across >600,000 cycles. "
            "[VERIFY the exact figure against the paper before publishing.]"
        ),
    )
    level_sd_log: float = Field(
        default=0.10,
        gt=0,
        lt=1,
        description=(
            "Between-user standard deviation of the log mean cycle length. A "
            "value of 0.10 puts roughly 95% of users between 24 and 36 days, "
            "which is consistent with the commonly cited 21 to 35 day normal "
            "range being a ~87% interval. [VERIFY]"
        ),
    )
    within_user_sd_log: float = Field(
        default=0.055,
        gt=0,
        lt=1,
        description=(
            "Starting within-user observation SD on the log scale, roughly 1.6 "
            "days at a 29 day cycle. Refined by the marginal-likelihood fit."
        ),
    )
    drift_sd_log: float = Field(
        default=0.018,
        gt=0,
        lt=1,
        description=(
            "Starting random-walk SD of the level between cycles, so that a "
            "user's typical length can migrate slowly over years without the "
            "filter treating each step as noise. Refined by the fit."
        ),
    )
    student_t_df: float = Field(
        default=4.0,
        ge=2.5,
        le=30,
        description=(
            "Observation degrees of freedom. Fixed deliberately: it is what makes "
            "the predictive quantiles compile-time constants and so keeps the "
            "Dart port free of special functions. Low enough for genuinely heavy "
            "tails, above 2 so the variance exists."
        ),
    )
    min_obs_sd_log: float = Field(
        default=0.02,
        gt=0,
        lt=1,
        description=(
            "Floor on the effective observation SD. Without it a run of "
            "identical cycles collapses the interval towards zero width, which "
            "would be the overconfidence this project is most concerned with "
            "(risk R6)."
        ),
    )

    def to_filter_priors(self) -> FilterPriors:
        """Convert to the scalar form the filter consumes."""
        return FilterPriors(
            log_mean_center=math.log(self.mean_cycle_days),
            log_mean_var=self.level_sd_log**2,
            obs_var=self.within_user_sd_log**2,
            drift_var=self.drift_sd_log**2,
            student_t_df=self.student_t_df,
            min_obs_var=self.min_obs_sd_log**2,
        )


class FitConfig(BaseModel):
    """Settings for the marginal-likelihood fit of the two free variances."""

    n_users: int = Field(default=2000, ge=50, description="Simulated users to fit against.")
    n_cycles: int = Field(default=24, ge=4, description="Cycles per simulated user.")
    obs_sd_bounds: tuple[float, float] = Field(default=(0.015, 0.30))
    drift_sd_bounds: tuple[float, float] = Field(default=(0.001, 0.10))
    max_iterations: int = Field(default=200, ge=10)


class BacktestConfig(BaseModel):
    """Settings for rolling-origin evaluation."""

    n_users: int = Field(default=1000, ge=20)
    n_cycles: int = Field(default=18, ge=4)
    min_history: int = Field(
        default=1,
        ge=0,
        description="Cycles of history before the first evaluated prediction.",
    )
    nominal_levels: tuple[float, float] = Field(
        default=(0.50, 0.80),
        description="Interval levels whose empirical coverage is reported.",
    )
    coverage_tolerance: float = Field(
        default=0.03,
        gt=0,
        description=(
            "Allowed absolute deviation of empirical from nominal coverage. The "
            "calibration test is the single most important gate in the repo, so "
            "this is deliberately tight."
        ),
    )


class Settings(BaseModel):
    """Top-level settings for a run."""

    seed: int = DEFAULT_SEED
    artifacts_dir: Path = Path("../artifacts")
    population: PopulationConfig = PopulationConfig()
    fit: FitConfig = FitConfig()
    backtest: BacktestConfig = BacktestConfig()


def load_settings(path: Path | None = None) -> Settings:
    """Load settings from a YAML file, falling back to the defaults.

    Args:
        path: YAML file to read. If `None`, or the file does not exist, the
            in-code defaults are used. Defaults are always valid on their own so
            that a fresh clone can produce artifacts with no configuration step.

    Returns:
        Validated settings.
    """
    if path is None or not path.exists():
        return Settings()
    raw: Any = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        raise TypeError(f"{path} must contain a YAML mapping, got {type(raw).__name__}")
    return Settings.model_validate(raw)
