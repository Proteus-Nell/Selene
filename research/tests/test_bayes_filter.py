"""Behavioural tests for the reference filter.

These assert *properties* rather than magic numbers wherever possible, so they stay
meaningful after a re-fit of the priors changes every constant.
"""

from __future__ import annotations

import math

import pytest

from cyclecore.config import PopulationConfig
from cyclecore.models.bayes_filter import (
    FilterPriors,
    days_from_log,
    filter_sequence,
    forecast,
    initial_state,
    update,
)
from cyclecore.models.intervals import (
    student_t_quantiles,
    windows_for_history,
    windows_from_state,
)


@pytest.fixture
def priors() -> FilterPriors:
    return PopulationConfig().to_filter_priors()


def test_initial_state_is_the_prior(priors: FilterPriors) -> None:
    state = initial_state(priors)
    assert state.n_obs == 0
    assert state.mean == priors.log_mean_center
    assert state.var == priors.log_mean_var


def test_prior_centre_is_near_29_days(priors: FilterPriors) -> None:
    assert days_from_log(initial_state(priors).mean) == 29


def test_update_moves_the_mean_towards_the_observation(priors: FilterPriors) -> None:
    state = initial_state(priors)
    higher = update(state, 34, priors)
    lower = update(state, 24, priors)
    assert higher.mean > state.mean
    assert lower.mean < state.mean


def test_update_reduces_level_variance(priors: FilterPriors) -> None:
    state = initial_state(priors)
    after = update(state, 28, priors)
    assert after.var < state.var, "an observation must reduce uncertainty about the level"


def test_variance_decreases_monotonically_on_a_regular_history(
    priors: FilterPriors,
) -> None:
    states = filter_sequence([28] * 10, priors)
    variances = [s.var for s in states]
    assert variances == sorted(variances, reverse=True)


def test_level_variance_never_reaches_zero(priors: FilterPriors) -> None:
    # A collapsed variance would mean absolute certainty about the next date,
    # which is the overconfidence failure this project cares most about (risk R6).
    states = filter_sequence([28] * 200, priors)
    assert states[-1].var > 0


def test_forecast_variance_exceeds_level_variance(priors: FilterPriors) -> None:
    state = filter_sequence([28] * 6, priors)[-1]
    fc = forecast(state, priors)
    assert fc.var > state.var, "prediction must add drift and observation noise"
    assert fc.scale == pytest.approx(math.sqrt(fc.var))


def test_outlier_widens_the_interval_rather_than_shifting_the_mean(
    priors: FilterPriors,
) -> None:
    """The single most important property of the robust observation model.

    A Gaussian observation model passes almost every other test in this file and
    fails this one, which is exactly why it is here.
    """
    settled = [28, 29, 28, 29, 28]
    quantiles = student_t_quantiles(priors.student_t_df)

    without = filter_sequence(settled, priors)[-1]
    with_outlier = filter_sequence([*settled, 55], priors)[-1]

    w_without = windows_from_state(without, priors, quantiles)
    w_with = windows_from_state(with_outlier, priors, quantiles)

    assert w_with.width80 > w_without.width80, "the outlier must widen the window"

    # The mean must move, since ignoring data entirely would be wrong, but it must
    # move far less than the outlier itself demands.
    naive_shift = math.log(55) - without.mean
    actual_shift = with_outlier.mean - without.mean
    assert 0 < actual_shift < naive_shift * 0.5


def test_a_gaussian_would_chase_the_outlier(priors: FilterPriors) -> None:
    """Contrast case proving the robustness term is doing real work.

    Sets the degrees of freedom very high, which makes the Student-t weight tend to
    1 and the filter effectively Gaussian, then shows the mean moves further.
    """
    from dataclasses import replace

    settled = [28, 29, 28, 29, 28]
    gaussian_like = replace(priors, student_t_df=1e6)

    robust = filter_sequence([*settled, 55], priors)[-1]
    gaussian = filter_sequence([*settled, 55], gaussian_like)[-1]

    assert gaussian.mean > robust.mean


def test_min_obs_var_floors_the_effective_variance(priors: FilterPriors) -> None:
    from dataclasses import replace

    floored = replace(priors, min_obs_var=0.01)
    unfloored = replace(priors, min_obs_var=1e-12)
    quantiles = student_t_quantiles(priors.student_t_df)

    a = windows_from_state(filter_sequence([28] * 12, floored)[-1], floored, quantiles)
    b = windows_from_state(filter_sequence([28] * 12, unfloored)[-1], unfloored, quantiles)
    assert a.width80 >= b.width80


def test_update_rejects_non_positive_lengths(priors: FilterPriors) -> None:
    state = initial_state(priors)
    for bad in (0, -1, -28):
        with pytest.raises(ValueError, match="must be positive"):
            update(state, bad, priors)


def test_filter_sequence_returns_prior_plus_one_state_per_observation(
    priors: FilterPriors,
) -> None:
    lengths = [28, 29, 30]
    states = filter_sequence(lengths, priors)
    assert len(states) == len(lengths) + 1
    assert [s.n_obs for s in states] == [0, 1, 2, 3]


def test_filter_sequence_on_empty_history(priors: FilterPriors) -> None:
    states = filter_sequence([], priors)
    assert len(states) == 1
    assert states[0] == initial_state(priors)


class TestDaysFromLog:
    """Rounding must be half-away-from-zero, matching the Dart port exactly."""

    def test_exact_values(self) -> None:
        assert days_from_log(math.log(28.0)) == 28
        assert days_from_log(math.log(1.0)) == 1

    def test_rounds_half_up_not_to_even(self) -> None:
        # Python's built-in round() would give 28 for 28.5 and 30 for 29.5,
        # because it rounds half to even. Dart's .round() gives 29 and 30.
        # floor(x + 0.5) gives 29 and 30, matching Dart.
        assert days_from_log(math.log(28.5)) == 29
        assert days_from_log(math.log(29.5)) == 30
        assert round(28.5) == 28, "documents the builtin we are deliberately avoiding"

    def test_rounds_down_below_half(self) -> None:
        assert days_from_log(math.log(28.49)) == 28

    def test_monotonic(self) -> None:
        previous = 0
        for days in range(1, 200):
            current = days_from_log(math.log(float(days)))
            assert current >= previous
            previous = current


class TestWindows:
    def test_windows_nest_correctly(self, priors: FilterPriors) -> None:
        quantiles = student_t_quantiles(priors.student_t_df)
        for lengths in ([], [28], [28, 30], [24, 35, 28, 42], [28] * 20):
            state = filter_sequence(list(lengths), priors)[-1]
            windows = windows_from_state(state, priors, quantiles)
            assert windows.is_coherent, f"incoherent windows for {lengths}"
            assert windows.width50 <= windows.width80

    def test_regular_history_narrows_the_window(self, priors: FilterPriors) -> None:
        quantiles = student_t_quantiles(priors.student_t_df)
        cold = windows_from_state(initial_state(priors), priors, quantiles)
        warm = windows_from_state(filter_sequence([28] * 12, priors)[-1], priors, quantiles)
        assert warm.width80 < cold.width80

    def test_irregular_history_is_wider_than_regular(self, priors: FilterPriors) -> None:
        # Uses the personalised pipeline, because that is what the app runs. With
        # only the population variance the two widths are identical: the filter
        # would have learned the user's mean but not their variability.
        quantiles = student_t_quantiles(priors.student_t_df)
        regular, _ = windows_for_history([28, 28, 29, 28, 29, 28], priors, quantiles)
        irregular, _ = windows_for_history([24, 35, 28, 42, 31, 26], priors, quantiles)
        assert irregular.width80 > regular.width80

    def test_without_personalisation_the_widths_collapse_together(
        self, priors: FilterPriors
    ) -> None:
        """Documents exactly what personalisation buys, and why it is required."""
        quantiles = student_t_quantiles(priors.student_t_df)
        regular, _ = windows_for_history(
            [28, 28, 29, 28, 29, 28], priors, quantiles, personalise=False
        )
        irregular, _ = windows_for_history(
            [24, 35, 28, 42, 31, 26], priors, quantiles, personalise=False
        )
        assert irregular.width80 == regular.width80


def test_student_t_quantiles_are_symmetric_and_ordered() -> None:
    q = student_t_quantiles(4.0)
    assert q["p50"] == pytest.approx(0.0, abs=1e-12)
    assert q["p10"] == pytest.approx(-q["p90"])
    assert q["p25"] == pytest.approx(-q["p75"])
    assert q["p10"] < q["p25"] < q["p50"] < q["p75"] < q["p90"]


def test_student_t_has_heavier_tails_than_normal() -> None:
    # The reason for choosing df=4: its 90th percentile sits beyond the normal's
    # 1.2816, so the same nominal interval is wider.
    assert student_t_quantiles(4.0)["p90"] > 1.2816
