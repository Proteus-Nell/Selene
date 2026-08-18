"""End-to-end smoke test: config to artifacts, fast enough to run every time.

Budget is a few seconds. If this grows past that it moves behind `-m slow` and
stops being run on every commit, which defeats the purpose.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cyclecore.config import Settings
from cyclecore.data.synthetic import sample_population, simulate_population
from cyclecore.eval.backtest import backtest_population, report_from_rows
from cyclecore.export.golden_vectors import write_golden
from cyclecore.export.priors_json import write_priors
from cyclecore.models.baselines import last_cycle, mean_of_n, median_of_n
from cyclecore.models.hyperpriors import fit_variances, population_log_likelihood
from cyclecore.models.intervals import confidence_class, student_t_quantiles
from cyclecore.seeds import seed_everything


def test_full_pipeline_writes_both_artifacts(tmp_path: Path) -> None:
    settings = Settings()
    rng = seed_everything(settings.seed)
    priors = settings.population.to_filter_priors()
    quantiles = student_t_quantiles(priors.student_t_df)

    # Simulate, backtest, export, then read both artifacts back.
    specs = sample_population(60, rng)
    users = simulate_population(specs, 14, rng)
    rows = backtest_population(users, priors, quantiles, min_history=1)
    report = report_from_rows(rows)
    assert report.n > 500
    assert 0.0 < report.coverage_80 < 1.0
    assert report.mae_days > 0

    priors_path = tmp_path / "priors" / "priors_v1.json"
    golden_path = tmp_path / "golden" / "predictor_cases_v1.json"
    write_priors(priors_path, settings.population, priors)
    write_golden(golden_path, priors, quantiles)

    assert priors_path.exists()
    assert golden_path.exists()

    priors_payload = json.loads(priors_path.read_text(encoding="utf-8"))
    golden_payload = json.loads(golden_path.read_text(encoding="utf-8"))

    # The two artifacts must describe the same model, or the Dart port would be
    # validated against priors the app does not ship.
    assert priors_payload["filter_priors"] == golden_payload["priors_used"]
    assert priors_payload["t_quantiles"]["values"] == golden_payload["t_quantiles"]


def test_files_end_with_a_newline(tmp_path: Path) -> None:
    settings = Settings()
    priors = settings.population.to_filter_priors()
    path = tmp_path / "priors_v1.json"
    write_priors(path, settings.population, priors)
    assert path.read_text(encoding="utf-8").endswith("\n")


def test_fit_runs_and_improves_the_likelihood() -> None:
    settings = Settings()
    rng = seed_everything(settings.seed)
    base = settings.population.to_filter_priors()
    users = simulate_population(sample_population(120, rng), 16, rng)
    sequences = [u.observed_lengths for u in users]

    before, _ = population_log_likelihood(sequences, base)
    result = fit_variances(sequences, base, max_iterations=60)

    assert result.converged
    assert result.log_likelihood >= before, "the fit must not make the likelihood worse"
    assert 0.015 <= result.obs_sd <= 0.30
    assert 0.001 <= result.drift_sd <= 0.10
    assert result.n_observations > 1000


def test_fit_rejects_histories_that_are_too_short() -> None:
    settings = Settings()
    with pytest.raises(ValueError, match="at least two cycles"):
        population_log_likelihood([[28], []], settings.population.to_filter_priors())


class TestBaselines:
    def test_empty_history_returns_none(self) -> None:
        assert last_cycle([]) is None
        assert mean_of_n([], 3) is None
        assert median_of_n([], 6) is None

    def test_last_cycle(self) -> None:
        assert last_cycle([28, 30, 27]) == 27

    def test_mean_of_n_uses_only_the_window(self) -> None:
        assert mean_of_n([100, 28, 28, 28], 3) == 28

    def test_median_of_n_ignores_an_outlier(self) -> None:
        assert median_of_n([28, 29, 200, 28, 29], 5) == 29

    def test_median_of_even_window(self) -> None:
        assert median_of_n([28, 30], 2) == 29

    def test_rounding_is_half_up(self) -> None:
        # mean of 28 and 29 is 28.5, which must round to 29, not to 28.
        assert mean_of_n([28, 29], 2) == 29

    def test_rejects_a_non_positive_window(self) -> None:
        with pytest.raises(ValueError, match="n must be positive"):
            mean_of_n([28], 0)


class TestConfidenceClass:
    def test_boundaries(self) -> None:
        assert confidence_class(1) == "high"
        assert confidence_class(3) == "high"
        assert confidence_class(4) == "medium"
        assert confidence_class(7) == "medium"
        assert confidence_class(8) == "low"
        assert confidence_class(13) == "low"
        assert confidence_class(14) == "too_irregular"
        assert confidence_class(40) == "too_irregular"
