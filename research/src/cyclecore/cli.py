"""Command line entry points.

    uv run cyclecore --help

Every command is deterministic given its config and seed. Nothing here writes
outside `--artifacts-dir`.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Annotated

import structlog
import typer

from cyclecore.config import Settings, load_settings
from cyclecore.data.synthetic import sample_population, simulate_population
from cyclecore.eval.backtest import backtest_population, report_from_rows
from cyclecore.export.golden_vectors import write_golden
from cyclecore.export.priors_json import write_priors
from cyclecore.models.hyperpriors import fit_variances
from cyclecore.models.intervals import student_t_quantiles
from cyclecore.seeds import seed_everything

app = typer.Typer(
    add_completion=False,
    help="Reference model, priors, and backtests for Period-Tracker.",
    no_args_is_help=True,
)

structlog.configure(
    processors=[
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.JSONRenderer(),
    ]
)
log = structlog.get_logger()

ConfigOpt = Annotated[
    Path | None,
    typer.Option("--config", "-c", help="YAML config file. Defaults are used if omitted."),
]
ArtifactsOpt = Annotated[
    Path,
    typer.Option("--artifacts-dir", "-a", help="Where to write committed artifacts."),
]


def _settings(config: Path | None) -> Settings:
    return load_settings(config)


@app.command("fit-priors")
def fit_priors(
    config: ConfigOpt = None,
    artifacts_dir: ArtifactsOpt = Path("../artifacts"),
    stamp: Annotated[
        bool,
        typer.Option("--stamp", help="Embed git SHA and timestamp. Breaks byte-reproducibility."),
    ] = False,
    skip_fit: Annotated[
        bool,
        typer.Option("--skip-fit", help="Export the configured values without fitting."),
    ] = False,
) -> None:
    """Fit the two free variances and write `priors/priors_v1.json` (task PY-B)."""
    settings = _settings(config)
    rng = seed_everything(settings.seed)
    base = settings.population.to_filter_priors()

    if skip_fit:
        log.info("fit_priors.skipped", reason="skip_fit flag set")
        priors = base
    else:
        specs = sample_population(
            settings.fit.n_users,
            rng,
            mean_cycle_days=settings.population.mean_cycle_days,
            level_sd_log=settings.population.level_sd_log,
        )
        users = simulate_population(specs, settings.fit.n_cycles, rng)
        sequences = [u.observed_lengths for u in users]
        result = fit_variances(
            sequences,
            base,
            obs_sd_bounds=settings.fit.obs_sd_bounds,
            drift_sd_bounds=settings.fit.drift_sd_bounds,
            max_iterations=settings.fit.max_iterations,
        )
        log.info(
            "fit_priors.fitted",
            obs_sd=round(result.obs_sd, 6),
            drift_sd=round(result.drift_sd, 6),
            log_likelihood=round(result.log_likelihood, 2),
            n_sequences=result.n_sequences,
            n_observations=result.n_observations,
            converged=result.converged,
            iterations=result.iterations,
        )
        if not result.converged:
            log.warning("fit_priors.not_converged", note="exported anyway, inspect before use")
        priors = replace(base, obs_var=result.obs_sd**2, drift_var=result.drift_sd**2)

    path = artifacts_dir / "priors" / "priors_v1.json"
    write_priors(path, settings.population, priors, stamp=stamp)
    log.info("fit_priors.written", path=str(path), stamped=stamp)


@app.command("export-golden")
def export_golden(
    config: ConfigOpt = None,
    artifacts_dir: ArtifactsOpt = Path("../artifacts"),
) -> None:
    """Write `golden/predictor_cases_v1.json` from the reference filter (task PY-A).

    Reads the priors artifact if it exists so the golden vectors and the shipped
    priors always correspond. Falls back to the configured values otherwise, and
    says so, rather than silently pinning vectors to priors the app will not use.
    """
    settings = _settings(config)
    seed_everything(settings.seed)

    priors_path = artifacts_dir / "priors" / "priors_v1.json"
    if priors_path.exists():
        import json

        payload = json.loads(priors_path.read_text(encoding="utf-8"))
        raw = payload["filter_priors"]
        priors = replace(
            settings.population.to_filter_priors(),
            log_mean_center=float(raw["log_mean_center"]),
            log_mean_var=float(raw["log_mean_var"]),
            obs_var=float(raw["obs_var"]),
            drift_var=float(raw["drift_var"]),
            student_t_df=float(raw["student_t_df"]),
            min_obs_var=float(raw["min_obs_var"]),
        )
        log.info("export_golden.priors_loaded", path=str(priors_path))
    else:
        priors = settings.population.to_filter_priors()
        log.warning(
            "export_golden.priors_missing",
            path=str(priors_path),
            note="using configured defaults; run fit-priors first for a matched pair",
        )

    quantiles = student_t_quantiles(priors.student_t_df)
    path = artifacts_dir / "golden" / "predictor_cases_v1.json"
    payload = write_golden(path, priors, quantiles)
    log.info("export_golden.written", path=str(path), cases=len(payload["cases"]))


@app.command("backtest")
def backtest(
    config: ConfigOpt = None,
    artifacts_dir: ArtifactsOpt = Path("../artifacts"),
) -> None:
    """Run a rolling-origin backtest and report accuracy plus calibration."""
    settings = _settings(config)
    rng = seed_everything(settings.seed)
    priors = settings.population.to_filter_priors()
    quantiles = student_t_quantiles(priors.student_t_df)

    specs = sample_population(
        settings.backtest.n_users,
        rng,
        mean_cycle_days=settings.population.mean_cycle_days,
        level_sd_log=settings.population.level_sd_log,
    )
    users = simulate_population(specs, settings.backtest.n_cycles, rng)
    rows = backtest_population(users, priors, quantiles, min_history=settings.backtest.min_history)

    overall = report_from_rows(rows)
    log.info(
        "backtest.overall",
        n=overall.n,
        mae_days=round(overall.mae_days, 3),
        median_ae_days=round(overall.median_ae_days, 3),
        coverage_50=round(overall.coverage_50, 4),
        coverage_80=round(overall.coverage_80, 4),
        mean_width_50=round(overall.mean_width_50, 2),
        mean_width_80=round(overall.mean_width_80, 2),
    )

    # Stratified, never only pooled: pooling hides that the irregular stratum is
    # where the model is worst, and that stratum is the one that matters most.
    for label, subset in (
        ("regular", [r for r in rows if not r.is_irregular]),
        ("irregular", [r for r in rows if r.is_irregular]),
    ):
        if subset:
            report = report_from_rows(subset)
            log.info(
                "backtest.stratum",
                stratum=label,
                n=report.n,
                mae_days=round(report.mae_days, 3),
                coverage_80=round(report.coverage_80, 4),
                mean_width_80=round(report.mean_width_80, 2),
            )

    _log_baselines(rows)
    log.info("backtest.done", artifacts_dir=str(artifacts_dir))


def _log_baselines(rows: list) -> None:  # type: ignore[type-arg]
    """Log baseline errors so the filter's value is always visible, not assumed."""
    from cyclecore.eval.metrics import mean_absolute_error

    actual = [r.actual_days for r in rows]
    for name, predicted in (
        ("filter", [r.predicted_days for r in rows]),
        ("last_cycle", [r.baseline_last for r in rows]),
        ("mean_of_3", [r.baseline_mean3 for r in rows]),
        ("median_of_6", [r.baseline_median6 for r in rows]),
    ):
        log.info(
            "backtest.baseline",
            predictor=name,
            mae_days=round(mean_absolute_error(actual, predicted), 3),
        )


@app.command("simulate")
def simulate(
    config: ConfigOpt = None,
    n_users: Annotated[int, typer.Option("--users", "-n")] = 5,
    n_cycles: Annotated[int, typer.Option("--cycles")] = 12,
) -> None:
    """Print a few simulated histories, for eyeballing the generator."""
    settings = _settings(config)
    rng = seed_everything(settings.seed)
    specs = sample_population(
        n_users,
        rng,
        mean_cycle_days=settings.population.mean_cycle_days,
        level_sd_log=settings.population.level_sd_log,
    )
    for user in simulate_population(specs, n_cycles, rng):
        log.info(
            "simulate.user",
            user_id=user.spec.user_id,
            irregular=user.spec.is_irregular,
            obs_sd=round(user.spec.obs_sd, 4),
            observed=user.observed_lengths,
            missed_logs=user.had_missed_logs,
        )


if __name__ == "__main__":
    app()
