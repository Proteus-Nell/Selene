"""The Student-t distribution function and its inverse, in plain arithmetic.

The model's predictive distribution is a Student-t on log cycle length. Its five
fixed quantiles ship as a table (`intervals.student_t_quantiles`, which needs SciPy
and runs offline). Moving a window forward once a period is late needs quantiles at
levels that cannot be listed in advance, because they depend on how many days have
passed. So the distribution function and its inverse are computed here from `math`
alone, by the same steps `app/lib/domain/predict/student_t.dart` takes, and
`tests/test_student_t.py` holds them to SciPy.

Every operation is one the Dart port can repeat exactly: `+ - * /`, `log`, `exp`,
`sin` and `sqrt`. No `log1p`, no `lgamma`, no SciPy.
"""

from __future__ import annotations

import math
from typing import Final

__all__ = [
    "incomplete_beta",
    "log_gamma",
    "t_cdf",
    "t_ppf",
]

_LANCZOS_G: Final[float] = 7.0
_LANCZOS: Final[tuple[float, ...]] = (
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
)
"""Lanczos coefficients for g = 7, n = 9: about 15 correct digits for x >= 0.5."""

_CF_MAX_TERMS: Final[int] = 300
_CF_EPSILON: Final[float] = 1e-15
_CF_TINY: Final[float] = 1e-300
_BISECTION_STEPS: Final[int] = 200


def log_gamma(x: float) -> float:
    """Return ln Γ(x), by the Lanczos approximation.

    Args:
        x: A positive number.

    Returns:
        The natural log of the gamma function at `x`.

    Raises:
        ValueError: When `x` is not positive.
    """
    if x <= 0.0:
        raise ValueError(f"log_gamma needs a positive argument, got {x}")
    if x < 0.5:
        # Reflection, Γ(x) Γ(1 - x) = π / sin(πx), keeps the series where it is
        # accurate.
        return math.log(math.pi / math.sin(math.pi * x)) - log_gamma(1.0 - x)
    x -= 1.0
    total = _LANCZOS[0]
    for i in range(1, len(_LANCZOS)):
        total += _LANCZOS[i] / (x + i)
    t = x + _LANCZOS_G + 0.5
    return 0.5 * math.log(2.0 * math.pi) + (x + 0.5) * math.log(t) - t + math.log(total)


def _beta_continued_fraction(x: float, a: float, b: float) -> float:
    """Evaluate the continued fraction for the incomplete beta function.

    The modified Lentz method, as in Numerical Recipes' `betacf`.
    """
    qab = a + b
    qap = a + 1.0
    qam = a - 1.0
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < _CF_TINY:
        d = _CF_TINY
    d = 1.0 / d
    h = d
    for m in range(1, _CF_MAX_TERMS + 1):
        m2 = 2.0 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < _CF_TINY:
            d = _CF_TINY
        c = 1.0 + aa / c
        if abs(c) < _CF_TINY:
            c = _CF_TINY
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < _CF_TINY:
            d = _CF_TINY
        c = 1.0 + aa / c
        if abs(c) < _CF_TINY:
            c = _CF_TINY
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < _CF_EPSILON:
            break
    return h


def incomplete_beta(x: float, a: float, b: float) -> float:
    """Return the regularized incomplete beta function I_x(a, b).

    Args:
        x: Where to evaluate it, from 0 to 1.
        a: The first shape parameter, positive.
        b: The second shape parameter, positive.

    Returns:
        I_x(a, b), from 0 to 1.
    """
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    # `math.log(1.0 - x)` rather than `math.log1p(-x)`: Dart has no log1p, and the
    # two runtimes have to take the same steps.
    front = math.exp(
        log_gamma(a + b) - log_gamma(a) - log_gamma(b) + a * math.log(x) + b * math.log(1.0 - x)
    )
    if x < (a + 1.0) / (a + b + 2.0):
        return front * _beta_continued_fraction(x, a, b) / a
    return 1.0 - front * _beta_continued_fraction(1.0 - x, b, a) / b


def t_cdf(t: float, df: float) -> float:
    """Return the Student-t distribution function at `t`.

    Args:
        t: The point, in standard units.
        df: Degrees of freedom, positive.

    Returns:
        P(T <= t) for a standard Student-t with `df` degrees of freedom.
    """
    tail = 0.5 * incomplete_beta(df / (df + t * t), 0.5 * df, 0.5)
    return 1.0 - tail if t > 0.0 else tail


def t_ppf(p: float, df: float) -> float:
    """Return the Student-t quantile at level `p`, by bisection on `t_cdf`.

    Bisection rather than Newton's method: slower, but it cannot leave its bracket,
    and it takes the same path in both runtimes.

    Args:
        p: The level, strictly between 0 and 1.
        df: Degrees of freedom, positive.

    Returns:
        The `t` at which `t_cdf(t, df)` is `p`.

    Raises:
        ValueError: When `p` is not strictly between 0 and 1.
    """
    if not 0.0 < p < 1.0:
        raise ValueError(f"t_ppf needs a level strictly between 0 and 1, got {p}")
    if p == 0.5:
        return 0.0
    lo, hi = -1.0, 1.0
    while t_cdf(lo, df) > p:
        lo *= 2.0
    while t_cdf(hi, df) < p:
        hi *= 2.0
    for _ in range(_BISECTION_STEPS):
        mid = 0.5 * (lo + hi)
        if mid in (lo, hi):
            break
        if t_cdf(mid, df) < p:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)
