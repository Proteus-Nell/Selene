"""Shape, type and range contracts on the simulator and the exported artifacts.

Contract tests fail loudly on schema drift instead of letting a silently wrong
model train on silently wrong data. See docs/PLAN.md 5.4.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cyclecore.config import PopulationConfig, Settings, load_settings
from cyclecore.data.synthetic import (
    MAX_PLAUSIBLE_DAYS,
    MIN_PLAUSIBLE_DAYS,
    sample_population,
    simulate_population,
    simulate_user,
)
from cyclecore.export.golden_vectors import build_golden_payload, golden_cases
from cyclecore.export.priors_json import (
    PRIORS_SCHEMA_VERSION,
    build_priors_payload,
    git_sha,
)
from cyclecore.models.intervals import QUANTILE_LEVELS, student_t_quantiles
from cyclecore.seeds import DEFAULT_SEED, seed_everything


class TestSyntheticContracts:
    def test_population_size_and_ids(self) -> None:
        rng = seed_everything(DEFAULT_SEED)
        specs = sample_population(50, rng)
        assert len(specs) == 50
        assert [s.user_id for s in specs] == list(range(50))

    def test_all_lengths_are_ints_inside_the_clamp(self) -> None:
        rng = seed_everything(DEFAULT_SEED)
        users = simulate_population(sample_population(60, rng), 20, rng)
        for user in users:
            for length in user.true_lengths + user.observed_lengths:
                assert isinstance(length, int)
                assert MIN_PLAUSIBLE_DAYS <= length <= MAX_PLAUSIBLE_DAYS

    def test_observed_is_never_longer_than_truth(self) -> None:
        rng = seed_everything(DEFAULT_SEED)
        users = simulate_population(sample_population(80, rng), 20, rng)
        for user in users:
            assert len(user.observed_lengths) <= len(user.true_lengths)

    def test_missed_logs_actually_occur(self) -> None:
        # If the merge path never fired, the validation code it exercises would be
        # untested and the generator would be quietly easier than reality.
        rng = seed_everything(DEFAULT_SEED)
        users = simulate_population(sample_population(300, rng), 24, rng)
        assert any(u.had_missed_logs for u in users)

    def test_irregular_users_are_a_meaningful_minority(self) -> None:
        rng = seed_everything(DEFAULT_SEED)
        specs = sample_population(1000, rng, irregular_fraction=0.25)
        share = sum(s.is_irregular for s in specs) / len(specs)
        assert 0.18 < share < 0.32

    def test_seeding_is_reproducible(self) -> None:
        first = simulate_population(
            sample_population(20, seed_everything(123)), 12, seed_everything(456)
        )
        second = simulate_population(
            sample_population(20, seed_everything(123)), 12, seed_everything(456)
        )
        assert [u.observed_lengths for u in first] == [u.observed_lengths for u in second]

    def test_different_seeds_give_different_data(self) -> None:
        a = simulate_population(sample_population(20, seed_everything(1)), 12, seed_everything(1))
        b = simulate_population(sample_population(20, seed_everything(2)), 12, seed_everything(2))
        assert [u.observed_lengths for u in a] != [u.observed_lengths for u in b]

    def test_rejects_bad_arguments(self) -> None:
        rng = seed_everything(DEFAULT_SEED)
        with pytest.raises(ValueError, match="n_users must be positive"):
            sample_population(0, rng)
        with pytest.raises(ValueError, match="irregular_fraction"):
            sample_population(5, rng, irregular_fraction=1.5)
        with pytest.raises(ValueError, match="n_cycles must be positive"):
            simulate_user(sample_population(1, rng)[0], 0, rng)


class TestPriorsArtifact:
    @pytest.fixture
    def payload(self) -> dict:  # type: ignore[type-arg]
        population = PopulationConfig()
        return build_priors_payload(population, population.to_filter_priors())

    def test_required_keys(self, payload: dict) -> None:  # type: ignore[type-arg]
        for key in (
            "schema_version",
            "filter_priors",
            "t_quantiles",
            "confidence_thresholds_days",
            "population_source",
        ):
            assert key in payload, f"missing {key}"

    def test_schema_version_is_current(self, payload: dict) -> None:  # type: ignore[type-arg]
        assert payload["schema_version"] == PRIORS_SCHEMA_VERSION

    def test_filter_priors_are_finite_positive_floats(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        priors = payload["filter_priors"]
        for key in ("log_mean_var", "obs_var", "drift_var", "min_obs_var", "student_t_df"):
            assert isinstance(priors[key], float)
            assert priors[key] > 0, f"{key} must be positive"

    def test_quantile_table_matches_the_declared_df(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        df = payload["filter_priors"]["student_t_df"]
        assert payload["t_quantiles"]["df"] == df
        assert set(payload["t_quantiles"]["values"]) == set(QUANTILE_LEVELS)
        assert payload["t_quantiles"]["values"] == student_t_quantiles(df)

    def test_is_unstamped_by_default(self, payload: dict) -> None:  # type: ignore[type-arg]
        # Byte-reproducibility is what lets CI regenerate and diff.
        assert "created_utc" not in payload
        assert "git_sha" not in payload

    def test_stamping_adds_provenance(self) -> None:
        population = PopulationConfig()
        stamped = build_priors_payload(population, population.to_filter_priors(), stamp=True)
        assert "created_utc" in stamped
        assert "git_sha" in stamped

    def test_is_json_serialisable(self, payload: dict) -> None:  # type: ignore[type-arg]
        assert json.loads(json.dumps(payload)) == payload

    def test_regenerating_is_byte_identical(self) -> None:
        population = PopulationConfig()
        first = json.dumps(
            build_priors_payload(population, population.to_filter_priors()), sort_keys=True
        )
        second = json.dumps(
            build_priors_payload(population, population.to_filter_priors()), sort_keys=True
        )
        assert first == second

    def test_git_sha_returns_a_string(self) -> None:
        assert isinstance(git_sha(), str)


class TestGoldenArtifact:
    @pytest.fixture
    def payload(self) -> dict:  # type: ignore[type-arg]
        priors = PopulationConfig().to_filter_priors()
        return build_golden_payload(priors, student_t_quantiles(priors.student_t_df))

    def test_case_names_are_unique(self) -> None:
        names = [c.name for c in golden_cases()]
        assert len(names) == len(set(names))

    def test_every_case_explains_itself(self) -> None:
        for case in golden_cases():
            assert case.why.strip(), f"{case.name} has no rationale"

    def test_covers_the_required_edge_cases(self) -> None:
        names = {c.name for c in golden_cases()}
        # Straight from the plan: cold start, one cycle, an outlier, a long gap,
        # and edited history. A golden file without these passes while the port
        # is broken in the ways that matter.
        assert "cold_start_no_cycles" in names
        assert "single_cycle_28" in names
        assert "single_outlier_late" in names
        assert "merged_cycle_from_missed_log" in names
        assert "edited_history_one_value_changed" in names

    def test_state_count_matches_history_length(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        for case in payload["cases"]:
            assert len(case["states"]) == len(case["cycle_lengths"]) + 1

    def test_every_numeric_output_is_finite(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        import math

        for case in payload["cases"]:
            for state in case["states"]:
                assert math.isfinite(state["mean"])
                assert math.isfinite(state["var"])
                assert state["var"] > 0
            for value in case["log_quantiles"].values():
                assert math.isfinite(value)

    def test_day_windows_are_ordered_and_positive(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        for case in payload["cases"]:
            w = case["day_windows"]
            assert 0 < w["lo80"] <= w["lo50"] <= w["median"] <= w["hi50"] <= w["hi80"]
            assert w["width80"] >= w["width50"] >= 1

    def test_confidence_is_a_known_class(self, payload: dict) -> None:  # type: ignore[type-arg]
        allowed = {"high", "medium", "low", "too_irregular"}
        for case in payload["cases"]:
            assert case["confidence"] in allowed

    def test_irregular_case_is_not_falsely_confident(
        self,
        payload: dict,  # type: ignore[type-arg]
    ) -> None:
        case = next(c for c in payload["cases"] if c["name"] == "irregular_history")
        assert case["confidence"] in {"low", "too_irregular"}

    def test_regenerating_is_byte_identical(self) -> None:
        priors = PopulationConfig().to_filter_priors()
        quantiles = student_t_quantiles(priors.student_t_df)
        first = json.dumps(build_golden_payload(priors, quantiles), sort_keys=True)
        second = json.dumps(build_golden_payload(priors, quantiles), sort_keys=True)
        assert first == second


class TestConfig:
    def test_defaults_are_valid_without_a_file(self) -> None:
        assert load_settings(None) == Settings()
        assert load_settings(Path("does-not-exist.yaml")) == Settings()

    def test_rejects_a_non_mapping_yaml(self, tmp_path: Path) -> None:
        path = tmp_path / "bad.yaml"
        path.write_text("- just\n- a\n- list\n", encoding="utf-8")
        with pytest.raises(TypeError, match="must contain a YAML mapping"):
            load_settings(path)

    def test_reads_an_override(self, tmp_path: Path) -> None:
        path = tmp_path / "ok.yaml"
        path.write_text("seed: 999\npopulation:\n  mean_cycle_days: 30.0\n", encoding="utf-8")
        settings = load_settings(path)
        assert settings.seed == 999
        assert settings.population.mean_cycle_days == 30.0

    def test_population_converts_to_filter_priors(self) -> None:
        population = PopulationConfig()
        priors = population.to_filter_priors()
        assert priors.student_t_df == population.student_t_df
        assert priors.obs_var == pytest.approx(population.within_user_sd_log**2)
        assert priors.min_obs_var == pytest.approx(population.min_obs_sd_log**2)

    def test_rejects_out_of_range_values(self) -> None:
        with pytest.raises(ValueError, match="mean_cycle_days"):
            PopulationConfig(mean_cycle_days=5.0)
        with pytest.raises(ValueError, match="student_t_df"):
            PopulationConfig(student_t_df=1.0)
