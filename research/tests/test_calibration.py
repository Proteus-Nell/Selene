"""Interval calibration, the most important gate in this repo.

Measured history, kept because the delta is the argument for the design:

    stratum     cov80 before refit   cov80 after refit   nominal
    pooled              0.78                0.80          0.80
    regular             0.90                0.86          0.80
    irregular           0.41                0.67          0.80

"Before" is the filter running on a single population-level observation variance.
Note that its **pooled** figure was 0.78, two points off nominal, and would have
sailed through a pooled gate at plus or minus three points, while the model was
covering 41% of outcomes for irregular users with an interval labelled 80%. That
is the concrete justification for the plan's rule that metrics are never reported
pooled (risks R3 and R6).

"After" is with the per-user variance refit in `models/personalize.py`, which is
why that module exists. The remaining gap for irregular users is real and still
tracked by the xfail at the bottom: the refit picks from a fixed grid and cannot
represent a user whose variability is itself changing, which is exactly what
perimenopause looks like.
"""

from __future__ import annotations

import pytest

from cyclecore.config import Settings
from cyclecore.data.synthetic import sample_population, simulate_population
from cyclecore.eval.backtest import backtest_population, report_from_rows
from cyclecore.eval.metrics import CalibrationReport, mean_absolute_error
from cyclecore.models.intervals import student_t_quantiles
from cyclecore.seeds import seed_everything

N_USERS = 400
N_CYCLES = 18


@pytest.fixture(scope="module")
def rows() -> list:  # type: ignore[type-arg]
    settings = Settings()
    rng = seed_everything(settings.seed)
    priors = settings.population.to_filter_priors()
    quantiles = student_t_quantiles(priors.student_t_df)
    specs = sample_population(
        N_USERS,
        rng,
        mean_cycle_days=settings.population.mean_cycle_days,
        level_sd_log=settings.population.level_sd_log,
    )
    users = simulate_population(specs, N_CYCLES, rng)
    return backtest_population(users, priors, quantiles, min_history=1)


@pytest.fixture(scope="module")
def pooled(rows: list) -> CalibrationReport:  # type: ignore[type-arg]
    return report_from_rows(rows)


@pytest.fixture(scope="module")
def regular(rows: list) -> CalibrationReport:  # type: ignore[type-arg]
    return report_from_rows([r for r in rows if not r.is_irregular])


@pytest.fixture(scope="module")
def irregular(rows: list) -> CalibrationReport:  # type: ignore[type-arg]
    return report_from_rows([r for r in rows if r.is_irregular])


def test_backtest_produced_enough_data(rows: list) -> None:  # type: ignore[type-arg]
    assert len(rows) > 5000, "too few predictions for coverage estimates to mean anything"


def test_both_strata_are_represented(
    regular: CalibrationReport, irregular: CalibrationReport
) -> None:
    # If the irregular stratum were tiny, the pooled numbers would look good and
    # mean nothing. The generator deliberately makes it about a quarter.
    assert regular.n > 1000
    assert irregular.n > 500


def test_pooled_coverage_still_hides_a_stratum_gap(
    pooled: CalibrationReport,
    regular: CalibrationReport,
    irregular: CalibrationReport,
) -> None:
    """The finding this module exists to record, in its current form.

    Asserts both halves: the pooled figure looks excellent, and it is still
    concealing a material divergence between strata. If someone later "fixes"
    calibration by widening intervals globally, the pooled number stays fine and
    this test still fails, which is the point.
    """
    assert abs(pooled.coverage_80 - 0.80) < 0.05, (
        f"pooled coverage {pooled.coverage_80:.3f} looks fine on its own"
    )
    divergence = abs(regular.coverage_80 - irregular.coverage_80)
    assert 0.08 < divergence < 0.30, (
        f"strata diverge by {divergence:.3f}. Below 0.08 the gap has closed and "
        f"the xfail below should be promoted; above 0.30 something regressed."
    )


def test_regular_stratum_is_at_least_conservatively_covered(
    regular: CalibrationReport,
) -> None:
    # Over-coverage is the safe direction: the window is wider than it needs to be,
    # so the user is told less than the model knows rather than more.
    assert regular.coverage_80 >= 0.80
    assert regular.coverage_50 >= 0.50


def test_irregular_stratum_is_known_to_be_undercovered(
    irregular: CalibrationReport,
) -> None:
    """Pins the current, known-remaining gap so a regression is visible.

    The per-user refit already closed most of it, from 0.41 to 0.67. This test
    holds the rest in view rather than letting it fade into the pooled average.
    """
    assert 0.60 < irregular.coverage_80 < 0.77, (
        f"irregular coverage_80 is {irregular.coverage_80:.3f}, against a nominal "
        f"0.80. The per-user refit lifted this from 0.41; closing the rest needs a "
        f"variance model that can itself change over time. If this passes 0.77, "
        f"promote the xfail test below."
    )


def test_point_accuracy_is_much_worse_for_irregular_users(
    regular: CalibrationReport, irregular: CalibrationReport
) -> None:
    assert irregular.mae_days > regular.mae_days * 2


def test_the_filter_beats_every_baseline_on_point_error(
    rows: list,  # type: ignore[type-arg]
) -> None:
    """If it cannot beat median-of-6, the honest move is to ship the arithmetic."""
    actual = [r.actual_days for r in rows]
    filter_mae = mean_absolute_error(actual, [r.predicted_days for r in rows])
    for name, predicted in (
        ("last_cycle", [r.baseline_last for r in rows]),
        ("mean_of_3", [r.baseline_mean3 for r in rows]),
        ("median_of_6", [r.baseline_median6 for r in rows]),
    ):
        baseline_mae = mean_absolute_error(actual, predicted)
        assert filter_mae < baseline_mae, (
            f"filter MAE {filter_mae:.3f} does not beat {name} at {baseline_mae:.3f}"
        )


def test_intervals_are_never_inverted(rows: list) -> None:  # type: ignore[type-arg]
    for row in rows:
        assert row.lo80 <= row.lo50 <= row.predicted_days <= row.hi50 <= row.hi80


def test_coverage_improves_with_history(rows: list) -> None:  # type: ignore[type-arg]
    """Sanity check that observing more cycles helps at all."""
    sparse = [r for r in rows if r.n_history <= 2]
    rich = [r for r in rows if r.n_history >= 10]
    assert sparse and rich
    sparse_mae = mean_absolute_error(
        [r.actual_days for r in sparse], [r.predicted_days for r in sparse]
    )
    rich_mae = mean_absolute_error([r.actual_days for r in rich], [r.predicted_days for r in rich])
    assert rich_mae < sparse_mae


@pytest.mark.xfail(
    reason=(
        "The per-user grid refit closed most of the gap (irregular coverage_80 "
        "0.41 -> 0.67) but not all of it. A fixed grid cannot represent a user "
        "whose variability is itself changing over time, which is what "
        "perimenopause looks like. Closing the rest needs a time-varying variance, "
        "not a wider grid. When this starts passing, delete "
        "test_irregular_stratum_is_known_to_be_undercovered and tighten the "
        "divergence assertion."
    ),
    strict=True,
)
def test_target_every_stratum_within_three_points_of_nominal(
    regular: CalibrationReport, irregular: CalibrationReport
) -> None:
    tolerance = 0.03
    for label, report in (("regular", regular), ("irregular", irregular)):
        assert abs(report.coverage_80 - 0.80) <= tolerance, f"{label} stratum"
        assert abs(report.coverage_50 - 0.50) <= tolerance, f"{label} stratum"
