"""Windows moved forward once a period is late.

Properties rather than numbers, as in `test_bayes_filter`: the golden file pins
the numbers for the Dart port, and these say what the numbers must mean.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import pytest
from scipy import stats

from cyclecore.config import PopulationConfig
from cyclecore.data.synthetic import sample_population, simulate_population
from cyclecore.eval.backtest import LATE_POINTS, LateRow, backtest_late_population
from cyclecore.export.golden_vectors import build_conditioned_payload, conditioned_cases
from cyclecore.models.bayes_filter import (
    FilterPriors,
    Forecast,
    days_from_log,
    filter_sequence,
    forecast,
)
from cyclecore.models.intervals import (
    PredictionWindows,
    conditioned_windows,
    student_t_quantiles,
    windows_for_history,
)
from cyclecore.seeds import seed_everything


@pytest.fixture
def priors() -> FilterPriors:
    return PopulationConfig().to_filter_priors()


def _forecast_for(lengths: list[int], priors: FilterPriors) -> Forecast:
    _, refit = windows_for_history(lengths, priors, student_t_quantiles(priors.student_t_df))
    return forecast(filter_sequence(lengths, refit.priors)[-1], refit.priors)


GOLDEN = Path(__file__).resolve().parents[2] / "artifacts" / "golden" / "predictor_cases_v1.json"

HISTORIES = [
    [28, 28, 28, 28, 28, 28],
    [27, 30, 26, 29, 31, 28],
    [22, 35, 41, 26, 48, 30],
    [28],
]


@pytest.mark.parametrize("lengths", HISTORIES)
def test_on_the_first_day_nothing_moves(lengths: list[int], priors: FilterPriors) -> None:
    # A cycle at least one day long is no evidence at all, so the windows must
    # be the ones the fixed quantile table gives, to the day.
    fixed, _ = windows_for_history(lengths, priors, student_t_quantiles(priors.student_t_df))
    fc = _forecast_for(lengths, priors)
    assert conditioned_windows(fc, 1, priors.student_t_df) == fixed


@pytest.mark.parametrize("lengths", HISTORIES)
def test_matches_the_same_conditioning_done_with_scipy(
    lengths: list[int], priors: FilterPriors
) -> None:
    df = priors.student_t_df
    fc = _forecast_for(lengths, priors)
    for elapsed in range(1, 100):
        below = stats.t.cdf((math.log(elapsed - 0.5) - fc.mean) / fc.scale, df)

        def day(level: float, below: float = below) -> int:
            t = stats.t.ppf(below + level * (1.0 - below), df)
            return days_from_log(fc.mean + fc.scale * t)

        expected = PredictionWindows(
            median_days=day(0.50),
            lo50=day(0.25),
            hi50=day(0.75),
            lo80=day(0.10),
            hi80=day(0.90),
        )
        assert conditioned_windows(fc, elapsed, df) == expected, elapsed


@pytest.mark.parametrize("lengths", HISTORIES)
def test_no_day_is_before_the_day_already_reached(lengths: list[int], priors: FilterPriors) -> None:
    fc = _forecast_for(lengths, priors)
    for elapsed in range(1, 120):
        w = conditioned_windows(fc, elapsed, priors.student_t_df)
        assert w.lo80 >= elapsed, elapsed
        assert w.lo80 <= w.lo50 <= w.median_days <= w.hi50 <= w.hi80, elapsed


@pytest.mark.parametrize("lengths", HISTORIES)
def test_windows_only_move_forward(lengths: list[int], priors: FilterPriors) -> None:
    fc = _forecast_for(lengths, priors)
    previous = conditioned_windows(fc, 1, priors.student_t_df)
    for elapsed in range(2, 120):
        current = conditioned_windows(fc, elapsed, priors.student_t_df)
        assert current.lo80 >= previous.lo80, elapsed
        assert current.median_days >= previous.median_days, elapsed
        assert current.hi80 >= previous.hi80, elapsed
        previous = current


def test_a_late_period_widens_the_window(priors: FilterPriors) -> None:
    # The longer it has been, the less a regular history says about when it
    # will come. A window that stayed as narrow as before would claim knowledge
    # the model no longer has.
    fc = _forecast_for([28] * 6, priors)
    on_time = conditioned_windows(fc, 1, priors.student_t_df)
    late = conditioned_windows(fc, 40, priors.student_t_df)
    assert late.hi80 - late.lo80 > on_time.hi80 - on_time.lo80


def test_refuses_a_day_before_the_cycle_started(priors: FilterPriors) -> None:
    fc = _forecast_for([28], priors)
    with pytest.raises(ValueError, match="at least 1"):
        conditioned_windows(fc, 0, priors.student_t_df)


def test_refuses_when_no_probability_is_left(priors: FilterPriors) -> None:
    # Only a forecast far narrower than the model ever produces gets here, but
    # the function has to say so rather than return a window from nothing.
    fc = Forecast(mean=math.log(28.0), var=1e-12)
    with pytest.raises(ValueError, match=r"strictly between|no probability"):
        conditioned_windows(fc, 60, priors.student_t_df)


class TestConditionedArtifact:
    @pytest.fixture
    def payload(self, priors: FilterPriors) -> dict:  # type: ignore[type-arg]
        return build_conditioned_payload(priors, student_t_quantiles(priors.student_t_df))

    def test_case_names_are_unique(self, payload: dict) -> None:  # type: ignore[type-arg]
        names = [case["name"] for case in payload["cases"]]
        assert len(names) == len(set(names))

    def test_every_history_crosses_its_window(self) -> None:
        # The cut-off is where a port is most likely to be wrong, so each
        # history has days on both sides of the window the app shows for it,
        # which is the one in the committed golden file.
        golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
        shown = {case["name"]: case["day_windows"] for case in golden["cases"]}
        for case, days in conditioned_cases():
            assert min(days) <= shown[case.name]["lo80"], case.name
            assert max(days) > shown[case.name]["hi80"], case.name

    def test_windows_are_ordered_and_not_in_the_past(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        for case in payload["cases"]:
            w = case["day_windows"]
            assert case["elapsed_days"] <= w["lo80"], case["name"]
            assert w["lo80"] <= w["lo50"] <= w["median"] <= w["hi50"] <= w["hi80"]
            assert 0.0 <= case["below"] < 1.0

    def test_distribution_points_are_finite(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        for point in payload["cdf"]:
            assert 0.0 <= point["p"] <= 1.0
        for point in payload["ppf"]:
            assert math.isfinite(point["t"])

    def test_regenerating_is_byte_identical(self, priors: FilterPriors) -> None:
        quantiles = student_t_quantiles(priors.student_t_df)
        first = json.dumps(build_conditioned_payload(priors, quantiles), sort_keys=True)
        second = json.dumps(build_conditioned_payload(priors, quantiles), sort_keys=True)
        assert first == second


class TestLateBacktest:
    """The backtest ADR-0016 quotes: moved windows scored on late cycles."""

    @pytest.fixture(scope="class")
    def rows(self) -> list[LateRow]:
        rng = seed_everything(11)
        priors = PopulationConfig().to_filter_priors()
        users = simulate_population(sample_population(80, rng), 14, rng)
        return backtest_late_population(users, priors, student_t_quantiles(priors.student_t_df))

    def test_found_late_cycles_to_score(self, rows: list[LateRow]) -> None:
        points = {row.point for row in rows}
        assert points <= set(LATE_POINTS)
        assert {"opened", "median", "closed"} <= points

    def test_only_cycles_that_reached_the_day_are_scored(self, rows: list[LateRow]) -> None:
        # A cycle whose period came sooner never put the app in that state.
        assert all(row.actual_days >= row.elapsed_days for row in rows)

    def test_moved_windows_never_reach_back(self, rows: list[LateRow]) -> None:
        for row in rows:
            assert row.elapsed_days <= row.lo80 <= row.lo50 <= row.hi50 <= row.hi80

    def test_later_points_are_later(self, rows: list[LateRow]) -> None:
        # Per cycle, the points are in the order LATE_POINTS names them.
        by_cycle: dict[tuple[int, int], list[LateRow]] = {}
        for row in rows:
            by_cycle.setdefault((row.user_id, row.n_history), []).append(row)
        order = {point: i for i, point in enumerate(LATE_POINTS)}
        for cycle in by_cycle.values():
            ranked = sorted(cycle, key=lambda row: order[row.point])
            elapsed = [row.elapsed_days for row in ranked]
            assert elapsed == sorted(elapsed)
