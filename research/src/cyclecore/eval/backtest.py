"""Rolling-origin backtesting, per user.

Rolling origin rather than a random split, and per user rather than pooled. Both
matter: a random split would let a model see a user's later cycles while
predicting an earlier one, and pooling would hide that accuracy collapses for the
users with the most variable cycles, who are precisely the ones the app serves
worst (risk R3).
"""

from __future__ import annotations

from dataclasses import dataclass

from cyclecore.data.synthetic import SimulatedUser
from cyclecore.eval.metrics import CalibrationReport, summarise_calibration
from cyclecore.models.baselines import last_cycle, mean_of_n, median_of_n
from cyclecore.models.bayes_filter import FilterPriors, filter_sequence
from cyclecore.models.intervals import windows_from_state
from cyclecore.models.personalize import PERSONALIZE_MIN_CYCLES, refit_user

__all__ = ["BacktestRow", "backtest_population", "backtest_user", "report_from_rows"]


@dataclass(frozen=True, slots=True)
class BacktestRow:
    """One evaluated prediction.

    Attributes:
        user_id: Which simulated user.
        is_irregular: Whether the user came from the irregular population
            component. Kept per row so metrics can be stratified rather than
            pooled.
        n_history: Cycles of history available when the prediction was made.
        actual_days: What the next cycle actually was.
        predicted_days: Filter prediction at the predictive median.
        lo50: Lower bound of the 50% window.
        hi50: Upper bound of the 50% window.
        lo80: Lower bound of the 80% window.
        hi80: Upper bound of the 80% window.
        baseline_last: Prediction from the last-cycle baseline.
        baseline_mean3: Prediction from the mean of the last three cycles.
        baseline_median6: Prediction from the median of the last six cycles.
    """

    user_id: int
    is_irregular: bool
    n_history: int
    actual_days: int
    predicted_days: int
    lo50: int
    hi50: int
    lo80: int
    hi80: int
    baseline_last: int
    baseline_mean3: int
    baseline_median6: int


def backtest_user(
    user: SimulatedUser,
    priors: FilterPriors,
    t_quantiles: dict[str, float],
    *,
    min_history: int = 1,
    refit_every: int = 5,
) -> list[BacktestRow]:
    """Evaluate every prediction this user's history supports.

    Walks forward one cycle at a time. At each step the filter has seen exactly the
    cycles before the one being predicted, and nothing after it.

    Args:
        user: The simulated history. Only `observed_lengths` is read, never
            `true_lengths`, which would be leakage.
        priors: Population constants.
        t_quantiles: Shipped quantile table.
        min_history: Cycles of history before the first evaluated prediction. The
            default of 1 deliberately evaluates the very sparse regime, because
            that is where a new user actually lives.
        refit_every: How often the per-user variance refit runs, in cycles. Mirrors
            the app, which refits periodically rather than on every log so the
            interval width does not visibly jitter between cycles.

    Returns:
        One row per evaluated prediction, possibly empty for a very short history.
    """
    observed = user.observed_lengths
    rows: list[BacktestRow] = []

    # Personalised priors, refreshed every `refit_every` cycles rather than every
    # cycle, mirroring what the app does on device.
    current = priors
    for index, length in enumerate(observed):
        history = observed[:index]
        if index >= PERSONALIZE_MIN_CYCLES and (index - PERSONALIZE_MIN_CYCLES) % refit_every == 0:
            current = refit_user(history, priors).priors

        if index >= min_history:
            state = filter_sequence(history, current)[-1]
            windows = windows_from_state(state, current, t_quantiles)
            rows.append(
                BacktestRow(
                    user_id=user.spec.user_id,
                    is_irregular=user.spec.is_irregular,
                    n_history=index,
                    actual_days=length,
                    predicted_days=windows.median_days,
                    lo50=windows.lo50,
                    hi50=windows.hi50,
                    lo80=windows.lo80,
                    hi80=windows.hi80,
                    baseline_last=last_cycle(history) or windows.median_days,
                    baseline_mean3=mean_of_n(history, 3) or windows.median_days,
                    baseline_median6=median_of_n(history, 6) or windows.median_days,
                )
            )
    return rows


def backtest_population(
    users: list[SimulatedUser],
    priors: FilterPriors,
    t_quantiles: dict[str, float],
    *,
    min_history: int = 1,
    refit_every: int = 5,
) -> list[BacktestRow]:
    """Run `backtest_user` across a population and concatenate the rows."""
    rows: list[BacktestRow] = []
    for user in users:
        rows.extend(
            backtest_user(
                user, priors, t_quantiles, min_history=min_history, refit_every=refit_every
            )
        )
    return rows


def report_from_rows(rows: list[BacktestRow]) -> CalibrationReport:
    """Summarise backtest rows into a calibration report."""
    if not rows:
        raise ValueError("cannot report on an empty backtest")
    return summarise_calibration(
        actual=[r.actual_days for r in rows],
        predicted=[r.predicted_days for r in rows],
        lower_50=[r.lo50 for r in rows],
        upper_50=[r.hi50 for r in rows],
        lower_80=[r.lo80 for r in rows],
        upper_80=[r.hi80 for r in rows],
    )
