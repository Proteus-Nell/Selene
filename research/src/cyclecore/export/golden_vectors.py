"""Export the cross-runtime golden vectors (task PY-A).

This file produces the artifacts that keep the Python reference and the Dart port
honest (DECISIONS.md ADR-0002): `predictor_cases_v1.json` for the filter and its
windows, and `conditioned_cases_v1.json` for the windows moved forward once a
period is late (ADR-0016). Both `pytest` and `flutter test` assert against them:
floats to `FLOAT_TOLERANCE`, day counts exactly.

Case selection is the whole value here. A golden file covering only the happy path
would pass while the port was broken in every way that matters, so the cases below
target the specific places a reimplementation drifts: the cold start, the first
observation, an outlier that must widen rather than shift, a merged cycle from a
missed log, and an irregular history whose window should be refused.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from cyclecore.models.bayes_filter import (
    FilterPriors,
    filter_sequence,
    forecast,
    predictive_quantile,
)
from cyclecore.models.intervals import (
    QUANTILE_LEVELS,
    conditioned_windows,
    confidence_class,
    windows_for_history,
)
from cyclecore.models.personalize import (
    DEFAULT_DRIFT_SD_GRID,
    DEFAULT_OBS_SD_GRID,
    PERSONALIZE_MIN_CYCLES,
)
from cyclecore.models.student_t import t_cdf, t_ppf

__all__ = [
    "CONDITIONED_SCHEMA_VERSION",
    "FLOAT_TOLERANCE",
    "GOLDEN_SCHEMA_VERSION",
    "GoldenCase",
    "build_conditioned_payload",
    "build_golden_payload",
    "conditioned_cases",
    "golden_cases",
    "write_conditioned",
    "write_golden",
]

GOLDEN_SCHEMA_VERSION = 1
"""Bump on any breaking change to the payload shape."""

CONDITIONED_SCHEMA_VERSION = 1
"""Bump on any breaking change to the conditioned cases' payload shape."""

FLOAT_TOLERANCE = 1e-9
"""Absolute tolerance for float comparisons between runtimes.

Not exact equality, deliberately. `log` and `exp` come from each platform's libm
and may differ in the last bit or two, which is far below this tolerance for the
magnitudes involved. Day counts are compared exactly, because
`floor(exp(x) + 0.5)` is integer-valued and any disagreement there is a real bug.
"""


@dataclass(frozen=True, slots=True)
class GoldenCase:
    """One golden test case.

    Attributes:
        name: Stable identifier, used in test failure messages.
        why: What this case is defending against. Carried into the artifact so a
            future reader knows why a case exists before deleting it.
        cycle_lengths: The observed history fed to the filter.
    """

    name: str
    why: str
    cycle_lengths: list[int]


def golden_cases() -> list[GoldenCase]:
    """Return the golden cases, in a stable order."""
    return [
        GoldenCase(
            name="cold_start_no_cycles",
            why=(
                "A brand new user. Exercises the prior alone, which is the state "
                "the app shows before it has learned anything."
            ),
            cycle_lengths=[],
        ),
        GoldenCase(
            name="single_cycle_28",
            why=(
                "The first observation, where the prior still dominates. A port "
                "that mixes up the predict and update order fails here first."
            ),
            cycle_lengths=[28],
        ),
        GoldenCase(
            name="two_cycles",
            why="Second observation, where the posterior starts to move.",
            cycle_lengths=[28, 30],
        ),
        GoldenCase(
            name="regular_six_identical",
            why=(
                "A perfectly regular history. The interval must narrow but must "
                "not collapse, which is what min_obs_var guards."
            ),
            cycle_lengths=[28, 28, 28, 28, 28, 28],
        ),
        GoldenCase(
            name="regular_six_varied",
            why="A realistic regular user, the common case.",
            cycle_lengths=[27, 29, 28, 30, 28, 29],
        ),
        GoldenCase(
            name="single_outlier_late",
            why=(
                "One 55 day cycle after a settled run. The Student-t weight must "
                "WIDEN the interval rather than drag the mean, which is the whole "
                "reason for the robust observation model. A Gaussian port passes "
                "every other case and fails this one."
            ),
            cycle_lengths=[28, 29, 28, 55, 28, 29],
        ),
        GoldenCase(
            name="outlier_first",
            why=(
                "The outlier arrives before any baseline exists, so it cannot be "
                "recognised as one. Pins the behaviour rather than pretending the "
                "model can tell."
            ),
            cycle_lengths=[55, 28, 29, 28],
        ),
        GoldenCase(
            name="merged_cycle_from_missed_log",
            why=(
                "A 90 day observation standing for two cycles whose middle start "
                "went unlogged. The most common real data defect."
            ),
            cycle_lengths=[28, 29, 90, 28],
        ),
        GoldenCase(
            name="irregular_history",
            why=(
                "Genuinely variable cycles, as in PCOS or perimenopause. The "
                "resulting window should be wide enough to classify as too "
                "irregular rather than falsely confident (risk R17)."
            ),
            cycle_lengths=[24, 35, 28, 42, 31, 26],
        ),
        GoldenCase(
            name="edited_history_one_value_changed",
            why=(
                "Identical to regular_six_varied except one cycle differs. Proves "
                "an edit propagates, which is what prediction cache invalidation "
                "depends on."
            ),
            cycle_lengths=[27, 29, 28, 30, 28, 34],
        ),
        GoldenCase(
            name="short_cycles_at_lower_bound",
            why="Repeated 15 day cycles, the lower end of the plausible band.",
            cycle_lengths=[15, 15, 16, 15],
        ),
        GoldenCase(
            name="long_history_twenty_cycles",
            why=(
                "A long settled history. Catches accumulated drift between the "
                "two implementations, which a short case would hide."
            ),
            cycle_lengths=[
                28,
                29,
                27,
                28,
                30,
                28,
                29,
                28,
                27,
                29,
                28,
                30,
                29,
                28,
                27,
                28,
                29,
                30,
                28,
                28,
            ],
        ),
        GoldenCase(
            name="slow_upward_drift",
            why=(
                "Cycle length migrating steadily upward. Exercises the drift term, "
                "which a port that drops drift_var still passes on flat cases."
            ),
            cycle_lengths=[26, 27, 28, 29, 30, 31, 32, 33],
        ),
    ]


def _case_payload(
    case: GoldenCase,
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> dict[str, Any]:
    # Run the pipeline exactly as the app does: refit first, then filter with the
    # personalised variances. Pinning the un-personalised model would validate the
    # Dart port against a model the app does not actually run.
    windows, refit = windows_for_history(list(case.cycle_lengths), priors, t_quantiles)
    states = filter_sequence(case.cycle_lengths, refit.priors)
    final = states[-1]
    fc = forecast(final, refit.priors)
    return {
        "name": case.name,
        "why": case.why,
        "cycle_lengths": list(case.cycle_lengths),
        "refit": {
            "personalised": refit.personalised,
            "obs_sd": refit.obs_sd,
            "drift_sd": refit.drift_sd,
            "n_cycles": refit.n_cycles,
        },
        # Every intermediate state, not just the last. A port that is subtly wrong
        # from cycle three onward but converges to a similar endpoint is caught
        # here and nowhere else.
        "states": [{"n_obs": s.n_obs, "mean": s.mean, "var": s.var} for s in states],
        "forecast": {"mean": fc.mean, "var": fc.var, "scale": fc.scale},
        "log_quantiles": {
            name: predictive_quantile(fc, t_quantiles[name]) for name in QUANTILE_LEVELS
        },
        # Integer outputs, compared exactly. This is where a rounding-mode
        # mismatch between the runtimes would surface.
        "day_windows": {
            "median": windows.median_days,
            "lo50": windows.lo50,
            "hi50": windows.hi50,
            "lo80": windows.lo80,
            "hi80": windows.hi80,
            "width50": windows.width50,
            "width80": windows.width80,
        },
        "confidence": confidence_class(windows.width80),
    }


def build_golden_payload(
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> dict[str, Any]:
    """Assemble the golden vectors artifact.

    Deterministic by construction: no timestamp, no git SHA, no randomness. See the
    determinism note in `priors_json`.
    """
    return {
        "schema_version": GOLDEN_SCHEMA_VERSION,
        "generated_by": "cyclecore.export.golden_vectors",
        "float_tolerance": FLOAT_TOLERANCE,
        "priors_used": {
            "log_mean_center": priors.log_mean_center,
            "log_mean_var": priors.log_mean_var,
            "obs_var": priors.obs_var,
            "drift_var": priors.drift_var,
            "student_t_df": priors.student_t_df,
            "min_obs_var": priors.min_obs_var,
        },
        "t_quantiles": dict(t_quantiles),
        "personalisation": {
            "min_cycles": PERSONALIZE_MIN_CYCLES,
            "obs_sd_grid": list(DEFAULT_OBS_SD_GRID),
            "drift_sd_grid": list(DEFAULT_DRIFT_SD_GRID),
        },
        "cases": [_case_payload(case, priors, t_quantiles) for case in golden_cases()],
    }


def write_golden(
    path: Path,
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> dict[str, Any]:
    """Write the golden vectors to `path`, creating parent directories.

    Returns:
        The payload that was written.
    """
    payload = build_golden_payload(priors, t_quantiles)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload


def conditioned_cases() -> list[tuple[GoldenCase, list[int]]]:
    """Return the histories whose windows are moved forward, and the days to move them to.

    Each history is paired with days from the 80% window's opening to well past
    it: the day the window opens, its median, its last day, a few days late, and
    weeks late. The cut-off is what the Dart port is most likely to get wrong, so
    every case crosses it.
    """
    by_name = {case.name: case for case in golden_cases()}
    return [
        (by_name["regular_six_identical"], [27, 28, 29, 30, 34, 45, 63]),
        (by_name["regular_six_varied"], [26, 29, 31, 33, 40, 62]),
        (by_name["irregular_history"], [20, 22, 31, 38, 45, 60, 80]),
        (by_name["short_cycles_at_lower_bound"], [14, 15, 17, 21, 40]),
        (by_name["single_cycle_28"], [22, 28, 36, 50, 89]),
    ]


def build_conditioned_payload(
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> dict[str, Any]:
    """Assemble the conditioned windows artifact.

    Two kinds of case. The distribution function and its inverse at fixed points,
    so a port that drifts in `student_t` is caught where it drifts; and windows
    moved forward for real histories, compared to the day.
    """
    df = priors.student_t_df
    cdf_points = [-60.0, -14.0, -4.5, -1.5, -0.25, 0.0, 0.4, 1.53, 3.0, 9.0, 120.0]
    ppf_levels = [1e-6, 0.001, 0.1, 0.25, 0.5, 0.75, 0.9, 0.999, 0.99991]
    cases = []
    for case, days in conditioned_cases():
        _, refit = windows_for_history(list(case.cycle_lengths), priors, t_quantiles)
        final = filter_sequence(case.cycle_lengths, refit.priors)[-1]
        fc = forecast(final, refit.priors)
        for elapsed in days:
            windows = conditioned_windows(fc, elapsed, df)
            below = t_cdf((math.log(elapsed - 0.5) - fc.mean) / fc.scale, df)
            cases.append(
                {
                    "name": f"{case.name}_day_{elapsed}",
                    "forecast": {"mean": fc.mean, "var": fc.var},
                    "elapsed_days": elapsed,
                    "below": below,
                    "day_windows": {
                        "median": windows.median_days,
                        "lo50": windows.lo50,
                        "hi50": windows.hi50,
                        "lo80": windows.lo80,
                        "hi80": windows.hi80,
                    },
                }
            )
    return {
        "schema_version": CONDITIONED_SCHEMA_VERSION,
        "generated_by": "cyclecore.export.golden_vectors",
        "float_tolerance": FLOAT_TOLERANCE,
        "student_t_df": df,
        "cdf": [{"t": t, "p": t_cdf(t, df)} for t in cdf_points],
        "ppf": [{"p": level, "t": t_ppf(level, df)} for level in ppf_levels],
        "cases": cases,
    }


def write_conditioned(
    path: Path,
    priors: FilterPriors,
    t_quantiles: dict[str, float],
) -> dict[str, Any]:
    """Write the conditioned windows artifact to `path`, creating parent directories.

    Returns:
        The payload that was written.
    """
    payload = build_conditioned_payload(priors, t_quantiles)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
