"""Generative simulator for menstrual cycle histories.

This is the **primary** dataset for the project, not a fallback. That inversion is
deliberate (docs/PLAN.md 6.1 and risk R1): a simulator needs no consent, carries no
licence risk, cannot be taken offline, and can be made arbitrarily adversarial.
Public data is used only to sanity-check that these marginals resemble reality.

The generative process mirrors the model's own assumptions, plus three things the
model does *not* know about, which is what makes it a fair test rather than a
tautology:

* occasional long, anovulatory-style cycles;
* missed logs, which merge two real cycles into one long observed one;
* a population with a genuinely irregular minority, not just noise around a mean.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

__all__ = [
    "MAX_PLAUSIBLE_DAYS",
    "MIN_PLAUSIBLE_DAYS",
    "SimulatedUser",
    "UserSpec",
    "sample_population",
    "simulate_population",
    "simulate_user",
]

MIN_PLAUSIBLE_DAYS = 15
"""Lower clamp on a generated cycle. Mirrors CycleRules.minPlausibleCycleDays."""

MAX_PLAUSIBLE_DAYS = 200
"""Upper clamp. Above the app's 90 day flag, because merged cycles must be able to
land in flagged territory for the validation path to be exercised."""


@dataclass(frozen=True, slots=True)
class UserSpec:
    """The true, unobservable parameters of one simulated person.

    Attributes:
        user_id: Stable identifier, used to key backtest rows.
        log_level: Starting true log mean cycle length.
        obs_sd: Within-user cycle-to-cycle SD on the log scale.
        drift_sd: Random-walk SD of the level between cycles.
        long_cycle_rate: Probability that any given cycle is extended, standing in
            for an anovulatory cycle.
        missed_log_rate: Probability that a cycle start goes unlogged, merging it
            with the next one.
    """

    user_id: int
    log_level: float
    obs_sd: float
    drift_sd: float
    long_cycle_rate: float
    missed_log_rate: float

    @property
    def is_irregular(self) -> bool:
        """Whether this user is drawn from the irregular part of the population."""
        return self.obs_sd >= 0.10


@dataclass(frozen=True, slots=True)
class SimulatedUser:
    """One simulated history, with the truth kept alongside what was observed.

    Attributes:
        spec: The generating parameters.
        true_lengths: The cycles that actually happened.
        observed_lengths: What the app would have recorded, after merging cycles
            whose start was missed. This is the only field a model may see.
    """

    spec: UserSpec
    true_lengths: list[int]
    observed_lengths: list[int]

    @property
    def had_missed_logs(self) -> bool:
        """Whether any cycle start went unlogged."""
        return len(self.observed_lengths) < len(self.true_lengths)


def sample_population(
    n_users: int,
    rng: np.random.Generator,
    *,
    mean_cycle_days: float = 29.0,
    level_sd_log: float = 0.10,
    irregular_fraction: float = 0.25,
) -> list[UserSpec]:
    """Draw a population of user parameters.

    The `irregular_fraction` is the point of this function. A population that is
    just Gaussian noise around 29 days would make the model look far better than
    it is, and would hide exactly the failure that matters: people with PCOS,
    perimenopause or thyroid conditions are the ones a cycle predictor serves
    worst, and they must be represented (risk R3).

    Args:
        n_users: How many users to draw.
        rng: Seeded generator.
        mean_cycle_days: Population mean cycle length.
        level_sd_log: Between-user SD of the log level.
        irregular_fraction: Share of users drawn from the high-variability
            component.

    Returns:
        One `UserSpec` per user.
    """
    if n_users <= 0:
        raise ValueError(f"n_users must be positive, got {n_users}")
    if not 0.0 <= irregular_fraction <= 1.0:
        raise ValueError(f"irregular_fraction must be in [0, 1], got {irregular_fraction}")

    centre = math.log(mean_cycle_days)
    specs: list[UserSpec] = []
    for user_id in range(n_users):
        irregular = bool(rng.random() < irregular_fraction)
        if irregular:
            obs_sd = float(rng.uniform(0.10, 0.24))
            drift_sd = float(rng.uniform(0.010, 0.045))
            long_rate = float(rng.uniform(0.05, 0.20))
        else:
            obs_sd = float(rng.uniform(0.025, 0.075))
            drift_sd = float(rng.uniform(0.004, 0.020))
            long_rate = float(rng.uniform(0.0, 0.03))
        specs.append(
            UserSpec(
                user_id=user_id,
                log_level=float(rng.normal(centre, level_sd_log)),
                obs_sd=obs_sd,
                drift_sd=drift_sd,
                long_cycle_rate=long_rate,
                missed_log_rate=float(rng.uniform(0.0, 0.04)),
            )
        )
    return specs


def simulate_user(spec: UserSpec, n_cycles: int, rng: np.random.Generator) -> SimulatedUser:
    """Simulate one user's cycle history.

    Args:
        spec: Generating parameters.
        n_cycles: How many true cycles to generate.
        rng: Seeded generator.

    Returns:
        The simulated user, with both truth and observations.
    """
    if n_cycles <= 0:
        raise ValueError(f"n_cycles must be positive, got {n_cycles}")

    level = spec.log_level
    true_lengths: list[int] = []
    for _ in range(n_cycles):
        level += float(rng.normal(0.0, spec.drift_sd))
        length = math.exp(level + float(rng.normal(0.0, spec.obs_sd)))
        if rng.random() < spec.long_cycle_rate:
            # An anovulatory-style cycle: the follicular phase stretches, so the
            # extension is additive in days rather than multiplicative.
            length += float(rng.uniform(10.0, 45.0))
        true_lengths.append(_clamp_days(length))

    return SimulatedUser(
        spec=spec,
        true_lengths=true_lengths,
        observed_lengths=_apply_missed_logs(true_lengths, spec.missed_log_rate, rng),
    )


def simulate_population(
    specs: list[UserSpec], n_cycles: int, rng: np.random.Generator
) -> list[SimulatedUser]:
    """Simulate a whole population, one history per spec."""
    return [simulate_user(spec, n_cycles, rng) for spec in specs]


def _clamp_days(length: float) -> int:
    """Round to whole days and clamp to the plausible range.

    Uses `floor(x + 0.5)` for consistency with the filter's rounding rule, so that
    a simulated length and a predicted length are quantised identically.
    """
    days = math.floor(length + 0.5)
    return max(MIN_PLAUSIBLE_DAYS, min(MAX_PLAUSIBLE_DAYS, days))


def _apply_missed_logs(
    true_lengths: list[int], missed_rate: float, rng: np.random.Generator
) -> list[int]:
    """Merge cycles whose start was never logged.

    A missed start is not a lost cycle: the app sees one long cycle spanning both.
    That is the single most common real data defect, and it is what puts
    observations into implausibly-long territory for the validation path to catch.

    The final cycle is never merged forward, because there is nothing after it to
    merge with.
    """
    if missed_rate <= 0.0 or len(true_lengths) < 2:
        return list(true_lengths)

    observed: list[int] = []
    carry = 0
    for index, length in enumerate(true_lengths):
        is_last = index == len(true_lengths) - 1
        if not is_last and rng.random() < missed_rate:
            # This cycle's *end* went unlogged, so it merges into the next one.
            carry += length
            continue
        observed.append(min(MAX_PLAUSIBLE_DAYS, carry + length))
        carry = 0
    return observed
