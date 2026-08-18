"""Tests for the per-user variance refit.

This module exists because the filter alone learns a user's mean and never their
variability. See the header of `models/personalize.py` and
`tests/test_calibration.py` for the measurement that forced it.
"""

from __future__ import annotations

import math
from dataclasses import replace

import pytest

from cyclecore.config import PopulationConfig
from cyclecore.models.bayes_filter import FilterPriors
from cyclecore.models.personalize import (
    DEFAULT_DRIFT_SD_GRID,
    DEFAULT_OBS_SD_GRID,
    PERSONALIZE_MIN_CYCLES,
    partial_log_likelihood,
    refit_user,
)


@pytest.fixture
def priors() -> FilterPriors:
    return PopulationConfig().to_filter_priors()


class TestGrids:
    def test_are_strictly_increasing(self) -> None:
        for grid in (DEFAULT_OBS_SD_GRID, DEFAULT_DRIFT_SD_GRID):
            assert list(grid) == sorted(grid)
            assert len(set(grid)) == len(grid)

    def test_are_positive(self) -> None:
        for grid in (DEFAULT_OBS_SD_GRID, DEFAULT_DRIFT_SD_GRID):
            assert all(value > 0 for value in grid)

    def test_obs_grid_spans_regular_to_very_irregular(self) -> None:
        # Roughly 0.6 days to 10 days of variability at a 29 day cycle.
        assert DEFAULT_OBS_SD_GRID[0] <= 0.02
        assert DEFAULT_OBS_SD_GRID[-1] >= 0.30

    def test_grid_is_small_enough_to_run_on_a_phone(self) -> None:
        # The device runs this search, so the whole grid must stay trivial.
        assert len(DEFAULT_OBS_SD_GRID) * len(DEFAULT_DRIFT_SD_GRID) < 200


class TestRefitThreshold:
    def test_short_history_is_not_personalised(self, priors: FilterPriors) -> None:
        for n in range(PERSONALIZE_MIN_CYCLES):
            result = refit_user([28] * n, priors)
            assert not result.personalised
            assert result.priors == priors
            assert result.n_cycles == n

    def test_enough_history_is_personalised(self, priors: FilterPriors) -> None:
        result = refit_user([28] * PERSONALIZE_MIN_CYCLES, priors)
        assert result.personalised
        assert result.obs_sd in DEFAULT_OBS_SD_GRID
        assert result.drift_sd in DEFAULT_DRIFT_SD_GRID

    def test_threshold_is_five(self) -> None:
        # Encoded in the plan and in the app copy, so pin it here too.
        assert PERSONALIZE_MIN_CYCLES == 5


class TestRefitRecoversVariability:
    def test_regular_user_gets_a_small_obs_sd(self, priors: FilterPriors) -> None:
        result = refit_user([28, 28, 29, 28, 28, 29, 28, 28], priors)
        assert result.obs_sd <= 0.06

    def test_irregular_user_gets_a_large_obs_sd(self, priors: FilterPriors) -> None:
        result = refit_user([24, 35, 28, 42, 31, 26, 39, 23], priors)
        assert result.obs_sd >= 0.10

    def test_obs_sd_increases_with_spread(self, priors: FilterPriors) -> None:
        selected: list[float] = []
        for spread in (0, 1, 3, 6, 10):
            history = [28 - spread, 28 + spread] * 5
            selected.append(refit_user(history, priors).obs_sd)
        assert selected == sorted(selected), f"not monotone: {selected}"

    def test_recovers_a_known_generating_sd(self, priors: FilterPriors) -> None:
        """Feed data generated at a known SD and check the fit lands near it."""
        import numpy as np

        rng = np.random.default_rng(7)
        true_sd = 0.09
        centre = math.log(29.0)
        history = [
            max(15, math.floor(math.exp(centre + rng.normal(0, true_sd)) + 0.5)) for _ in range(40)
        ]
        result = refit_user(history, priors)
        assert 0.5 * true_sd <= result.obs_sd <= 2.0 * true_sd


class TestPartialLogLikelihood:
    def test_is_finite(self, priors: FilterPriors) -> None:
        assert math.isfinite(partial_log_likelihood([28, 29, 30], priors))

    def test_empty_history_scores_zero(self, priors: FilterPriors) -> None:
        assert partial_log_likelihood([], priors) == 0.0

    def test_prefers_the_variance_that_matches_the_data(self, priors: FilterPriors) -> None:
        spread = [22, 34, 25, 37, 27, 33, 24, 36]
        tight = replace(priors, obs_var=0.02**2)
        loose = replace(priors, obs_var=0.15**2)
        assert partial_log_likelihood(spread, loose) > partial_log_likelihood(spread, tight)

    def test_prefers_a_tight_variance_on_regular_data(self, priors: FilterPriors) -> None:
        regular = [28, 28, 29, 28, 28, 29, 28, 28]
        tight = replace(priors, obs_var=0.03**2)
        loose = replace(priors, obs_var=0.20**2)
        assert partial_log_likelihood(regular, tight) > partial_log_likelihood(regular, loose)

    def test_dropping_the_constant_does_not_change_the_ranking(self, priors: FilterPriors) -> None:
        """The whole portability trick, verified against the full scipy density.

        `partial_log_likelihood` omits the terms of the Student-t density that
        depend only on the degrees of freedom. Since df is fixed across the grid,
        that constant cannot change which candidate wins, which is what lets the
        Dart port avoid `lgamma` entirely.
        """
        from scipy import stats

        from cyclecore.models.bayes_filter import forecast, initial_state, update

        def full_log_likelihood(lengths: list[int], p: FilterPriors) -> float:
            total = 0.0
            state = initial_state(p)
            for length in lengths:
                fc = forecast(state, p)
                total += float(
                    stats.t.logpdf(math.log(length), df=p.student_t_df, loc=fc.mean, scale=fc.scale)
                )
                state = update(state, length, p)
            return total

        history = [26, 31, 28, 34, 27, 30]
        candidates = [replace(priors, obs_var=sd**2) for sd in (0.03, 0.06, 0.12, 0.20)]
        partial_order = sorted(candidates, key=lambda p: partial_log_likelihood(history, p))
        full_order = sorted(candidates, key=lambda p: full_log_likelihood(history, p))
        assert [p.obs_var for p in partial_order] == [p.obs_var for p in full_order]


class TestDeterminism:
    def test_same_input_gives_same_output(self, priors: FilterPriors) -> None:
        history = [26, 31, 28, 34, 27, 30]
        first = refit_user(history, priors)
        second = refit_user(history, priors)
        assert first == second

    def test_ties_resolve_to_the_first_candidate(self, priors: FilterPriors) -> None:
        # Strictly-greater comparison means a tie keeps the earlier, tighter grid
        # point. Both runtimes must agree on that, so it is pinned here.
        history = [28] * 8
        result = refit_user(history, priors, obs_sd_grid=(0.05, 0.05), drift_sd_grid=(0.01, 0.01))
        assert result.obs_sd == 0.05
        assert result.drift_sd == 0.01

    def test_custom_grids_are_respected(self, priors: FilterPriors) -> None:
        result = refit_user([28] * 8, priors, obs_sd_grid=(0.11,), drift_sd_grid=(0.022,))
        assert result.obs_sd == 0.11
        assert result.drift_sd == 0.022
        assert result.priors.obs_var == pytest.approx(0.11**2)
