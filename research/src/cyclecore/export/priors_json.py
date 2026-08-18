"""Export the population priors the app ships (task PY-B).

Determinism note
----------------
The payload is deterministic: regenerating with the same config and seed produces
a byte-identical file. Provenance fields (`git_sha`, `created_utc`) are therefore
**opt-in** via `stamp=True`, not always-on.

That is not laziness about provenance, it is what makes the CI drift check
possible at all: `golden.yml` regenerates the artifacts and fails if they differ
from what is committed, and a timestamp baked in on every run would make that
check fail permanently and then be disabled. Provenance belongs on release
artifacts, reproducibility belongs in CI, and separating them lets both work.
"""

from __future__ import annotations

import json
import subprocess
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from cyclecore.config import PopulationConfig
from cyclecore.models.bayes_filter import FilterPriors
from cyclecore.models.intervals import (
    CONFIDENCE_HIGH_MAX_DAYS,
    CONFIDENCE_LOW_MAX_DAYS,
    CONFIDENCE_MEDIUM_MAX_DAYS,
    QUANTILE_LEVELS,
    student_t_quantiles,
)
from cyclecore.models.personalize import (
    DEFAULT_DRIFT_SD_GRID,
    DEFAULT_OBS_SD_GRID,
    PERSONALIZE_MIN_CYCLES,
)

__all__ = ["PRIORS_SCHEMA_VERSION", "build_priors_payload", "git_sha", "write_priors"]

PRIORS_SCHEMA_VERSION = 1
"""Bump on any breaking change to the payload shape.

The app refuses to load a priors file whose `schema_version` it does not
recognise, rather than reading fields that may have changed meaning. See
docs/PLAN.md 5.3.
"""


def git_sha() -> str:
    """Return the current commit SHA, or `unknown` outside a git checkout."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return "unknown"
    return result.stdout.strip() or "unknown"


def build_priors_payload(
    population: PopulationConfig,
    priors: FilterPriors,
    *,
    stamp: bool = False,
) -> dict[str, Any]:
    """Assemble the priors artifact.

    Args:
        population: The configured population values, echoed so the artifact
            explains itself without needing the repo.
        priors: The scalar constants the filter consumes, after any fit.
        stamp: Whether to include non-deterministic provenance fields.

    Returns:
        A JSON-serialisable mapping.
    """
    quantiles = student_t_quantiles(priors.student_t_df)
    payload: dict[str, Any] = {
        "schema_version": PRIORS_SCHEMA_VERSION,
        "generated_by": "cyclecore.export.priors_json",
        # The scalars the filter reads. Names match FilterPriors and the Dart port.
        "filter_priors": {
            "log_mean_center": priors.log_mean_center,
            "log_mean_var": priors.log_mean_var,
            "obs_var": priors.obs_var,
            "drift_var": priors.drift_var,
            "student_t_df": priors.student_t_df,
            "min_obs_var": priors.min_obs_var,
        },
        # Student-t quantiles for the fixed degrees of freedom above. Shipped as
        # constants so the Dart port needs no special functions at all.
        "t_quantiles": {
            "df": priors.student_t_df,
            "levels": dict(QUANTILE_LEVELS),
            "values": quantiles,
        },
        # The on-device personalisation search. Shipped as explicit values so the
        # Dart port iterates the identical grid rather than recomputing a
        # log-spaced range and rounding differently.
        "personalisation": {
            "min_cycles": PERSONALIZE_MIN_CYCLES,
            "obs_sd_grid": list(DEFAULT_OBS_SD_GRID),
            "drift_sd_grid": list(DEFAULT_DRIFT_SD_GRID),
        },
        "confidence_thresholds_days": {
            "high_below": CONFIDENCE_HIGH_MAX_DAYS,
            "medium_below": CONFIDENCE_MEDIUM_MAX_DAYS,
            "low_below": CONFIDENCE_LOW_MAX_DAYS,
        },
        # Human-readable provenance for the numbers that came from literature
        # rather than from a fit. Kept in the artifact so a reader never has to
        # guess where 29 days came from.
        "population_source": {
            "mean_cycle_days": population.mean_cycle_days,
            "level_sd_log": population.level_sd_log,
            "note": (
                "Centre and between-user spread are taken from published summary "
                "statistics, not individual records. See docs/PLAN.md 6.1. "
                "[VERIFY against the cited paper before any wider release.]"
            ),
        },
    }
    if stamp:
        payload["git_sha"] = git_sha()
        payload["created_utc"] = datetime.now(UTC).isoformat()
    return payload


def write_priors(
    path: Path,
    population: PopulationConfig,
    priors: FilterPriors,
    *,
    stamp: bool = False,
) -> dict[str, Any]:
    """Write the priors artifact to `path`, creating parent directories.

    Returns:
        The payload that was written, so callers can log or assert on it.
    """
    payload = build_priors_payload(population, priors, stamp=stamp)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
