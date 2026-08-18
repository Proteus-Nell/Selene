"""The "overfit on one batch" analogue for a Bayesian filter.

The classic sanity check for a trained network is that it can drive the loss to
zero on a single batch. A filter has no loss to minimise, so the equivalent
question is: fed an unambiguous signal, does the posterior converge to the right
answer and tighten, and fed a genuinely ambiguous one, does it correctly refuse to
tighten?

The second half is the part that catches real bugs. A filter that narrows on
everything looks great on the first test and is dangerously wrong.
"""

from __future__ import annotations

import math

import pytest

from cyclecore.config import PopulationConfig
from cyclecore.models.bayes_filter import FilterPriors, filter_sequence
from cyclecore.models.intervals import (
    student_t_quantiles,
    windows_for_history,
    windows_from_state,
)


@pytest.fixture
def priors() -> FilterPriors:
    return PopulationConfig().to_filter_priors()


@pytest.fixture
def quantiles(priors: FilterPriors) -> dict[str, float]:
    return student_t_quantiles(priors.student_t_df)


def test_constant_28_converges_to_28(priors: FilterPriors) -> None:
    state = filter_sequence([28] * 10, priors)[-1]
    assert state.mean == pytest.approx(math.log(28.0), abs=0.005)


def test_constant_28_predicts_28(priors: FilterPriors, quantiles: dict[str, float]) -> None:
    windows = windows_from_state(filter_sequence([28] * 10, priors)[-1], priors, quantiles)
    assert windows.median_days == 28


def test_constant_28_narrows_the_interval(
    priors: FilterPriors, quantiles: dict[str, float]
) -> None:
    cold = windows_from_state(filter_sequence([], priors)[-1], priors, quantiles)
    warm = windows_from_state(filter_sequence([28] * 10, priors)[-1], priors, quantiles)
    assert warm.width80 < cold.width80
    assert warm.width80 <= 8, "ten identical cycles should give a reasonably tight window"


def test_convergence_holds_for_several_constant_lengths(priors: FilterPriors) -> None:
    for length in (21, 25, 28, 31, 35):
        state = filter_sequence([length] * 15, priors)[-1]
        assert state.mean == pytest.approx(math.log(float(length)), abs=0.01), (
            f"failed to converge on a constant {length} day history"
        )


def test_alternating_history_widens_rather_than_narrows(
    priors: FilterPriors, quantiles: dict[str, float]
) -> None:
    """The half of this test that actually catches bugs.

    A 26/34 alternation has the same median as a run of 30s but is genuinely
    unpredictable. The interval must be *wider* than for the regular history, not
    narrower, and in particular must be wide enough to contain both arms.
    """
    regular, _ = windows_for_history([30] * 10, priors, quantiles)
    alternating, _ = windows_for_history([26, 34] * 5, priors, quantiles)
    assert alternating.width80 > regular.width80


def test_alternating_history_interval_contains_both_arms(
    priors: FilterPriors, quantiles: dict[str, float]
) -> None:
    windows, refit = windows_for_history([26, 34] * 6, priors, quantiles)
    assert refit.personalised, "twelve cycles must trigger the refit"
    assert windows.lo80 <= 26, f"80% window {windows} excludes the short arm"
    assert windows.hi80 >= 34, f"80% window {windows} excludes the long arm"


def test_increasing_variability_monotonically_widens(
    priors: FilterPriors, quantiles: dict[str, float]
) -> None:
    widths: list[int] = []
    for spread in (0, 1, 3, 6, 10):
        history = [28 - spread, 28 + spread] * 5
        windows, _ = windows_for_history(history, priors, quantiles)
        widths.append(windows.width80)
    assert widths == sorted(widths), f"width must not shrink as spread grows: {widths}"


def test_a_single_cycle_stays_humble(priors: FilterPriors, quantiles: dict[str, float]) -> None:
    """One observation must not produce a confident prediction.

    The app labels this state as not yet personalised, and the model has to agree
    by keeping the interval wide.
    """
    one, one_refit = windows_for_history([28], priors, quantiles)
    many, _ = windows_for_history([28] * 12, priors, quantiles)
    assert not one_refit.personalised, "one cycle is below the refit threshold"
    assert one.width80 > many.width80
