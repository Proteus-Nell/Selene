"""The plain-arithmetic Student-t functions, held to SciPy.

`student_t` exists so the app can read quantiles at levels nobody can list in
advance without shipping a special-functions library. It is only worth having if
it agrees with SciPy, which is what these tests pin, across the degrees of
freedom the model could plausibly be fitted with and well into both tails.
"""

from __future__ import annotations

import math

import pytest
from scipy import special, stats

from cyclecore.config import PopulationConfig
from cyclecore.models.intervals import student_t_quantiles
from cyclecore.models.student_t import incomplete_beta, log_gamma, t_cdf, t_ppf

DFS = [1.0, 2.5, 4.0, 7.0, 30.0]
POINTS = [-80.0, -20.0, -6.0, -2.0, -1.0, -0.3, 0.0, 0.05, 0.7, 1.5, 3.0, 9.0, 150.0]
LEVELS = [1e-9, 1e-6, 0.001, 0.05, 0.1, 0.25, 0.5, 0.6, 0.75, 0.9, 0.99, 0.999999]


@pytest.mark.parametrize("x", [1e-6, 0.1, 0.25, 0.49, 0.5, 1.0, 1.5, 2.0, 2.5, 10.0, 171.5])
def test_log_gamma_matches_scipy(x: float) -> None:
    assert log_gamma(x) == pytest.approx(special.gammaln(x), rel=1e-12, abs=1e-12)


@pytest.mark.parametrize("x", [0.0, -1.0])
def test_log_gamma_refuses_a_non_positive_argument(x: float) -> None:
    with pytest.raises(ValueError, match="positive"):
        log_gamma(x)


@pytest.mark.parametrize(("a", "b"), [(2.0, 0.5), (0.5, 0.5), (15.0, 0.5), (3.0, 7.0)])
@pytest.mark.parametrize("x", [1e-12, 1e-4, 0.1, 0.4, 0.5, 0.77, 0.99])
def test_incomplete_beta_matches_scipy(x: float, a: float, b: float) -> None:
    assert incomplete_beta(x, a, b) == pytest.approx(special.betainc(a, b, x), abs=1e-14)


@pytest.mark.parametrize("x", [1e-12, 1e-4, 0.1, 0.5, 0.99, 1.0 - 1e-6, 1.0 - 1e-9])
def test_incomplete_beta_matches_its_closed_forms(x: float) -> None:
    # I_x(1/2, 1/2) = (2/pi) asin(sqrt(x)), and I_x(2, 1) = x^2. These referee
    # the points nearest 1, where SciPy's own betainc is off in the twelfth
    # place for the first of them. Each half of the arcsine is taken from the
    # end it is accurate at.
    if x < 0.5:
        arcsine = (2.0 / math.pi) * math.asin(math.sqrt(x))
    else:
        arcsine = 1.0 - (2.0 / math.pi) * math.asin(math.sqrt(1.0 - x))
    assert incomplete_beta(x, 0.5, 0.5) == pytest.approx(arcsine, abs=1e-15)
    assert incomplete_beta(x, 2.0, 1.0) == pytest.approx(x * x, abs=1e-15)


def test_incomplete_beta_is_exact_at_its_ends() -> None:
    assert incomplete_beta(0.0, 2.0, 0.5) == 0.0
    assert incomplete_beta(-0.1, 2.0, 0.5) == 0.0
    assert incomplete_beta(1.0, 2.0, 0.5) == 1.0
    assert incomplete_beta(1.1, 2.0, 0.5) == 1.0


@pytest.mark.parametrize("df", DFS)
@pytest.mark.parametrize("t", POINTS)
def test_cdf_matches_scipy(t: float, df: float) -> None:
    assert t_cdf(t, df) == pytest.approx(stats.t.cdf(t, df), abs=1e-14)


@pytest.mark.parametrize("df", DFS)
def test_cdf_lower_tail_keeps_its_relative_accuracy(df: float) -> None:
    # The lower tail is computed directly rather than as one minus something, so
    # it stays accurate where the probability is tiny. That is where the late
    # windows read from once a period is very late.
    for t in (-6.0, -20.0, -80.0):
        assert t_cdf(t, df) == pytest.approx(stats.t.cdf(t, df), rel=1e-11)


@pytest.mark.parametrize("df", DFS)
def test_cdf_is_symmetric_about_zero(df: float) -> None:
    for t in POINTS:
        assert t_cdf(t, df) + t_cdf(-t, df) == pytest.approx(1.0, abs=1e-15)


@pytest.mark.parametrize("df", DFS)
def test_cdf_never_decreases(df: float) -> None:
    grid = [i / 10.0 for i in range(-200, 201)]
    values = [t_cdf(t, df) for t in grid]
    assert values == sorted(values)


@pytest.mark.parametrize("df", DFS)
@pytest.mark.parametrize("p", LEVELS)
def test_ppf_matches_scipy(p: float, df: float) -> None:
    assert t_ppf(p, df) == pytest.approx(stats.t.ppf(p, df), rel=1e-9, abs=1e-12)


@pytest.mark.parametrize("df", DFS)
@pytest.mark.parametrize("p", LEVELS)
def test_ppf_inverts_the_cdf(p: float, df: float) -> None:
    assert t_cdf(t_ppf(p, df), df) == pytest.approx(p, rel=1e-12, abs=1e-15)


def test_ppf_at_the_median_is_exactly_zero() -> None:
    assert t_ppf(0.5, 4.0) == 0.0


@pytest.mark.parametrize("p", [0.0, 1.0, -0.2, 1.5])
def test_ppf_refuses_a_level_outside_the_open_interval(p: float) -> None:
    with pytest.raises(ValueError, match="strictly between"):
        t_ppf(p, 4.0)


def test_ppf_reproduces_the_shipped_quantile_table() -> None:
    # The fixed windows read from a table SciPy wrote. The windows moved forward
    # read from `t_ppf`. Where the two describe the same quantile they have to
    # agree, or a late period's window would jump on the day it starts to move.
    df = PopulationConfig().to_filter_priors().student_t_df
    table = student_t_quantiles(df)
    for name, value in table.items():
        level = int(name.removeprefix("p")) / 100.0
        assert t_ppf(level, df) == pytest.approx(value, rel=1e-12, abs=1e-15), name
        assert math.isfinite(value)
