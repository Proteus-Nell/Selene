#!/usr/bin/env python3
"""Generate the Dart mirror of the priors artifact (task AND-07).

`artifacts/priors/priors_v1.json` is the contract between the Python research
side and the Dart app (DECISIONS.md ADR-0002). The app compiles those constants
in rather than parsing the asset on every cold start, so this script writes
`app/lib/domain/predict/priors_bundled.dart` from the artifact and records the
artifact's SHA-256 alongside them.

That checksum is the guard PLAN.md 3.5 describes for `sync_priors.sh`: it makes
"the committed Dart constants no longer match the committed artifact" a
mechanically detectable state instead of something a reviewer has to notice.
`--check` is the CI form and writes nothing.

The values are emitted with `repr`, which round-trips a float exactly, and Dart's
literal parser is correctly rounded, so both runtimes end up on the identical
bit pattern. Integral values are emitted as int literals because the Dart
analyzer's `prefer_int_literals` rule rejects `4.0` in a `double` context.

Usage:
    python3 tools/scripts/gen_priors_dart.py
    python3 tools/scripts/gen_priors_dart.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = REPO_ROOT / "artifacts" / "priors" / "priors_v1.json"
OUTPUT = REPO_ROOT / "app" / "lib" / "domain" / "predict" / "priors_bundled.dart"

SUPPORTED_SCHEMA_VERSIONS = (1,)

QUANTILE_LEVELS = ("p10", "p25", "p50", "p75", "p90")


def dart_number(value: float) -> str:
    """Render `value` as a Dart literal that parses back to the same double."""
    as_float = float(value)
    if as_float.is_integer() and abs(as_float) < 1e15:
        return str(int(as_float))
    return repr(as_float)


def dart_grid(values: list[float], indent: str) -> str:
    """Render a grid as a Dart list literal, one value per line."""
    body = "".join(f"{indent}  {dart_number(v)},\n" for v in values)
    return f"<double>[\n{body}{indent}]"


def render(payload: dict, digest: str) -> str:
    """Return the full text of the generated Dart file."""
    schema_version = payload["schema_version"]
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise SystemExit(
            f"{ARTIFACT} declares schema_version {schema_version}; this "
            f"generator understands {list(SUPPORTED_SCHEMA_VERSIONS)}. Update "
            f"priors.dart and this script together, then regenerate."
        )

    filter_priors = payload["filter_priors"]
    quantiles = payload["t_quantiles"]
    personalisation = payload["personalisation"]
    thresholds = payload["confidence_thresholds_days"]

    quantile_lines = "".join(
        f"    {level}: {dart_number(quantiles['values'][level])},\n"
        for level in QUANTILE_LEVELS
    )

    return f"""// GENERATED FILE. DO NOT EDIT BY HAND.
//
// Written by `tools/scripts/gen_priors_dart.py` from
// `artifacts/priors/priors_v1.json`. Regenerate after every priors export:
//
//     python3 tools/scripts/gen_priors_dart.py
//
// `python3 tools/scripts/gen_priors_dart.py --check` fails if this file has
// drifted from the artifact, which is what keeps the two sides of ADR-0002
// honest.

import 'package:period_tracker/domain/predict/priors.dart';

/// SHA-256 of the `priors_v1.json` these constants were generated from.
///
/// Recorded so a stale copy is detectable without re-running the export. This
/// is a drift guard, not a security boundary: the artifact is committed to the
/// repository and never fetched at runtime.
const String priorsArtifactSha256 =
    '{digest}';

/// The population priors compiled into the app.
///
/// Compiled in rather than parsed from an asset so a prediction never depends
/// on file IO, and so a corrupt or missing asset cannot leave the app with no
/// model at all. [ModelPriors.parse] still exists for reading the artifact
/// directly, which is how the tests prove these constants match it.
const ModelPriors bundledPriors = ModelPriors(
  schemaVersion: {schema_version},
  filterPriors: FilterPriors(
    logMeanCenter: {dart_number(filter_priors["log_mean_center"])},
    logMeanVar: {dart_number(filter_priors["log_mean_var"])},
    obsVar: {dart_number(filter_priors["obs_var"])},
    driftVar: {dart_number(filter_priors["drift_var"])},
    studentTDf: {dart_number(filter_priors["student_t_df"])},
    minObsVar: {dart_number(filter_priors["min_obs_var"])},
  ),
  quantiles: QuantileTable(
    df: {dart_number(quantiles["df"])},
{quantile_lines}  ),
  personalisation: Personalisation(
    minCycles: {personalisation["min_cycles"]},
    obsSdGrid: {dart_grid(personalisation["obs_sd_grid"], "    ")},
    driftSdGrid: {dart_grid(personalisation["drift_sd_grid"], "    ")},
  ),
  confidenceThresholds: ConfidenceThresholds(
    highBelowDays: {thresholds["high_below"]},
    mediumBelowDays: {thresholds["medium_below"]},
    lowBelowDays: {thresholds["low_below"]},
  ),
);
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the generated file is stale, and write nothing",
    )
    args = parser.parse_args()

    if not ARTIFACT.exists():
        print(f"error: {ARTIFACT} does not exist", file=sys.stderr)
        return 1

    raw = ARTIFACT.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    generated = render(json.loads(raw), digest)

    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current == generated:
            print(f"OK: {OUTPUT.relative_to(REPO_ROOT)} matches the artifact")
            return 0
        print(
            f"error: {OUTPUT.relative_to(REPO_ROOT)} is stale. Run "
            f"`python3 tools/scripts/gen_priors_dart.py` and commit the result.",
            file=sys.stderr,
        )
        return 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)} (sha256 {digest[:12]}...)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
