// GENERATED FILE. DO NOT EDIT BY HAND.
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
    'e50b530a36ee7b9e8ee1eb02ae7fc3cd043577234852d0e079a4fa1a35f8c3af';

/// The population priors compiled into the app.
///
/// Compiled in rather than parsed from an asset so a prediction never depends
/// on file IO, and so a corrupt or missing asset cannot leave the app with no
/// model at all. [ModelPriors.parse] still exists for reading the artifact
/// directly, which is how the tests prove these constants match it.
const ModelPriors bundledPriors = ModelPriors(
  schemaVersion: 1,
  filterPriors: FilterPriors(
    logMeanCenter: 3.367295829986474,
    logMeanVar: 0.010000000000000002,
    obsVar: 0.005368255831169181,
    driftVar: 0.0005955908946064671,
    studentTDf: 4,
    minObsVar: 0.0004,
  ),
  quantiles: QuantileTable(
    df: 4,
    p10: -1.5332062740589436,
    p25: -0.7406970841126829,
    p50: 0,
    p75: 0.7406970841126829,
    p90: 1.533206274058944,
  ),
  personalisation: Personalisation(
    minCycles: 5,
    obsSdGrid: <double>[
      0.02,
      0.026,
      0.033,
      0.042,
      0.053,
      0.067,
      0.085,
      0.107,
      0.135,
      0.17,
      0.215,
      0.271,
      0.342,
    ],
    driftSdGrid: <double>[
      0.004,
      0.008,
      0.014,
      0.024,
      0.04,
      0.066,
      0.1,
    ],
  ),
  confidenceThresholds: ConfidenceThresholds(
    highBelowDays: 4,
    mediumBelowDays: 8,
    lowBelowDays: 14,
  ),
);
