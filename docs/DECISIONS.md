# Architecture Decision Log

Lightweight ADRs for Period-Tracker. One decision per entry, newest at the bottom.

**Format:** Context, Decision, Runner-up and why rejected, Consequences, Status.
**Statuses:** `Proposed` | `Accepted` | `Superseded by ADR-NNNN` | `Deprecated`.

**Rules:** never edit an accepted ADR's Decision; supersede it with a new one instead. Any PR that changes an architectural direction must add or supersede an ADR (enforced by the PR checklist in [PLAN.md](PLAN.md#56-git-workflow)).

| ADR | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](#adr-0001-flutter-and-dart-for-the-android-application) | Flutter and Dart for the Android application | Accepted | 2026-08-17 |
| [0002](#adr-0002-two-runtime-split-python-reference-dart-production-golden-vectors-as-the-contract) | Two-runtime split with golden vectors as the contract | Accepted | 2026-08-17 |
| [0003](#adr-0003-hierarchical-bayesian-state-space-model-as-tier-a-tflite-on-device-training-deferred-to-tier-b) | Bayesian state-space model as Tier A, TFLite training deferred to Tier B | Accepted; Tier B runtime clause superseded by [0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely) | 2026-08-17 |
| [0004](#adr-0004-unencrypted-local-sqlite-with-zero-network-permission) | Unencrypted local SQLite with zero network permission | Accepted; unencrypted storage superseded by [0018](#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds) | 2026-08-17 |
| [0005](#adr-0005-uv-with-python-311-wsl2-for-gpu-work-jdk-17-pinned-for-android-mlflow-local-only) | uv + Python 3.11, WSL2 for GPU, JDK 17 pinned, MLflow local-only | Accepted; clause 2 (WSL2 scope) narrowed by [0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely) | 2026-08-17 |
| [0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely) | PyTorch and ExecuTorch replace TensorFlow and LiteRT entirely | Accepted | 2026-08-17 |
| [0007](#adr-0007-named-cycle-phases-shown-by-default-ovulation-estimation-still-opt-in) | Named cycle phases shown by default, ovulation estimation still opt-in | Accepted | 2026-08-20 |
| [0008](#adr-0008-app-lock-gates-the-interface-and-does-not-encrypt-the-database) | App lock gates the interface and does not encrypt the database | Accepted | 2026-08-20 |
| [0009](#adr-0009-medicines-reference-data-is-generated-at-build-time-from-openfda) | Medicines reference data is generated at build time from openFDA | Accepted; allowlist superseded by [0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) | 2026-08-20 |
| [0010](#adr-0010-long-term-conditions-are-recorded-not-modelled) | Long-term conditions are recorded, not modelled | Accepted | 2026-08-20 |
| [0011](#adr-0011-export-v2-refuses-v1-files) | Export v2 refuses v1 files | Accepted; refusing a format that only adds fields superseded by [0020](#adr-0020-temperature-mucus-and-progesterone-are-recorded-only-and-export-v4-still-restores-v3) | 2026-08-20 |
| [0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) | The medicines reference covers every drug, one label each, chosen by rule | Accepted | 2026-10-02 |
| [0013](#adr-0013-the-medicines-bundle-is-compressed-chunks-and-an-index-searched-on-the-phone) | The medicines bundle is compressed chunks and an index, searched on the phone | Accepted | 2026-10-02 |
| [0014](#adr-0014-the-interaction-checker-compares-label-text-and-never-calls-a-pair-safe) | The interaction checker compares label text, and never calls a pair safe | Accepted; findings extended to groups by [0021](#adr-0021-group-names-on-labels-come-from-a-sourced-table-and-recorded-contraception-joins-the-conflict-flags) | 2026-10-02 |
| [0015](#adr-0015-recorded-medicines-are-kept-as-a-setting-and-their-flags-only-inform) | Recorded medicines are kept as a setting, and their flags only inform | Accepted; recorded contraception joins the flags in [0021](#adr-0021-group-names-on-labels-come-from-a-sourced-table-and-recorded-contraception-joins-the-conflict-flags) | 2026-10-02 |
| [0016](#adr-0016-a-late-period-moves-the-range-forward-and-lost-track-counts-from-the-last-period) | A late period moves the range forward, and lost track counts from the last period | Accepted | 2026-10-27 |
| [0017](#adr-0017-releases-are-built-from-a-tag-with-the-key-in-repository-secrets-and-their-version-code-comes-from-the-name) | Releases are built from a tag, with the key in repository secrets, and their version code comes from the name | Accepted | 2026-10-27 |
| [0018](#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds) | The database is encrypted, with a key the Android Keystore holds | Accepted | 2026-10-28 |
| [0019](#adr-0019-a-backup-can-be-protected-with-a-passphrase-and-an-unprotected-one-still-restores) | A backup can be protected with a passphrase, and an unprotected one still restores | Accepted | 2026-10-28 |
| [0020](#adr-0020-temperature-mucus-and-progesterone-are-recorded-only-and-export-v4-still-restores-v3) | Temperature, mucus and progesterone are recorded only, and export v4 still restores v3 | Accepted | 2026-10-28 |
| [0021](#adr-0021-group-names-on-labels-come-from-a-sourced-table-and-recorded-contraception-joins-the-conflict-flags) | Group names on labels come from a sourced table, and recorded contraception joins the conflict flags | Accepted | 2026-10-28 |
| [0022](#adr-0022-medication-guides-carry-their-safety-sections-only-and-a-guide-whose-dosing-cannot-be-left-out-is-left-out-whole) | Medication Guides carry their safety sections only, and a guide whose dosing cannot be left out is left out whole | Accepted | 2026-10-28 |
| [0023](#adr-0023-herbal-supplements-are-nccihs-public-domain-fact-sheets-compared-with-medicines-by-their-safety-section) | Herbal supplements are NCCIH's public-domain fact sheets, compared with medicines by their safety section | Accepted | 2026-10-28 |
| [0024](#adr-0024-the-summary-for-a-doctor-is-a-pdf-the-app-writes-itself-with-csv-files-of-the-same-data-and-neither-holds-intercourse) | The summary for a doctor is a PDF the app writes itself, with CSV files of the same data, and neither holds intercourse | Accepted | 2026-10-28 |
| [0025](#adr-0025-the-late-period-check-in-has-a-switch-of-its-own-and-medicine-reminders-repeat-every-day-in-the-phones-own-time-zone) | The late-period check-in has a switch of its own, and medicine reminders repeat every day in the phone's own time zone | Accepted | 2026-10-28 |

---

## ADR-0001: Flutter and Dart for the Android application

**Status:** Accepted, 2026-08-17
**Deciders:** Project owner

### Context

The deliverable is a `.apk`. The owner is comfortable with Python and not currently with Kotlin or Dart. The app must run fully offline, store structured data locally, schedule local notifications, and eventually run an on-device model. The realistic candidates were native Kotlin with Jetpack Compose, Flutter with Dart, React Native with TypeScript, and a Python-on-Android path (Kivy or BeeWare).

### Decision

**Flutter with Dart**, using `drift` for persistence and `flutter_riverpod` for state.

### Runner-up and why rejected

**Kotlin with Jetpack Compose.** It is the objectively strongest technical fit: smallest APK, direct access to the on-device ML runtime and its training APIs with no bridging layer, best platform integration. Rejected because the owner explicitly chose Flutter, and the practical gap is small for an app of this size. Dart is a shorter step from Python than Kotlin plus the Android framework, the hot-reload loop is faster for solo UI iteration, and `drift` gives a better testing story than Room for pure-Dart domain logic (domain tests run on the desktop VM with no emulator).

**Python via Kivy or BeeWare** was rejected outright: larger binaries, weak notification and background-work integration, and rough tooling on Windows. Staying in one language is not worth a worse app.

**React Native** was rejected: weakest of the four for on-device ML and offline-first structured storage.

### Consequences

- The prediction core must be written twice, once in Python as reference and once in Dart. See [ADR-0002](#adr-0002-two-runtime-split-python-reference-dart-production-golden-vectors-as-the-contract).
- Choosing Flutter means the Tier B ML runtime is not reachable from Dart directly. Per [ADR-0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely), Tier B integrates through a Kotlin platform channel, because ExecuTorch's on-device training API is Kotlin-only. This is the main concrete cost of ADR-0001.
- The Flutter SDK version must be pinned with FVM (`.fvmrc` committed) to keep builds reproducible.
- The root `.gitignore` must be rewritten: the current Python template ignores `lib/` and `build/`, which would silently exclude all Flutter source.
- Adding iOS later becomes cheap, though it is explicitly out of scope.

---

## ADR-0002: Two-runtime split (Python reference, Dart production), golden vectors as the contract

**Status:** Accepted, 2026-08-17
**Deciders:** Project owner

### Context

The model must run on the phone (Dart, per ADR-0001), but the research work (fitting population priors, backtesting, calibration analysis, plotting) is far more productive in Python, which is also where the owner's skills and the RTX 4070 are useful. Implementing the same numerical algorithm in two languages invites silent divergence: a subtle difference in a clamp, a log, or an update order produces two models that agree on typical inputs and disagree exactly on the edge cases that matter.

### Decision

Split the repo into `research/` (Python, never ships) and `app/` (Dart, ships), with exactly one contract between them: **JSON artifacts committed under `artifacts/`**.

- `artifacts/priors/priors_v1.json`: population hyperpriors fitted in Python, loaded by the app.
- `artifacts/golden/predictor_cases_v1.json`: input/output pairs generated from the Python reference implementation.
- Both `pytest` and `flutter test` assert against the golden file at 1e-9 tolerance. A dedicated CI job regenerates the vectors and fails if the committed file is stale.

`app/lib/domain/` may not import Flutter. `research/` may not know anything about the app.

### Runner-up and why rejected

**Single implementation in Dart, with research done in Dart too.** Rejected because Dart has no usable equivalent of NumPyro, ArviZ, or the SciPy statistics stack; Bayesian hyperprior fitting and calibration analysis would be built from scratch.

**Single implementation in Python, shipped to the phone** (via Chaquopy, or by running the model in an embedded interpreter). Rejected because it adds tens of megabytes to the APK, complicates the build, and buys nothing: the production model is arithmetic, not a library-heavy pipeline.

**Compile the Python to an exported graph (`.pte` or equivalent) and run only that on device.** Rejected for Tier A because expressing a robust Kalman filter with a per-user grid refit as a traced graph is far harder to write, debug, and explain than 200 lines of plain Dart, and it would make the prediction path opaque in the one place where explainability is a product requirement.

### Consequences

- Every change to the filter is a two-file change plus regenerated golden vectors, enforced by the PR checklist. This is deliberate friction on the most correctness-critical code in the repo.
- The golden file must cover the edge cases, not just the happy path: cold start, one cycle, an outlier cycle, a long gap, edited history.
- Research can move fast and break things; the app cannot. The boundary makes that asymmetry structural rather than a matter of discipline.

---

## ADR-0003: Hierarchical Bayesian state-space model as Tier A, TFLite on-device training deferred to Tier B

**Status:** Accepted, 2026-08-17. **The Tier B runtime clause is superseded by [ADR-0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely)** (ExecuTorch replaces TFLite). The Tier A decision, the tiering structure, and the per-user gate are unaffected and remain in force.
**Deciders:** Project owner

### Context

The owner chose on-device personalized learning: the model adapts to the user's own logged cycles, on the device, with no shipped global model doing the work and no data leaving the phone. The hard constraint is data volume: a user has 0 cycles on day one and perhaps 12 after a year. This is an extreme small-n regime where a neural network has essentially nothing to learn from, and where cold-start behavior dominates the user experience.

A second constraint is product-level: the app must communicate uncertainty honestly (see PLAN.md section 6.2), which means the model must produce a calibrated predictive distribution, not a point estimate.

### Decision

**Tier A (ships in MVP):** a Student-t state-space model on log cycle length with a random-walk level, inferred with a robust scalar Kalman filter, initialized from population hyperpriors fitted offline in Python, and personalized on device by (a) the exact posterior update on every cycle and (b) a periodic grid refit of per-user observation and drift variance that maximizes one-step-ahead predictive likelihood. Roughly 200 lines of dependency-free Dart.

**Tier B (Phase 3, optional, feature-flagged):** a small TFLite model trained on device via LiteRT training signatures, predicting the *residual* of the Tier A forecast from features Tier A ignores. It activates only if `ml/gate.dart` finds it beats Tier A on the user's own rolling-origin backtest.

Primary evaluation metric is **interval calibration**, not MAE.

### Runner-up and why rejected

**A neural sequence model (small GRU or temporal CNN) trained on device from cycle one.** Rejected on three grounds: with n under 20 observations it cannot outperform a well-specified low-dimensional model and will overfit badly; it produces point estimates unless additional machinery is bolted on, and calibrated uncertainty is a product requirement here, not a nicety; and it makes the entire prediction path unexplainable, which conflicts with the requirement to tell the user *why* a prediction looks the way it does. It is not rejected forever: it is exactly what Tier B is, with a gate that forces it to prove itself per user.

**Pure arithmetic (mean of last N cycles).** Rejected because it has no uncertainty estimate at all, handles a single outlier cycle catastrophically, and gives the user nothing to trust or distrust. It survives as a **baseline that Tier A must beat** in every backtest.

### Consequences

- The MVP has **zero** TensorFlow, ONNX, or ML-runtime dependency. The APK carries no inference engine.
- The full model runs in microseconds, so predictions can be recomputed synchronously on every edit with no caching complexity beyond an input hash.
- Population priors become a shipped artifact with a version and a checksum, and the app must refuse to load a priors file it does not understand.
- Tier B failing to beat the baseline is an acceptable, planned outcome that costs nothing user-facing (see risk R13).
- The calibration test (empirical coverage within +/- 3 points of nominal on 2,000 simulated users) becomes a merge gate.

---

## ADR-0004: Unencrypted local SQLite with zero network permission

**Status:** Accepted, 2026-08-17. The unencrypted storage is superseded by [ADR-0018](#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds); zero network permission stands.
**Deciders:** Project owner

### Context

Menstrual data reveals sexual activity, pregnancy, pregnancy loss, fertility treatment, gender identity, and chronic illness. Since 2022 it has been a documented subject of legal process in the United States. The options considered ranged from a plain Room/Drift database relying on the Android sandbox, through SQLCipher with a Keystore-held key and an app lock, up to a hardened build with stealth mode, duress PIN, and panic wipe.

### Decision

**Plain (unencrypted) Drift/SQLite in app-private storage**, with these non-negotiable accompaniments:

- `INTERNET` permission actively **removed** from the merged release manifest (`tools:node="remove"`), and asserted absent in CI by `assert_no_network.sh` against the built APK.
- `android:allowBackup="false"` plus explicit `dataExtractionRules`, so Android auto-backup cannot copy the database to the cloud.
- No analytics, no crash reporting, no telemetry, in the app or in `research/`.
- Logs never contain cycle content.
- User-initiated export and import as an MVP feature, and a real `DELETE` plus `VACUUM` for data deletion, not a soft-delete flag.
- An honest `docs/PRIVACY.md` and `docs/THREAT_MODEL.md` stating exactly what this does and does not protect against.

### Runner-up and why rejected

**SQLCipher with the key in the Android Keystore, plus a biometric or PIN app lock.** This is the better answer on the merits for this data category, and it was the recommendation. Rejected because the owner chose the plain-DB posture for this build. The gap is real and is recorded rather than hidden: an unlocked or forensically imaged device exposes the data in plaintext, and there is no app lock in MVP.

**Maximum hardening (stealth icon, duress PIN, panic wipe)** was rejected as disproportionate complexity for a personal project, and because stealth features tend to create their own failure modes (users lose access to their own data).

### Consequences

- **Accepted risk, stated explicitly:** the database is readable by anyone with the unlocked device or a forensic image of it. This is documented in `PRIVACY.md` so the user is not misled by the word "private".
- The design must keep the migration path open: all database access goes through a single Drift `QueryExecutor` construction site, so switching to SQLCipher later is a swap plus a one-time re-encrypt migration, not a rewrite.
- App lock is the **first** post-MVP privacy feature in `docs/BACKLOG.md`.
- The no-network guarantee is the strongest part of this posture and is machine-verified, which means it cannot silently regress.
- Revisit this ADR if the threat model ever includes device seizure or a shared device.

---

## ADR-0005: uv + Python 3.11, WSL2 for GPU, JDK 17 pinned, MLflow local-only

**Status:** Accepted, 2026-08-17. **Clause 2 is narrowed by [ADR-0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely)**: with TensorFlow gone and PyTorch supporting native Windows CUDA, WSL2 is needed only for JAX GPU and is now optional. Clauses 1, 3, and 4 are unaffected.
**Deciders:** Project owner

### Context

Four toolchain choices were entangled enough to decide together. Verified facts on the target machine: system Python is **3.14.3**, `uv 0.11.2` is installed, Flutter is **not** installed, and the default JDK is **25**. The GPU is an RTX 4070 (12 GB) on Windows 11.

### Decision

1. **`uv` with a pinned Python 3.11** for `research/`. `uv` installs and pins the interpreter itself, so the 3.14 on PATH is irrelevant; `uv.lock` is committed; `requirements.txt` is generated by `uv export` and never hand-edited.
2. **WSL2 (Ubuntu) for all GPU work.** JAX CUDA and TensorFlow GPU are not available natively on Windows. Windows-native remains a fully supported CPU-only path, and CI is CPU-only.
3. **JDK 17 (Temurin) pinned** via `flutter config --jdk-dir`, because the installed JDK 25 is not supported by the Android Gradle Plugin.
4. **MLflow with a local file store** (`file:./mlruns`) for experiment tracking.

### Runner-up and why rejected

**conda/mamba** instead of uv: rejected because its main advantage (shipping CUDA libraries) is obsolete now that `jax[cuda12]` and `torch` wheels bundle their own, and it costs slow solves and environment drift.

**Python 3.12** instead of 3.11: rejected because TensorFlow's supported Python range has historically trailed by a minor version and 3.12 buys nothing this project needs. Revisit if 3.11 nears end of security support. **[VERIFY current TF and JAX support matrices at setup time.]**

**PyTorch on native Windows** instead of WSL2 (PyTorch does support Windows CUDA): a legitimate escape hatch if WSL2 proves painful, kept available as the `torch` extra. Rejected as the default because NumPyro on JAX is the right tool for the hyperprior fitting, and it needs Linux for GPU.

**Weights and Biases** instead of MLflow: better UI and sweep tooling, and rejected on a single decisive ground. W&B is cloud-first, and this project's entire premise is that reproductive-health data never leaves the device. A blanket "no accounts, no uploads, no telemetry anywhere in this repo" rule removes any path by which a stray run uploads real data. That invariant is worth more than a nicer dashboard.

### Consequences

- Two environments to maintain (Windows CPU, WSL2 GPU), both driven from the same `pyproject.toml` via extras. The `gpu` extra is the only difference.
- The GPU is a convenience, not a dependency: every artifact the app consumes can be produced on CPU, deterministically, from the same seed. This must stay true, and CI enforces it.
- `mlruns/` and `data/` are gitignored; `artifacts/` and `data/DATASETS.md` are committed.
- Installing Temurin 17 is a prerequisite for the very first Android build and belongs in M0, before any Dart is written.

---

## ADR-0006: PyTorch and ExecuTorch replace TensorFlow and LiteRT entirely

**Status:** Accepted, 2026-08-17
**Deciders:** Project owner
**Supersedes:** the Tier B runtime clause of [ADR-0003](#adr-0003-hierarchical-bayesian-state-space-model-as-tier-a-tflite-on-device-training-deferred-to-tier-b); narrows clause 2 of [ADR-0005](#adr-0005-uv-with-python-311-wsl2-for-gpu-work-jdk-17-pinned-for-android-mlflow-local-only)

### Context

ADR-0003 specified TensorFlow/Keras for authoring the Tier B residual head and TFLite/LiteRT as the on-device runtime, bound from Dart by `tflite_flutter`. The owner asked whether PyTorch could replace TensorFlow, then directed a complete replacement with no re-evaluation phase.

Verification performed on 2026-08-17 established four facts that shape this decision:

| Fact | Source |
| --- | --- |
| `executorch_flutter` exists and is active: v0.7.2, MIT, verified publisher, 160 pub points, requires Flutter 3.38+. It is **inference-only**: no `TrainingModule`, no optimizer, no fine-tuning | [pub.dev/packages/executorch_flutter](https://pub.dev/packages/executorch_flutter) |
| ExecuTorch on-device training is **experimental**. `TrainingModule` and `SGD` exist on Android and were migrated from Java to Kotlin, with end-to-end Android training tests added | [pytorch/executorch](https://github.com/pytorch/executorch), [Using ExecuTorch on Android](https://docs.pytorch.org/executorch/stable/using-executorch-android.html) |
| `ai-edge-torch` is deprecated and renamed `litert-torch`; its PyTorch converter is Beta and builds on `torch.export()` | [google-ai-edge/litert-torch](https://github.com/google-ai-edge/litert-torch) |
| PyTorch supports native Windows CUDA, which neither TensorFlow nor JAX does | Established constraint, see PLAN.md 3.8 |

### Decision

**TensorFlow is removed from the project entirely.** It appears in no dependency group, no runtime, and no artifact format. `tf-keras`, `.tflite`, `tflite_flutter`, and the LiteRT runtime go with it.

1. **PyTorch is the sole authoring framework.** Tier B goes `nn.Module` to `torch.export()` to `.pte`.
2. **ExecuTorch is the sole on-device runtime.** Artifact format is `.pte`.
3. **Integration is one Kotlin platform channel**, `ExecuTorchChannel.kt`, over `org.pytorch:executorch-android`, exposing exactly `load`, `infer`, `trainStep`, `saveCheckpoint`. Not `executorch_flutter`, because on-device training is unreachable from Dart.
4. **`torch` and `executorch` are pinned as a matched pair** and bumped together, never separately.
5. The `export` and `torch` extras collapse into a single `edge` extra. A `[[tool.uv.index]]` entry for the PyTorch CUDA wheel index is required, since those wheels are not on PyPI.
6. **This runtime choice is final.** No M5 re-evaluation spike, by explicit direction.

### Runner-up and why rejected

**PyTorch authoring plus LiteRT runtime, via `litert-torch`.** This is the lower-risk option on the technical merits today, and it was the recommendation. LiteRT's on-device training through SavedModel signatures is a more established feature than ExecuTorch's experimental `TrainingModule`, and `litert-torch` would let a PyTorch-authored model feed it, so the authoring win could have been had without touching the runtime.

Rejected by explicit direction: remove the TensorFlow lineage entirely and commit without a re-evaluation phase. The tradeoff is recorded rather than hidden. **This decision trades a more mature on-device training API for a single-framework stack with no conversion hop.** That is a defensible engineering position (one framework, one export path, one place to debug) but it is a real trade, not a free win.

**`executorch_flutter` for both inference and training:** rejected, it is inference-only.

**Two runtimes (`executorch_flutter` for inference, Kotlin channel for training):** rejected. Two independent linkages of the ExecuTorch runtime in one APK, two version pins that can skew, two error surfaces.

**Keeping TensorFlow:** rejected by direction. It would also have retained the WSL2 GPU requirement.

### Consequences

**Positive**

- One framework end to end. No cross-framework conversion step, which removes an entire category of "the model works in Python but not on device" bugs.
- PyTorch's native Windows CUDA means Tier B training experiments run on the RTX 4070 without WSL2. WSL2 narrows to JAX GPU only and becomes genuinely optional, since every artifact the app consumes is reproducible on CPU from the same seed.
- The Kotlin channel is a hard, inspectable boundary. Deleting `ExecuTorchChannel.kt` and `lib/ml/` removes the ExecuTorch dependency completely.

**Negative, stated plainly**

- ExecuTorch on-device training is experimental where LiteRT's was established. **Risk R2 stays at High likelihood.** This is the accepted cost of the single-framework decision, not an oversight.
- A Kotlin platform channel is now **mandatory** M5 work (roughly 150 lines), where it was previously a fallback. Some Kotlin is unavoidable despite ADR-0001 choosing Flutter.
- `torch` and `executorch` version coupling is a new maintenance obligation.

**Neutral**

- MVP is completely unaffected. Tier A is pure Dart and the MVP ships zero ML runtime, so this decision touches only an optional Phase 3 milestone that is designed to be deletable.
- Artifact rename `cycle_head_v1.tflite` to `cycle_head_v1.pte`; `export/tflite_export.py` to `export/executorch_export.py`; `ml/tflite_runner.dart` to `ml/executorch_channel.dart`.
- If Tier B ever degrades to inference-only (head trained offline, shipped fixed), `executorch_flutter` becomes usable directly and the Kotlin channel can be deleted. That path is non-experimental.

---

## ADR-0007: Named cycle phases shown by default, ovulation estimation still opt-in

**Status:** Accepted, 2026-08-20
**Deciders:** Project owner

### Context

Assumption A5 says the app "will not present a safe day or a contraceptive
fertile window", and 6.2 adds that "if ovulation estimation is added at all, it
is off by default". Read together, those were taken to mean that *any* phase
naming was gated. The calendar therefore showed logged days and a predicted
window and nothing about where in the cycle a user was.

That conflates two different claims. "You are on day 14, which is the follicular
phase" is a restatement of dates the user themselves logged. "Your fertile
window is the 12th to the 16th" is an inference about ovulation, and it is the
one that carries regulatory and safety weight.

### Decision

Show clinical phase names — Period, Follicular, Luteal — and the cycle day, by
default. Keep any *estimated ovulation range* behind a setting that is off until
switched on, exactly as 6.2 requires.

A copy test fails the build on "safe day", "safe window", unqualified "fertile",
and "you are ovulating". The rule becomes machine-enforced rather than a
convention that erodes.

### Consequences

A5 is amended: phase naming is permitted, contraceptive framing is not. 6.2 is
narrowed to what it was actually protecting — ovulation estimation — rather than
the vocabulary around it. The risk this accepts is that a user reads "luteal
phase" as fertility information; the mitigation is that the phase strip never
names ovulation and the estimate stays opt-in.

**Amended by AND-39, without moving the line.** The home screen's cycle ring has
a band for the estimated ovulation range, which makes it a second surface the
estimate could reach someone through. It is drawn only when the same setting is
on, it is absent for the frame before that preference has loaded, and it is
subtracted from the follicular phase rather than added to the cycle. All three
are pinned in `today_hero_test.dart`. There is still no `CyclePhase.ovulation`:
the enum has three values and the band is drawn from `ovulationEstimate`, so a
screen that does not ask for the estimate cannot render it.

---

## ADR-0008: App lock gates the interface and does not encrypt the database

**Status:** Accepted, 2026-08-20
**Deciders:** Project owner

### Context

ADR-0004 accepted an unencrypted database on the condition that the user is
told, and listed an app lock as the first privacy feature queued after the MVP.
Adding intercourse logging — the most sensitive field the app would hold — made
that queue position untenable: the data and its protection should arrive
together.

Three options were weighed: delegate to the device credential with a biometric
prompt; hold an app-specific PIN; or derive a SQLCipher key from a PIN and
encrypt at rest.

### Decision

Delegate to Android's `BiometricPrompt` with device-credential fallback, via
`local_auth`. Off by default, unlock on cold start and after sixty seconds in
the background.

**This hides the screen. It does not encrypt anything.** `PRIVACY.md` must say
so in those words, because an app lock that a user believes is encryption is
worse than no lock at all — it buys false confidence against exactly the threat
model in PLAN 6.5.

### Consequences

No secret for this project to store, verify or get wrong, and it unlocks with
whatever the user already uses. It does not defend against someone who can
unlock the phone, which is the realistic threat for this data; an app-specific
PIN would, and remains available later. Encryption at rest stays deferred, and
the honest reason is that losing a forgotten key destroys data that has no cloud
copy.

---

## ADR-0009: Medicines reference data is generated at build time from openFDA

**Status:** Accepted, 2026-08-20. **The allowlist is superseded by [ADR-0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule)**: the reference covers every drug in openFDA's label export, one label each, chosen by rule. Generating the data at build time, and the zero network permission that protects, are unaffected and remain in force.
**Deciders:** Project owner

### Context

An in-app medication and hygiene product lookup was wanted. The obvious
implementation queries a drug database at runtime, which requires the `INTERNET`
permission and therefore reverses ADR-0004.

The cost of that reversal was assessed and is not mainly about payload
confidentiality. A lookup leaks *intent*: DNS, TLS SNI, destination and timing
show that a particular phone asked a drug-information service about something,
and when. PLAN 6.5 and the legal-process history in ADR-0004 make that the
harm to design against. The permission is also inherited by every dependency,
so declaring it removes the guarantee that a compromised package has no socket
to open.

### Decision

Generate the data offline and ship it. `tools/scripts/gen_medicines.py` pulls an
allowlisted openFDA subset into `artifacts/medicines/medicines_v1.json` and a
generated Dart file, with a `--check` CI gate — the same generate-and-verify
pattern already used for the model priors. The phone never makes a request and
`INTERNET` is never declared.

Anything outside the bundled set is handed to the system browser through an
intent, which needs no permission: the browser makes the request, visibly, on
the user's explicit action.

### Consequences

ADR-0004 stands unamended and `assert_no_network.sh` stays green. Coverage is
limited to the allowlist, and the data is a dated snapshot — which is shown on
screen, because a stale date the user can see beats fresh data they cannot
verify. openFDA is **US labelling**, so strengths, brand names and warnings may
not match a user's local product; the screen says so. Tampons and cups are FDA
devices rather than drugs and are curated by hand.

---

## ADR-0010: Long-term conditions are recorded, not modelled

**Status:** Accepted, 2026-08-20
**Deciders:** Project owner

### Context

PLAN 1081 lists what the filter structurally cannot know: hormonal
contraception, pregnancy, PCOS, thyroid disease, and more. Each breaks the
"noisy stationary-ish process" assumption the model rests on. Letting a user
record these conditions raises the obvious question of what the app should then
*do* with them.

Making the model account for them was considered. It was rejected because there
is nothing to account with: the priors artifact was fitted on synthetic and
population data with no condition strata, so condition-specific behaviour would
be invented calibration wearing the costume of a measurement.

### Decision

Conditions are stored with a start date and an optional end date, displayed on
the day and in insights, and **never reach the prediction code**. A test proves
it.

One exception. An active pregnancy returns a `SuppressedByCondition` state
instead of a window, because confidently predicting a period for someone who is
pregnant is wrong rather than merely uninformed. That withholds a claim; it does
not make a different one, and it needs no new maths.

### Consequences

Hormonal contraception often removes true cycles entirely and is the strongest
candidate for the same treatment. It was considered and **not** chosen, and must
not be added quietly. Condition-specific priors remain open as research work; if
they are ever fitted, this ADR is what to supersede.

---

## ADR-0011: Export v2 refuses v1 files

**Status:** Accepted, 2026-08-20. Refusing a format that only adds fields is superseded by [ADR-0020](#adr-0020-temperature-mucus-and-progesterone-are-recorded-only-and-export-v4-still-restores-v3): export v4 restores v3.
**Deciders:** Project owner

### Context

Release 1 adds conditions to the export format. Three compatibility postures
were offered: accept both versions on import; keep every new field optional so
old builds can read new files; or write and read v2 only.

The export is this app's **only** recovery path. There is no cloud, no Play
Store restore, and risk R8 names losing it as a real failure. Refusing v1 files
therefore means every backup a user already holds stops working the moment they
update, and a phone lost after that point is total data loss.

### Decision

v2 only. v1 files are refused on import.

The consequence above was stated before the choice was made and the choice was
reaffirmed. It is recorded here so that a future session does not read it as an
oversight and quietly add a compatibility path.

Two mitigations, neither of which reintroduces v1 parsing: the refusal names its
reason specifically rather than failing generically, and the app prompts once
after the schema migration to make a fresh backup.

### Consequences

Import stays a single code path. Anyone who updates without re-exporting is one
device failure away from losing everything, and the re-export prompt is the only
thing standing between them and that. If this is ever revisited, accepting v1 on
import is a small change and the right one.

---

## ADR-0012: The medicines reference covers every drug, one label each, chosen by rule

**Status:** Accepted, 2026-10-02. Supersedes the allowlist in [ADR-0009](#adr-0009-medicines-reference-data-is-generated-at-build-time-from-openfda); its build-time generation, and ADR-0004's zero network permission, stand. The bundle it leaves as the next step is [ADR-0013](#adr-0013-the-medicines-bundle-is-compressed-chunks-and-an-index-searched-on-the-phone).
**Deciders:** Project owner

### Context

The Learn section is being rebuilt around a drugs A-Z and an interaction checker,
modelled on Drugs.com's. ADR-0009 shipped thirteen allowlisted medicines, each
fetched by a text search on its generic name, keeping the first hit. Checked
against openFDA before any snapshot was committed, that picked the wrong product
for four of the five checked: a combined pill for both emergency contraception
and the progestogen-only pill, a zinc oxide diaper cream for zinc, and an
injection for tranexamic acid tablets.

Drugs.com's data cannot be used. Its content is licensed, its `robots.txt` bars
automated access, and this project is to be open source. openFDA's bulk label
export is public, needs no key, and can be redistributed.

### Decision

1. **Every drug, not a list.** Every human prescription and over-the-counter
   drug that openFDA links to a current US product listing, from the bulk
   export.
2. **A drug is what it contains.** It is identified by its active substances,
   its route, and whether it is prescription or over the counter. Never by a
   name match.
3. **One label each, chosen by rule.** The most complete safety sections, then
   the original manufacturer over a repackager, then the reference (NDA or BLA)
   label over a generic, then the newest (`rank` in `gen_medicines.py`).
   Nothing is picked by hand, and nothing is written by hand: the app shows the
   professional label, or the Drug Facts panel for an over-the-counter drug, as
   published.
4. Homeopathic products are left out. Kits, which list no substances or route,
   take their substances from their generic name and their route from their
   carton or their drug's usual route.
5. The selection is committed as `artifacts/medicines/selection_v1.json`, one
   drug per line, so that a refresh diffs per drug.

### Runner-up and why rejected

**Keep the allowlist and fix its queries.** Still a list chosen by hand, and
every addition is another query to get right by hand.

**License a drug database** (First Databank, Medi-Span, Lexicomp, DrugBank) for
Drugs.com-style severity ratings. Incompatible with an open-source project, and
not needed to show the regulator's own text.

**Query openFDA from the phone.** Reverses ADR-0004, for the reasons ADR-0009
gives.

### Consequences

- 5,843 drugs from 262,888 labels (export of 2026-10-02). Two thirds of the
  labels are not linked to a current listing and are left out, which also
  leaves out discontinued products.
- Still US labelling and still a dated snapshot, and the app must keep saying
  both.
- The bundle the app reads (the label text, the A-Z index and its search) is
  the next step. Until it lands, `medicines_v1.json` stays unpopulated and the
  release gate in `RELEASE.md` stays open. Measured for that step: the safety
  sections of every selected label are 59 MB of text, 4.6 MB compressed with
  xz, and search covers 35,022 distinct generic and brand names.
- `--check` in CI confirms the selection is well formed. It cannot tell an
  edited value from a real one; only a fresh `--fetch` can.
- Flags for conflicting medications recorded in Conditions are planned on top
  of this, and will need their own ADR, since they extend ADR-0010.

---

## ADR-0013: The medicines bundle is compressed chunks and an index, searched on the phone

**Status:** Accepted, 2026-10-02. Builds the bundle [ADR-0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) left as its next step.
**Deciders:** Project owner

### Context

ADR-0012 chose one label for each of 5,843 drugs. Their safety sections are
60 MB of text, which has to reach a phone that has no network permission
(ADR-0004), so it ships inside the app. The A-Z was taken on one condition:
that searching all of it stays quick. Compiled into Dart the way ADR-0009's
thirteen medicines were, it would be a 60 MB source file, held in memory for as
long as the app runs.

### Decision

1. **Assets, not code.** `app/assets/medicines/index.json.zlib` describes every
   drug: its names, brands, substances and routes, the label that stands for
   it, how many labels were filed for it, and where its text is. The text is
   in `labels-NNN.jsonl.zlib`, one drug per line in key order, starting a new
   chunk after each megabyte of text. Opening a drug decompresses one
   megabyte, not sixty. `medicines_bundled.dart` keeps only the bundle's
   checksum, its counts and the export date.
2. **zlib**, through `dart:io`'s codec, which is the platform's own. No new
   dependency.
3. **Loaded when needed.** The index is decoded in a background isolate when
   the lookup opens, and dropped when it closes. A drug's text is read when its
   page opens, and the last chunk read is kept.
4. **Searched on the phone, on every keystroke**, in one pass over a buffer
   holding every name a drug can be found by. A name that is, or starts with,
   the query ranks first. The drug's own name comes before a substance, and a
   substance before a brand. Then more labels first, which puts the form most
   widely sold first. On the machine this was built on, one word takes 3 to 8
   ms and two words about 10. A test fails the search at 40 ms.
5. **Every line names its drug.** The app refuses text that names another
   drug, rather than showing one drug's warnings under another's name.
   `gen_medicines.py --check` confirms in CI that every line is where the
   index says, and that the bundle and the generated Dart agree.

### Runner-up and why rejected

**xz instead of zlib.** In the same one-megabyte chunks, 7.3 MB rather than
12, but it needs `package:archive`, whose decoder is pure Dart where zlib's is
native.

**A prebuilt SQLite database with full-text search**, through the drift the app
already uses. Indexed search, but SQLite keeps text uncompressed: 60 MB copied
out of the APK onto the phone, beside the user's own records, while the APK
still carries it too.

**Dart constants**, as ADR-0009 shipped. A 60 MB source file, compiled in and
resident in memory whenever the app runs.

### Consequences

- The APK grows by the size of the bundle, about 12 MB. Its files are already
  compressed, so the APK's own compression saves nothing on them.
- The index is 3 MB of JSON and takes 0.3 to 0.5 seconds to decode on a
  development machine, so longer on a phone. The screen shows a progress bar
  until it is ready, and the hygiene entries work meanwhile.
- A refresh from openFDA rewrites most of the bundle, adding up to 12 MB to the
  repository's history each time. Refresh for a release, not routinely. If the
  history grows to matter, move `app/assets/medicines` to Git LFS.
- The A-Z browse and the interaction checker build on this index.

---

## ADR-0014: The interaction checker compares label text, and never calls a pair safe

**Status:** Accepted, 2026-10-02. Builds on [ADR-0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) and [ADR-0013](#adr-0013-the-medicines-bundle-is-compressed-chunks-and-an-index-searched-on-the-phone). Its findings are extended to groups, such as "NSAIDs", by [ADR-0021](#adr-0021-group-names-on-labels-come-from-a-sourced-table-and-recorded-contraception-joins-the-conflict-flags), which adopts the group table rejected below.
**Deciders:** Project owner

### Context

The owner asked for an interaction checker modelled on Drugs.com's, built from
open data with nothing hand-written. Drugs.com's checker draws on a licensed
database with severity ratings, and nothing like it is open. What is open is
the label text the bundle already carries, and the FDA's established
pharmacologic classes, which openFDA attaches to some labels.

### Decision

1. **Three findings for each pair, and no others:** an ingredient both
   contain; an FDA class both are in; and each passage in one label's safety
   sections that names the other, by one of its substances or one of its
   classes, quoted as the label prints it. No severity, no verdict, no advice.
2. **The names are worked out by the generator, from the data**
   (`match_terms`). A substance is looked for under its full name, and under
   its name without its salt ("naproxen" for "naproxen sodium") when what is
   left is unambiguous, at least five characters long, and not itself a salt
   word. A salt word is any word that ends eight or more substance names.
   Only a substance openFDA lists on some label counts. A name read off a
   kit's title, "DAY" or "COLD", would be found in nearly every label.
3. **Classes come from `pharm_class_epc`.** They are merged over a drug's
   labels, and carried from a label of one substance alone to every drug
   containing that substance: most labels carry no class, a shop's ibuprofen
   among them. A combination lends its classes to neither ingredient. 36% of
   drugs end up with at least one class.
4. **Some name matches do not count as mentions:**
   - a match inside one of the label's own names, such as "estradiol" inside
     "ethinyl estradiol" on the pill's label;
   - an ingredient or class the two share, which is reported once, as shared;
   - anything outside the safety sections, such as uses or purpose.

   Where a name appears in several sections, the passage quoted comes from the
   most telling one: drug interactions, then the Drug Facts lines about other
   medicines, then contraindications, the boxed warning and the warnings.
5. **Never "safe".** Where the labels connect a pair in none of these ways, the
   screen says that this does not mean the two are safe together, and why.
   `interaction_copy_test.dart` fails the build on reassuring or directive
   wording.
6. **The list is not kept.** The checker's list lives on its screen and is gone
   when the reader leaves it.
7. **Run on the phone, off the UI thread**, as regular expressions over the two
   labels. Ten medicines, 45 pairs, take about a tenth of a second on a
   development machine, labels included.

### Runner-up and why rejected

**A licensed interaction database** (First Databank, Medi-Span, Lexicomp,
DrugBank). It would add severity ratings and far wider coverage, but it costs
money, and the licence would have to allow bundling into an offline app. It
could replace the matching later without changing the screens.

**A table of mentions computed by the generator.** Once every substance and
class is expanded, it runs to millions of pairs. Matching two labels on the
phone takes milliseconds.

**A table mapping group names to FDA classes**, for "NSAIDs", "combined
hormonal contraceptives", "MAO inhibitors" and the like. It would catch what
this misses, but it is hand-written, which the owner has ruled out for now.

### Consequences

- Labels often name medicines only by a group or an abbreviation, which this
  matching cannot see. Tranexamic acid's label contraindicates "combined
  hormonal contraceptives", and the checker does not connect it with the
  combined pill. The screen names this limit wherever it finds nothing.
- Matching is by whole words, so a word can be found in another sense:
  "lactic" in "lactic acidosis", taken as the base of lactic acid. Every
  mention is quoted, so the reader sees the words around it.
- The classes are the FDA's own, including some that read oddly on a product:
  levonorgestrel's include "Progestin-containing Intrauterine System", and so
  do Plan B's.
- The selection's schema went to 2 and its file to `selection_v2.json`. The
  bundle's schema went to 2 as well, and the app refuses an older bundle,
  which would have no names to look for.
- Medication Guides, proposed alongside this step, are deferred.

---

## ADR-0015: Recorded medicines are kept as a setting, and their flags only inform

**Status:** Accepted, 2026-10-02. Uses the matching of [ADR-0014](#adr-0014-the-interaction-checker-compares-label-text-and-never-calls-a-pair-safe). Recorded kinds of contraception join the flags in [ADR-0021](#adr-0021-group-names-on-labels-come-from-a-sourced-table-and-recorded-contraception-joins-the-conflict-flags), which adopts the runner-up below.
**Deciders:** Project owner

### Context

The owner asked for conflict flags in Conditions and medication: a notice that
medicines a person takes might conflict, which only informs, with a way out to
the web. Flags need the medicines kept between visits, which the checker
deliberately does not do. A medicine list is among the most revealing things
this app could hold: emergency contraception, HIV prevention, antidepressants.

Two constraints decide where it lives:

- **Exports.** Under ADR-0011 a build refuses backups in an older format. A new
  table would mean export format v3, and every v2 backup a user holds would
  stop restoring, for the second time in two releases.
- **Deletion.** "Delete everything" has to remove the list, and the activity
  log must not record it.

### Decision

1. **One setting, `recorded_medicines`:** a JSON list of `{key, name}`, in the
   order added. Exports carry settings verbatim and imports restore them as
   they are, so the format does not change. "Delete everything" empties the
   settings table, and removing the last medicine deletes the row. Settings
   writes are not logged.
2. **Picked, not typed.** Each medicine comes from the bundled US list and is
   kept by the bundle's key. Its name is kept too, so one that a later refresh
   drops is still shown, marked as no longer compared.
3. **The flags are computed when the screen opens**, with ADR-0014's matching
   over every pair. A flagged pair shows what connects it, a sentence each,
   and two ways on: the browser hand-off, which searches the two names after
   the usual confirmation, and the checker, which quotes each mention. A flag
   never says to stop or change anything, and `interaction_copy_test.dart`
   fails the build on directive or reassuring wording. Where nothing connects,
   the screen says so, and that this does not mean the medicines are safe
   together.

   *Amended 2026-10-27, at the owner's direction:* every pair gets a card,
   flagged or not. A pair the labels do not connect says "No labels connect
   these two medications, but you are advised to verify the results.", with
   the same browser hand-off as a flagged pair.
4. **Nothing reaches the prediction**, as with conditions (ADR-0010).

### Runner-up and why rejected

**A medicines table, with dates like conditions.** Typed, queryable, and spans
would allow "taken from ... to ...". But it changes the export format to v3,
which under ADR-0011 strands every v2 backup.

**Flags against conditions too**, such as a recorded combined pill with
rifampin. That needs a hand-written mapping from each condition to medicines,
which the owner has ruled out for now.

### Consequences

- The list is stored unencrypted with everything else (ADR-0004), and is in
  every export. Anyone who can read either can read it. PRIVACY.md says so.
- A setting has no dates. The list is what someone takes now, not a history.
- An older build that restores a backup with this setting keeps it, and
  ignores it.
- The flags inherit ADR-0014's limits. A label that names the other medicine
  only by a group, such as "combined hormonal contraceptives", raises no flag.

---

## ADR-0016: A late period moves the range forward, and lost track counts from the last period

**Status:** Accepted, 2026-10-27. Extends the golden-vector contract of [ADR-0002](#adr-0002-two-runtime-split-python-reference-dart-production-golden-vectors-as-the-contract).
**Deciders:** Project owner

### Context

Someone who logged symptoms every day but no period saw "any day now" in the
ring for as long as they kept logging. Two things combined:

- **The countdown read the window as first predicted.** Once that window had
  opened, every later day was "inside the expected range", including every day
  after it had closed.
- **Losing track was counted from the last log of any kind.** A headache logged
  yesterday reset it, so the state that exists to stop a stale window being
  shown never arrived.

Someone who logged nothing at all was told "not yet, log a period start", which
is also what the ring said to every irregular history and every recorded
pregnancy. The owner chose three fixes: say the period is later than expected,
count losing track from the last period, and move the range forward.

### Decision

1. **Lost track counts from the start of the last logged period:** day 61 of the
   cycle in progress, the day the ring stops counting, and only once the window
   first predicted has also passed, so that a cycle expected to run long is not
   mistaken for a lost one. It replaces "60 days with no log of any kind". The
   panel says when the last period started, and the ring has its own message,
   "lost track".
2. **Once the window has opened with no period logged, the windows move
   forward.** The days gone by are evidence that the cycle is at least that
   long, so the forecast is conditioned on it: in whole days, a length of at
   least *k* is a log length of at least log(*k* - 0.5), and each quantile at
   level *q* becomes the forecast's quantile at
   `below + q (1 - below)`, where `below` is the forecast's probability under
   that bound. No bound is ever before today. Quantiles at levels known only on
   the day cannot come from the shipped table, so the Student-t distribution
   function and its inverse are computed in plain arithmetic (`student_t.py`,
   ported step for step to `student_t.dart`), held to SciPy by the Python tests,
   and pinned across runtimes by a second golden file,
   `conditioned_cases_v1.json`: 30 cases from five histories, floats to 1e-9
   and days exactly. The move depends on the day, so it is applied to the
   cached fit rather than cached, and the prediction is recomputed when the app
   comes back on a new day.
3. **Past the window first predicted, the app says the period is later than
   expected**, and by how many days. The panel gives the moved range as a rough
   guide, without "four out of five", a most likely day or a confidence label,
   because the backtest below does not support them there.
4. **A moved range as wide as the app refuses to show for an irregular history
   (14 days) is not shown.** Past the window, `PredictionResult.laterThanExpected`
   says when the period was expected instead. Inside the window, the window
   first predicted stands, unmoved.
5. **Reminders are scheduled from the window first predicted**, never from a
   moved one, which would move "likely started" to tomorrow every day and keep
   the late notice five days away for good.
6. **The ring names every state without a window**: "no range" for a history
   too irregular for one, "paused" while a pregnancy is recorded, and "check
   dates" when the stored dates disagree.

`cyclecore backtest-late` scores moved windows on the synthetic population,
counting only cycles that reached each day without their period. Coverage of
the 80% window, as first predicted and once moved:

| Day | Regular cycles | Held | Irregular cycles | Held |
| --- | --- | --- | --- | --- |
| As first predicted | 12,414 | 85.7% | 4,190 | 68.8% |
| Day after the window opened | 10,542 | 89.7% | 3,555 | 71.2% |
| Day after its median | 4,713 | 86.4% | 1,932 | 65.0% |
| Day after it closed | 1,090 | 59.1% | 829 | 58.3% |
| 5 days after it closed | 457 | 15.8% | 587 | 63.4% |
| 15 days after it closed | 403 | 90.8% | 358 | 88.8% |

Inside the window, a moved range holds as well as the window first predicted.
Past it, the cycles still going for a regular user are mostly a missed log, at
about twice the usual length, which a single Student-t cannot put its mass on
until the range is wide. The irregular rows include windows the app does not
show, being wider than 14 days.

### Runner-up and why rejected

**No range at all past the window**, only "later than expected". The backtest
supports it: a range moved five days past a regular user's window held the
period one time in six. Rejected because the owner chose to move the range
forward, and because it does help inside the window, where it drops days that
have already gone. Past the window it is kept, but labelled for what it is. If
it misleads in use, removing it is one condition in the repository.

**A mixture model with a missed-log component**, putting mass at about twice
the usual length. It is what the backtest points to, but it is a change to the
model rather than to how its forecast is read, and it needs its own priors,
golden vectors and calibration work.

### Consequences

- A second golden file is part of the contract, and the Dart port has two
  special functions that only exist to read it. Neither changes the windows
  first predicted, whose golden file is byte-identical.
- Someone who logs only periods loses track a few days sooner than before,
  because the count starts at the period's first day rather than its last.
- A cycle around ten weeks long is already too irregular to show a window under
  the 14-day rule, which counts days rather than a proportion of the cycle. That
  is unchanged here. The protection in point 1 still applies to it: until its
  window has passed, it gets its own figures rather than "lost track".
- `Prediction` carries `originalWindow80` and `daysLate`. It is never exported,
  so the export format does not change.

---

## ADR-0017: Releases are built from a tag, with the key in repository secrets, and their version code comes from the name

**Status:** Accepted, 2026-10-27
**Deciders:** Project owner

### Context

A newer build would not install over an older one. There were no releases, so
the APKs being installed were CI artifacts, and CI signs with a debug key that
every runner generates afresh: no two runs share a signature, and Android
refuses an update signed by a different key. The version had also never moved
from `1.0.0+1`, and Flutter adds `1000 × ABI` to each split APK's version code,
so even a correctly signed 32-bit APK of a later release would be refused over
the arm64 APK of an earlier one. The owner asked for GitHub Releases that
update an existing install.

### Decision

1. **A tag `vX.Y.Z` on `main` runs `.github/workflows/release.yml`**, which
   tests the commit, builds it with `tools/scripts/release.sh`, and leaves a
   draft release: the APKs, `SHA256SUMS.txt`, and the signing certificate's
   fingerprint in the notes. A person publishes it, after the upgrade check
   that no workflow can do.
2. **The release keystore is held in four repository secrets**, read only by
   that workflow, which only a tag push triggers. It is written outside the
   working tree for the build and deleted afterwards.
3. **The version code is derived from the name**, `major × 10000 + minor × 100 +
   patch`, by `tools/scripts/release_version.py`, which refuses a pubspec that
   breaks the rule, a tag that does not match it, and a version no newer than
   one already tagged.
4. **Every APK of a release has that one code**, built with
   `-Pforce-version-code-ignoring-abi=true`, and `release.sh` checks each APK
   for it.
5. **CI artifacts are named as test builds**, not installable ones. The first
   release starts at code 10000, above anything an earlier build could have
   had, but a copy installed from a CI artifact still has to be backed up,
   uninstalled and restored once, because its signature differs.

### Runner-up and why rejected

**Building on the owner's machine and uploading by hand.** The key never leaves
that machine, which is the stronger position: here, anyone who can change the
release workflow on `main` can make it sign something else. Rejected as the
default because a release is then only as reproducible as one laptop, and every
check in `release.sh` depends on someone running it. It stays possible:
`release.sh` is the same script either way, and `docs/RELEASE.md` section 6
works without the secrets if the draft is created by hand.

**A build number chosen by hand**, or the workflow's run number. Either can go
backwards: a hand-chosen number by being forgotten, a run number when the
workflow is renamed or re-created.

### Consequences

- The keystore is now in two places that must stay identical: the backups in
  `docs/RELEASE.md` section 1, and the secrets. Replacing the secrets with a new
  key strands every copy installed from an earlier release.
- Minor and patch versions stop at 99.
- Settings shows the version name alone, since the build number is derived
  from it.

---

## ADR-0018: The database is encrypted, with a key the Android Keystore holds

**Status:** Accepted, 2026-10-28. Supersedes the unencrypted storage of [ADR-0004](#adr-0004-unencrypted-local-sqlite-with-zero-network-permission). [ADR-0008](#adr-0008-app-lock-gates-the-interface-and-does-not-encrypt-the-database) stands: the app lock still only gates the interface.
**Deciders:** Project owner

### Context

ADR-0004 accepted an unencrypted database, with the risk stated in PRIVACY.md
and a way out designed in: every connection is made in one function, so
encryption would be a change there and a one-time migration. The owner chose to
take it, as the database encrypted on the phone plus optional passphrase
protection for exports, after asking two questions:

- **Do backups taken before keep restoring?** Yes. Encrypting the database
  does not change the export format.
- **Can an encrypted backup be read after a reinstall?** Only one protected by
  a passphrase. A key the Keystore holds is deleted with the app.

### Decision

1. **SQLite3 Multiple Ciphers**, selected through `package:sqlite3`'s build
   hook (`hooks: user_defines: sqlite3: source: sqlite3mc` in `pubspec.yaml`).
   It is MIT licensed, needs no OpenSSL, and its prebuilt binaries are checked
   against hashes the package pins. The cipher, ChaCha20-Poly1305, is named on
   every connection, so a change of the library's default could not lock an
   existing file. `flutter test` runs on the same library, so the encryption is
   tested rather than mocked.
2. **The key is 32 random bytes**, made on the phone the first time a build
   that encrypts opens the database, and kept with `flutter_secure_storage`,
   which wraps it with an RSA key held by the Android Keystore. Its
   `resetOnError` is off, so a failed read cannot wipe the only key. The key
   never leaves the phone and is not in any export.
3. **A database written before is encrypted in place** on the first launch of
   the app: `PRAGMA hexrekey`, inside one transaction, with a copy kept until
   the encrypted file opens with the key and passes `quick_check`, and put back
   if it does not. A file already damaged is quarantined as it is, unencrypted.
   One the encryption could not run on, as on a full disk, is opened
   unencrypted and encrypted on a later launch.
4. **An unreadable key store opens nothing.** The app says so and the next
   launch tries again, rather than making a new key the existing file could
   never be opened with. A key missing from the store, which leaves a file
   nothing can open, is handled as damage: the file is kept aside and the user
   is offered their last export.
5. **The notification action never makes a key or encrypts.** Its background
   isolate opens a file not yet encrypted as it is, an encrypted one only with
   the stored key, and otherwise leaves the day unlogged.

### Runner-up and why rejected

**SQLCipher**, which the same hook offers. It links OpenSSL on Android and
brings its own licence terms, for nothing the app needs that SQLite3 Multiple
Ciphers lacks.

**A key that needs the user to authenticate**, such as one bound to the device
credential. It would protect an unlocked phone with root, which this design does
not. But the notification action logs a period from the lock screen without the
app open, and could not open the database, and forgetting the credential would
lose the data.

**A channel in the app's own Android code** instead of a plugin. One dependency
fewer, but the background engine the notification action runs in registers
plugins, not the app's own channels.

### Consequences

- A copy of the app's files, taken without the phone, cannot be read. An
  unlocked phone still can: by anyone using it unless the app lock is on, and
  by someone with root or a forensic tool, using the key the way the app does.
  PRIVACY.md says so, and `privacy_text_test.dart` holds it to saying so.
- Scheduled reminders' wording is kept by Android outside the file until they
  are due. PRIVACY.md names it.
- Uninstalling deletes the key with the database. An export is the only way
  data outlives the app.
- A file quarantined after encryption is encrypted too, and opens only with
  the key this install holds.

---

## ADR-0019: A backup can be protected with a passphrase, and an unprotected one still restores

**Status:** Accepted, 2026-10-28. The other half of the owner's choice in [ADR-0018](#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds).
**Deciders:** Project owner

### Context

A backup is the one copy of this data that leaves the app, and it goes
wherever the person puts it: a downloads folder, a cloud drive, an email to
themselves. The database key cannot protect it. That key never leaves the
phone and is deleted with the app, so a backup sealed with it could not be read
after a reinstall or on a new phone, which are the two times a backup is
needed. And the backups people already hold, unprotected, have to keep
restoring.

### Decision

1. **Export asks every time** whether to protect the backup, before the folder
   is chosen. "Save without one" is a button of its own, beside "Protect and
   save", not what happens on the way out.
2. **A protected backup is JSON**, with the extension the import already
   accepts:

   ```json
   {"format": "selene-protected-backup", "version": 1,
    "kdf": {"name": "pbkdf2-hmac-sha256", "iterations": 600000, "salt": "<16 bytes>"},
    "cipher": {"name": "aes-256-gcm", "nonce": "<12 bytes>"},
    "ciphertext": "<the export, then the 16-byte tag>"}
   ```

   Binary fields are base64, and the format name and version are bound to the
   ciphertext as associated data. Inside is the ordinary export, byte for
   byte, so opening one hands the import the same text, and every check the
   import makes still runs.
3. **PBKDF2-HMAC-SHA256 at 600,000 iterations**, OWASP's 2023 figure. Each file
   records its own count, and a file asking for more than 5,000,000 is refused
   before any work is done. The derivation is written in the app, hashing
   HMAC's two padded key blocks once rather than on every iteration, which
   takes about a third of pointycastle's time. It is held to the RFC 7914 test
   vectors and to pointycastle's own PBKDF2. AES-256-GCM is pointycastle's. Both
   run on another isolate, so the screen stays responsive.
4. **A passphrase is at least 8 characters**, typed twice. A wrong one is
   refused and asked for again. A forgotten one cannot be recovered, and the
   dialog says so before anything is saved.
5. **An unprotected export is unchanged** and restores as before. The import
   tells the two apart by the `format` field.

### Runner-up and why rejected

**Argon2id**, which is memory-hard and resists guessing on graphics cards
better. In pure Dart it is slow on a phone at parameters worth having, and the
alternative is a native plugin, for a file made a few times a year.

**Sealing with the database key.** Unreadable after a reinstall, as above.

**A password-protected zip.** The common zip encryption is broken, the AES
variant needs another library, and the import would need to unpack before it
could read anything.

### Consequences

- A forgotten passphrase loses that backup, and nobody can help.
- The format above is complete, so any PBKDF2 and AES-GCM implementation can
  open a backup without this app.
- Sealing and opening each take a second or two on a phone, behind a progress
  bar.

---

## ADR-0020: Temperature, mucus and progesterone are recorded only, and export v4 still restores v3

**Status:** Accepted, 2026-10-28. Relaxes [ADR-0011](#adr-0011-export-v2-refuses-v1-files) for formats that only add fields.
**Deciders:** Project owner

### Context

The owner asked for three more things to be logged: basal body temperature,
cervical mucus, and progesterone results, both a home PdG strip and a blood
test with its unit. Asked whether they should feed the prediction, the owner
chose **record only**. They are fertility signs: read together, a temperature
shift, egg-white mucus and a positive PdG strip are how fertility-awareness
methods place ovulation, and assumption A5 forbids this app from presenting a
fertile window or a safe day.

They change the export, and under ADR-0011 every change of format refused the
previous one. Twice already that stranded every backup taken before it, the
second time for a single nullable field. The owner asked that existing backups
keep restoring.

### Decision

1. **Five nullable columns** on `day_logs`, schema v5: the temperature in
   Celsius whatever unit it was entered in, mucus as one of dry, sticky,
   creamy, watery or egg white, the strip as negative or positive, and the
   blood value with its unit, ng/mL or nmol/L, kept as the laboratory reported
   it rather than converted. A value and its unit are set together or not at
   all, which `DayLog` asserts and the import checks. Null is not recorded.
2. **Recorded only, structurally.** Nothing in `lib/domain/predict/` or
   `lib/domain/cycles/` may name the types or the fields, and
   `record_only_isolation_test.dart` fails the build if anything does. It also
   checks that a history with every measurement on every day predicts exactly
   what the same history without them does.
3. **In the day editor, in a section of their own**, closed unless the day has
   one, which says before anything is entered that none of it is used to
   predict anything. Numbers are written when they are finished, not on every
   keystroke, and refused with a reason when they are out of range. Settings
   chooses °C or °F for display.
4. **Export v4 carries them, and v3 still restores.** v4 only adds fields, so
   a v3 file has nothing missing, and an absent field means not recorded,
   which is what it meant when the file was written. The import keeps a
   fingerprint per readable version. v2 and earlier stay refused. The
   re-export prompt fires only for backups older than the oldest restorable
   format, so nobody holding a v3 backup is told it is lost.

### Runner-up and why rejected

**Using them to refine the prediction.** A temperature shift or a positive PdG
strip would narrow the next window, but it is the same inference as placing
ovulation, one step from the fertile window A5 rules out. The owner chose
record only.

**Keeping ADR-0011's policy and refusing v3.** It would strand every backup
taken before this release for the third time, for a change that only adds
fields, with nothing to gain: there is nothing in a v3 file the import would
have to guess.

### Consequences

- The import has a branch per readable version. The next change that does
  remove or rename something can still refuse what came before, and must say
  so here.
- The measurements are in exports, and so in any backup a person sends
  anywhere.
- The calendar does not mark them. The day editor is where they are seen.

## ADR-0021: Group names on labels come from a sourced table, and recorded contraception joins the conflict flags

**Status:** Accepted, 2026-10-28. Extends the findings of [ADR-0014](#adr-0014-the-interaction-checker-compares-label-text-and-never-calls-a-pair-safe), and adopts what it and [ADR-0015](#adr-0015-recorded-medicines-are-kept-as-a-setting-and-their-flags-only-inform) left as runners-up.
**Deciders:** Project owner

### Context

Labels often name another medicine only by a group. Tranexamic acid's
contraindicates "combined hormonal contraceptives"; sertraline's warns about
"NSAIDs"; tramadol's about "SSRIs", "SNRIs", "TCAs" and "MAOIs". ADR-0014
matched names and the FDA's classes only, so none of these connected, and the
conflict flags of ADR-0015 inherited the gap. Both screens said so.

The owner chose a **sourced table**: a short table mapping each group name to
the medicines in it, each row citing its source. Asked whether recorded
conditions should take part in the flags, such as a recorded combined pill
with rifampin, the owner chose **yes, with a mapping**, each kind of hormonal
contraception counting as its active substances.

The FDA's own classes could not do this alone. Most labels carry no class, so
citalopram, sertraline and escitalopram have none in the bundle, and some
classes are broader than the words labels use: the FDA's "Serotonin Reuptake
Inhibitor" takes in trazodone and nefazodone, which are not SSRIs, and in this
data its "Anti-coagulant" takes in citric acid.

### Decision

1. **A hand-written table, `artifacts/medicines/groups_v1.json`, whose every
   member comes from the source it cites**: the FDA's established
   pharmacologic classes as the National Library of Medicine's RxClass
   publishes them, which lists every ingredient rather than only labelled
   ones; the FDA's own lists (Table 1 of its 2020 NSAID safety communication;
   its Office of Women's Health pages on depression medicines and on birth
   control); the definition in its draft guidance on combined hormonal
   contraceptive labelling; and, for fluvoxamine and two oddities in the
   bundle's data, the drug's own approved label. Twelve groups:

   | Group | Members from |
   | --- | --- |
   | NSAIDs | FDA class, FDA safety communication |
   | SSRIs | FDA Office of Women's Health, fluvoxamine's label |
   | SNRIs, MAOIs, tricyclic antidepressants | FDA class, FDA Office of Women's Health |
   | triptans | FDA class |
   | combined hormonal contraceptives, combined oral contraceptives | FDA guidance |
   | oral contraceptives, hormonal contraceptives, progestin-only contraceptives, progestin-only pills | FDA Office of Women's Health |

2. **Contraceptives are defined, not listed.** A drug is a hormonal
   contraceptive when its own label's uses say it prevents pregnancy and it
   contains an estrogen or a progestin, by the FDA's Estrogen and Progestin
   classes and norgestrel from the Birth Control page. It is combined when it
   contains an estrogen, since no contraceptive is an estrogen alone, and
   progestin-only otherwise; oral by its route. Menopause and fibroid products
   with the same hormones are left out by their uses. A test names every
   contraceptive left out and why, so a new pill whose hormones the table
   does not list fails the build.
3. **Resolved against the bundle when the app is built.**
   `tools/scripts/gen_medicine_groups.py` reads the committed bundle, no
   network, and writes `medicine_groups_bundled.dart` with the drugs each group
   covers by key. CI's `--check` fails on a member that names no drug in the
   bundle, which catches a typo; on one listed absent that a refresh has
   brought in; on a phrase no bundled label prints; and on a stale file. A Dart
   test fails when the bundle was rebuilt and the groups were not.
4. **Two findings more.** A group both medicines are in, said in its narrowest
   form ("combined oral contraceptives" rather than that and "hormonal
   contraceptives" too), and not where an FDA class both are in has said it.
   And a passage naming a group the other medicine is in, quoted like any
   mention, with the table's sources under it. A group's phrase does not count
   straight after "non" ("non-hormonal contraception"), inside a longer group
   phrase ("hormonal contraceptives" in "combined hormonal contraceptives"
   names only the combined ones), or in a sentence another mention already
   quotes. Names and classes are matched as ADR-0014 has them.
5. **Recorded contraception in the flags.** A record of the combined pill, the
   mini pill, the hormonal IUD or the implant that runs today counts as what
   every product of its kind in the bundle shares, since the record does not
   say which product: the groups they are all in, and the ingredients they all
   contain, which is levonorgestrel for the IUD, etonogestrel for the implant,
   and no one ingredient for either pill. It is compared with each recorded
   medicine, and its card is searchable online like any pair's. A kind whose
   own product is among the recorded medicines takes no part: that medicine
   stands for it, with its own label. The other conditions take no part.

### Runner-up and why rejected

**The FDA's classes alone.** Nothing hand-written, but sparse in this data and
broad in places, as above: it would leave sertraline out of SSRIs and put
trazodone in.

**NLM MeSH pharmacological actions.** Broader still: its serotonin uptake
inhibitors take in olanzapine.

**CYP3A4 inhibitors and inducers**, from the FDA's table of examples. Labels
qualify them too many ways: "strong", "strong or moderate", "potent", "after
stopping a CYP3A4 inhibitor". An unqualified "CYP3A4 inhibitors" found inside
"strong CYP3A4 inhibitors" would name drugs the label does not mean. Deferred.

**Anticoagulants.** No current FDA page lists them that could be checked, and
the FDA's "Anti-coagulant" class in this data takes in citric acid. Deferred.
Labels mostly name warfarin and the rest by name, which is matched already.

**Asking which pill a recorded combined pill is.** The record is a kind. A
person who knows the product can add it to the medicines, where it stands for
the kind.

### Consequences

- Tranexamic acid and the pill connect, as do rifampin and every hormonal
  contraceptive, lamotrigine and combined oral contraceptives, and tramadol
  and the antidepressants, in the checker and in the flags.
- The table is a reading of its sources, and has to be kept like one. A
  refresh of the bundle can move its members, and the check says so; its
  sources are dated where they were read.
- A group's name can be read in a sense its label does not quite mean: "oral
  contraceptives containing ethinyl estradiol" names a progestin-only pill as
  well. Every mention is quoted with its sources, as every mention is.
- A recorded combined pill counts as no one ingredient, because not every
  combined pill has ethinyl estradiol. A label that names only ethinyl
  estradiol connects with the pill once the pill itself is recorded.
- Where nothing connects, the screens still say that this does not mean safe
  together, and now name groups the check does not know: anticoagulants, and
  strong CYP3A4 inducers.
- The groups add about 27 KB of generated Dart, read once when first used.

## ADR-0022: Medication Guides carry their safety sections only, and a guide whose dosing cannot be left out is left out whole

**Status:** Accepted, 2026-10-28. Keeps the rule of [ADR-0009](#adr-0009-medicines-reference-data-is-generated-at-build-time-from-openfda) and [ADR-0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) that no dosing is carried.
**Deciders:** Project owner

### Context

The owner asked for Medication Guides on each medicine's page: the leaflets
the FDA requires for some drugs, written for patients, which openFDA carries
in the label export as `spl_medguide`. About one label in twelve has one.

A guide is laid out by 21 CFR 208.20 as questions, and one of them is "How
should I take ...?", which is dosing. The medicines reference has never
carried dosing: a dose read off a US label and applied to a packet bought
elsewhere is the harm it exists to avoid. openFDA carries a guide as one run of
text with its headings inline, so leaving that section out means finding the
headings in prose. Tried on a whole partition of the export, cutting the
dosing heading alone leaked dosing into what was kept. A heading misspelt on
the label ("How shlould atomoxetine capsules be taken?") is not found, and a
quoted cross-reference ('See " What are the possible side effects...? "') is
taken for a heading and splits the section in two. Either way, missed-dose
instructions land in the section before.

The bundle had been built from the 2026-10-02 export, which openFDA has since
replaced, so a guide could only come from the same label the bundle shows by
building the bundle again.

### Decision

1. **The guide comes from the label the bundle already shows**, in the same
   pass over the export, and is stored with the drug's sections as `[heading,
   text]` pairs. The index counts them.
2. **Only the safety sections are carried, by their headings in 21 CFR
   208.20:** the most important information; what the medicine is; who should
   not take it; what to tell a healthcare provider first; what to avoid; its
   possible side effects; and, in antidepressants' guides, how to watch for
   suicidal thoughts. Not how to take it, how to store it, or what is in it.
3. **Fail closed.** A guide is carried only when one of its first three
   headings is the most important information, which 21 CFR 208.20 puts
   first. Nothing that would be carried may read as dosing:
   - a missed, next, double or extra dose;
   - a how-often, such as "two times a day" or "every 12 hours";
   - an instruction to take, use or inject something that gives an amount or
     a frequency;
   - outside the most important information, any instruction to take, mix,
     inject or swallow at all.

   A guide that fails any of these is left out whole, not cut further. A
   question after an opening quote mark is a cross-reference, not a heading.
4. **Shown folded** at the foot of the medicine's page, under a note that says
   what it is and that how to take the medicine is left out, and why.
5. **The bundle is rebuilt from the 2026-10-28 export.** It holds 5,687 drugs,
   506 of them with a guide. 45 guides were left out for dosing and 41 for a
   layout the rules do not recognise.

### Runner-up and why rejected

**The whole guide, dosing included, behind a warning.** It contradicts the
reference's rule that dosing is not carried at all, rather than carried and
hidden.

**Cutting only the "How should I take" section.** It leaked, as above.

**Patient package inserts**, the leaflets that come with the pill. They have
no fixed layout to find their dosing in. Left out.

**Fetching guides from openFDA's API by set id**, without a refresh. The API
serves each label's newest version, so a guide could be from a later version
than the label shown above it.

### Consequences

- The rules are a reading of prose, and they over-reject on purpose. OxyContin's
  guide warns in its most important information "Do not take more than 80 mg
  of OxyContin in one day", which is a safety limit the label above it carries
  too, and the guide is left out for it. A guide whose side effects run on from
  a heading the rules missed is left out as well. A refresh reports the counts,
  and `docs/RELEASE.md` says what a drop in them means.
- A test reads every guide in the committed bundle against the same rules, so
  a loosened rule, or a bundle edited by hand, fails the build.
- The interaction checker does not read guides. ADR-0014's sections are
  unchanged.
- The bundle is 13.3 MB, inside ADR-0013's 16 MB. The refresh dropped 148 drugs
  that openFDA no longer links to a current listing; the group table resolved
  against it unchanged (ADR-0021).

---

## ADR-0023: Herbal supplements are NCCIH's public-domain fact sheets, compared with medicines by their safety section

**Status:** Accepted, 2026-10-28. Extends the matching of [ADR-0014](#adr-0014-the-interaction-checker-compares-label-text-and-never-calls-a-pair-safe) to herbs, and holds them to [ADR-0022](#adr-0022-medication-guides-carry-their-safety-sections-only-and-a-guide-whose-dosing-cannot-be-left-out-is-left-out-whole)'s rule that no dosing is carried.
**Deciders:** Project owner

### Context

The owner asked for a Supplements A to Z of public-domain NIH pages on
supplements such as St. John's wort, "so they can be compared with medicines
too". Herbs are where a period tracker's users meet interactions they do not
expect: St. John's wort makes the pill less effective, and many take
chasteberry, black cohosh or evening primrose oil for their cycle.

The US National Center for Complementary and Integrative Health (NCCIH), part
of the NIH, publishes Herbs at a Glance: a fact sheet on each of 56 herbs, each
with the same sections, from the background to "Keep in Mind". Every sheet says
"This publication is not copyrighted and is in the public domain." Its
photograph is credited to a photographer and is not.

The app already had a page called Supplements, under Learn, about nutrition,
which the owner hid behind a ten-second hold.

### Decision

1. **The sheets are fetched at build time and carried as NCCIH wrote them**,
   as the medicines are (ADR-0009): `tools/scripts/gen_supplements.py --fetch`
   reads the index and every page it links to, keeps the pages that carry the
   public-domain statement, and writes `app/assets/supplements/nccih_herbs.json`,
   about 260 KB. Kept: the title, the common and Latin names, the sections up
   to "Keep in Mind", the date the sheet was last updated, its address, and
   NCCIH's disclaimer. Left out: the photograph and its credit, the links and
   the references. A list item keeps the mark the page draws for its depth, so
   that a list of medicines stays under the line that says why it is there.
2. **No dosing**, by ADR-0022's rules: a sheet with an instruction to take an
   amount of something would be left out whole. None has one. A sentence about
   what dose a study used, as goldenseal's does, is not an instruction.
3. **Found on Look something up, as "Herbal supplements A to Z"**, and by
   searching any of a herb's names. Not under Learn, so it does not collide
   with the nutrition page, which stays behind its hold.
4. **Compared with medicines in the interaction checker, by the safety section
   only.** For a herb and a medicine:
   - the medicine's label is searched as for another medicine (ADR-0014) for
     any of the herb's names, as one name, so "St. John's Wort (Hypericum
     perforatum)" is found once;
   - the herb's safety section, "What Do We Know About Safety?", is searched
     for the medicine's names, FDA classes and groups (ADR-0021): "Birth
     control pills" names the oral contraceptives, under the line its list
     hangs from;
   - a medicine whose own ingredients include the herb, as many homeopathic
     remedies' do, is said to contain it, and its label is not searched for a
     name it is talking about itself by.
5. **The names looked for are NCCIH's own**, worked out by the generator: the
   title and every common and Latin name, without notes in parentheses unless
   they give another name ("synonym Crataegus oxycantha"), also without a
   possessive's apostrophe and a hybrid's "x". Not an abbreviation: "EPO" is
   erythropoietin too. The generator refuses a name two herbs share.
6. **Herbs are not compared with each other.** No sheet's safety section names
   another of the herbs, and two herbs have no label between them. The checker
   says so when it lists two.

### Runner-up and why rejected

**NIH Office of Dietary Supplements fact sheets.** They cover vitamins and
minerals as well as herbs, and the vitamin and mineral sheets are built around
recommended intakes, amounts this app does not carry.

**MedlinePlus herbs and supplements.** Its pages came from the Natural
Medicines Comprehensive Database, which is licensed rather than in the public
domain, and MedlinePlus said in July 2025 that they were no longer available.

**A hand-written table of herb and drug interactions.** It would be the app's
own claims, with no source a reader could check, which ADR-0014 rejected for
medicines.

**Recording herbs under Conditions and medication**, so they join the conflict
flags. Recorded medicines are bundle keys (ADR-0015); herbs would need a second
kind of record. Left for when it is asked for.

### Consequences

- A sheet names only some of the medicines a herb interacts with, and often by
  a kind this matching cannot see: "some antidepressants", "drugs that affect
  serotonin". A herb and a medicine with nothing found get the same refusal
  to call them safe as two medicines, and the same way out to a search.
- Names are matched as labels print them, and labels print some loosely: a
  label's "ginseng" is not NCCIH's "Asian ginseng", and is not found.
- The bundled font has the bullet and not the hollow bullet or square the
  sheets nest lists with, or the black circle many Medication Guides use. The
  marks are drawn instead, on the herb pages and the guides alike.
- The reference is refreshed with `--fetch`; `--check` fails CI when the asset
  and its generated Dart disagree, or a sheet loses its safety section.

---

## ADR-0024: The summary for a doctor is a PDF the app writes itself, with CSV files of the same data, and neither holds intercourse

**Status:** Accepted, 2026-10-28. Saves where [ADR-0019](#adr-0019-a-backup-can-be-protected-with-a-passphrase-and-an-unprotected-one-still-restores)'s backups do, and keeps the app's dependency rule of [ADR-0004](#adr-0004-unencrypted-local-sqlite-with-zero-network-permission).
**Deciders:** Project owner

### Context

The owner asked for something to take to a doctor: a PDF summary of "cycle
lengths, period dates, symptoms, conditions and medicines over a chosen span,
as a printable file saved where you choose", and the same data as a
spreadsheet file "for anyone who wants to analyse it themselves". The JSON
backup holds everything, but it is for the app to read back, not for a person.

A summary is read by someone other than the person who recorded it, and a
spreadsheet may travel further. `docs/PLAN.md` 6.5 says to plan for that.

### Decision

1. **One summary, two files.** `CycleSummary` is built from the whole record
   over a span: the last 3, 6 or 12 months, or everything. It holds the logged
   days in the span, which day of its cycle each was, the cycles that started
   in it, the conditions that ran during it, and the medicines recorded. Both
   files are made from it, so they cannot disagree.
2. **The PDF is written by the app itself** (`pdf_document.dart`): text in
   Helvetica and Helvetica Bold, the base fonts every reader has, in
   WinAnsiEncoding; A4 pages with numbered footers; tables that wrap and carry
   their header onto a new page. It holds the figures a doctor reads first
   (periods started, median cycle length and range, median days of bleeding),
   a table of the periods, the symptoms by days and severity, the
   measurements, the conditions with their dates, and the medicines.
3. **The cycle figures count what prediction counts.** A cycle the app flags
   (ADR-0003's validation) is listed with why, and left out of the medians.
4. **The spreadsheet is three CSV files**: the logged days, the cycles, and
   the conditions and medicines. The columns are the backup's keys and the
   values its names, dates are `YYYY-MM-DD`, and the files follow RFC 4180
   with CRLF line endings. Temperatures are in Celsius, with a Fahrenheit
   column beside them for someone who reads Fahrenheit.
5. **Intercourse is in neither.** `SummaryDay` has no field for it, and
   `intercourse_isolation_test.dart` fails if the summary's code names it. The
   question asked before a summary is made says so.
6. **Saved to a folder the user chooses**, as a backup is, with nothing sent
   anywhere. A file's name holds only the span, since names are read where
   contents are not.
7. **Medicines are listed as the list stands.** It has no dates (ADR-0015),
   and the PDF says so rather than implying they ran across the span.

### Runner-up and why rejected

**The `pdf` package.** It does everything this needs and much more, and
brings `image`, `archive`, `barcode` and others into the app to draw text
and rules. Writing the little PDF needed is a few hundred lines that a test
can check byte by byte. `printing`, the usual partner, depends on `http`.

**One CSV in a long format** (a row a fact: date, kind, name, value). One file
instead of three, but a spreadsheet user would have to pivot it before it
said anything.

**Predictions in the summary.** A prediction is not a record, and a range on a
doctor's desk is easily read as a date. Left out.

### Consequences

- The PDF can set only WinAnsi's characters. The app is in English, and a
  character outside them is written as "?". A translation into a language
  with other letters would need a font embedded.
- The PDF is untagged, so a screen reader reads it less well than the app.
  The app itself, and the CSV files, remain the accessible way in.
- The medians are the app's own statistics, not a clinical calculation, and
  the PDF says it is a personal record and not a diagnosis.

## ADR-0025: The late-period check-in has a switch of its own, and medicine reminders repeat every day in the phone's own time zone

**Status:** Accepted, 2026-10-28. Keeps the late notice's date where [ADR-0016](#adr-0016-a-late-period-moves-the-range-forward-and-lost-track-counts-from-the-last-period) put it, and stores the reminder times beside the medicines as [ADR-0015](#adr-0015-recorded-medicines-are-kept-as-a-setting-and-their-flags-only-inform) stores those.
**Deciders:** Project owner

### Context

The owner asked for "one gentle notification when the expected range has
passed with no period logged, linked to the late-period fix", and for
"reminders to take recorded medicines at times you set", all of them "local
notifications from the phone, with lock-screen detail off by default".

The first is nearly there already: the late notice, five days after the
window first predicted has closed, has been planned since AND-17. It came with the
switch for the reminders before a period, so it could not be had on its own,
and its wording predates the late-period fix.

The second is new in kind. Every notification so far goes off once, on a
date, and is scheduled as an instant in UTC worked out from the phone's own
clock (`schedule_time_test.dart`), which is right for a single date. A daily
reminder is repeated by Android at the same time on the clock **in the zone it
was scheduled in**. Scheduled in UTC, a reminder set for 08:00 goes off at
07:00 or 09:00 once the clocks change, until the app is next opened.

### Decision

1. **The late-period check-in is the late notice with a switch of its own**,
   "Check in if a period is late". Until it is set it follows "Remind me
   before a period is due", which it was part of, so nobody's notifications
   change on update. It speaks as the app does about a late period ("Later
   than expected", "The expected range has passed with no period logged"),
   and carries the one-tap "Started today" action, as the likely-started
   notice does. Its date stays where ADR-0016 put it.
2. **Medicine reminders are times set on each recorded medicine**, under
   Conditions and medication: up to four, each every day. They are a second
   setting beside the medicines, a medicine's key to its times, so they travel
   in exports and go with "delete everything" with no change to the export
   format. Removing a medicine removes its times. Settings has a row that says
   where they are set and goes there.
3. **They have a channel of their own**, so that muting one kind of
   notification does not mute another (risk R15), and are marked as reminders,
   so a phone set to let reminders through Do Not Disturb lets them through.
   Nothing about the cycle, its prediction or its switches touches them.
4. **Without lock-screen detail, a reminder names no medicine.** Its title is
   the app's name, as every notification's is, and its body is "The reminder
   you set for 08:00". Not the generic body, which says to open the app to see
   what a notification is about, because the app has nothing to show for a
   reminder someone set themselves. With detail on, the title names the
   medicine. Without it, a locked screen shows none of it, as for the others.
5. **Scheduled in the phone's zone, by name.** `MainActivity` answers one
   method channel with `TimeZone.getDefault().id`, the zone is found in the
   `timezone` package's full database, and the plugin repeats the reminder at
   the same time on the clock in that zone. The full database because Android
   still names some zones by older names, `Asia/Calcutta` among them, that the
   smaller files leave out. If the zone cannot be found, the reminder is
   scheduled for the same moment in UTC: right until the clocks next change,
   and put right the next time the app reschedules.
6. **The permission is asked for when a reminder is set**, the one other
   moment a notification has visibly been asked for. It counts as the app's
   one request. If notifications are off, the reminder is kept and the app
   says it cannot arrive until they are allowed.
7. **Rebuilt with everything else.** Every reschedule still cancels all and
   schedules all, the reminders included, and `NotificationSync` watches the
   times, so setting, changing or removing one, an import, or deleting
   everything reaches the platform without each having to ask. The cancel
   takes the cycle's notices off the screen as well, as before, but a medicine
   reminder that has gone off stays until it is seen to: the app reschedules
   whenever it is opened, and a reminder that vanished then could be why a
   dose was missed. They are left out of the missed-reminder check: they
   repeat every day, so every closed day would read as one missed.
8. **Inexact, as every notification here is.** A reminder can arrive a few
   minutes after its time. Exact alarms need a permission the user grants in
   system settings.

### Runner-up and why rejected

**The `flutter_timezone` package.** It answers the same question through a
plugin. `MainActivity` answering one method is a few lines and adds nothing.

**The smaller time zone data** (`latest_10y`, 66 KB against 445 KB). It lacks
the older names Android reports, and a zone it cannot find falls back to UTC.
The full database is loaded only when a medicine reminder is scheduled.

**Repeating in UTC.** No zone needed, but an hour out for half the year
wherever the clocks change, until the app is opened.

**Following the phone into a new zone by itself**, with a receiver for the
zone changing. Some medicines are timed by the hours since the last dose
rather than by the clock, and a reminder that moved after a flight would be
wrong for those, with no way for the app to tell which is which. The
reminder moves when the app is next opened instead.

**A record of doses taken.** Not asked for. The reminders remind and record
nothing.

### Consequences

- After travelling, a reminder keeps to the zone it was set in until the app
  is next opened.
- With detail on, Android keeps a medicine's name in a scheduled reminder's
  wording outside the encrypted database, as it already keeps the predicted
  dates (`docs/PRIVACY.md` says so).
- The Kotlin half is checked as source by `main_activity_test.dart` and built
  by CI, but run only on a phone: `docs/RELEASE.md` has the check.
- The time zone database adds about 0.45 MB to each APK.

---

## Backlog of deferred decisions

Recorded so they are not silently re-litigated. Promote to a numbered ADR when the decision is actually made.

| Topic | Trigger to decide | Current lean |
| --- | --- | --- |
| [App lock](#deferred-note-app-lock) | First post-MVP privacy work | **Do it first.** Closes the largest gap in ADR-0004. See the note below |
| Play Store distribution | Only if the app leaves personal use | Skip; sideload is sufficient and avoids the health-app policy surface |
| [iOS build](#deferred-note-ios-build) | Only once MVP has been dogfooded for a month **and** a real iOS user exists | **Skip by default.** Cheaper than native, but not free, and it weakens the core privacy claim. See the note below |
| Ovulation range estimation | Only after the calibration story is solid | Off by default if ever added, and never framed as contraception |
| Hydra instead of pydantic-settings | If backtest sweeps exceed roughly 50 configurations | Switch at that point; not before |
| DVC or similar for data versioning | If datasets exceed a few hundred MB or multiply | Checksums in `DATASETS.md` are sufficient today |
| `executorch` on the research side | When Tier B (AND-20) starts | Verified at PY-A that the `edge` extra resolves on Python 3.11 Windows (`executorch==1.4.1`, `torch==2.13.0`), which de-risks ADR-0006's authoring half. Kept out of the default install and out of `requirements.txt` until Tier B actually begins |
| `freezed` pinned to a **pre-release** (`^4.0.0-dev.3`) | When `freezed` 4.0.0 stable ships | Move to stable. Accepted deliberately: `freezed` 3.2.5 emits invalid Dart against the Dart 3.13 SDK (`final` on named parameters for any collection field), so the pre-release is currently the only version that generates compiling code. Alternatives weighed and rejected were pinning Flutter back to 3.44.9, and dropping codegen for hand-written models |

---

## Deferred decision notes

Fuller write-ups for the two backlog items most likely to be picked up next. These are proto-ADRs: they carry a lean and a rationale but have not been decided. Promote to a numbered ADR when acted on.

### Deferred note: App lock

**Status:** Deferred, **first in the queue**
**Relates to:** [ADR-0004](#adr-0004-unencrypted-local-sqlite-with-zero-network-permission), [ADR-0001](#adr-0001-flutter-and-dart-for-the-android-application), PLAN.md 2.4.3 and 6.5

#### Why it is deferred, and why it is nevertheless first

ADR-0004 accepted a plaintext database. The threat-model table in PLAN.md 6.5 lists exactly one uncovered everyday threat: **a curious person picking up an unlocked phone.** An app lock closes that specific gap, and it is far cheaper than the SQLCipher migration that would close the forensic-imaging gap. Deferred because it is not needed for the app to be useful; first in queue because it is the highest privacy value per unit of effort in the whole backlog.

#### Design lean

| Choice | Lean | Reason |
| --- | --- | --- |
| Mechanism | `local_auth` with biometric **plus device-credential fallback** | Delegates to the OS, which is the only party positioned to do this properly |
| Custom PIN | **No** | A hand-rolled PIN over an unencrypted database is theatre. It adds a credential to store, a lockout policy to design, and a false sense of security, while protecting nothing that the OS lock screen does not already protect better |
| Enforcement point | A `go_router` route guard | One of the reasons ADR-0001 chose declarative routing. The guard is a few lines and cannot be bypassed by deep link |
| Timeout | Configurable, default lock on background after 30 seconds | Immediate re-lock on every app switch is the fastest route to the user turning the feature off |

#### The honesty requirement

**An app lock over an unencrypted database is a UI gate, not a security boundary.** It stops a person who picks up your phone. It does not stop anyone with file-level access, ADB, or a forensic image. The Settings copy must say this plainly.

This matters more than it looks. A lock that creates false confidence is arguably **worse than no lock**, because a user who believes the data is protected may log more sensitive detail than they otherwise would. The feature must not be described as encryption.

#### Interactions to handle at implementation time

- **Notifications (PLAN.md 2.4.3, risk R16).** If the app lock is enabled, notification content should force to lock-screen-secret regardless of the user's content preference, or at minimum warn on the toggle. A locked app whose notifications announce cycle state on the lock screen defeats itself.
- **Accessibility (PLAN.md 2.4.4).** Biometric must never be the only path. The device-credential fallback is mandatory, and the prompt needs a screen-reader-navigable route. Users without enrolled biometrics, or who cannot use them, must not be locked out of their own data.
- **Sequencing versus SQLCipher.** Build the lock **before** encryption, not after. If SQLCipher lands later, the lock's authentication step becomes the natural key-release point, so building it first means the encryption work slots into an existing prompt instead of introducing a second one.

#### Cost and trigger

Roughly 1 to 2 sessions. Trigger: the first post-MVP session, or immediately if the device is ever shared or lost.

**[VERIFY]** `local_auth` behaviour when no biometric is enrolled and no device credential is set. That path must degrade to "lock unavailable, explain why", never to a hard lockout.

### Deferred note: iOS build

**Status:** Deferred, no trigger met
**Relates to:** assumption A2, [ADR-0001](#adr-0001-flutter-and-dart-for-the-android-application), [ADR-0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely)

#### What Flutter genuinely gives you free

All of `lib/domain/`, `lib/data/`, the Bayesian filter, the priors artifact, the golden vectors, and every Dart test are platform-neutral and port at zero cost. This is the real payoff of the ADR-0002 boundary, and it is not a small share of the codebase.

#### What is not free

| Area | Cost |
| --- | --- |
| Notifications | Different permission model, no exact alarms, different background scheduling limits. `flutter_local_notifications` covers the API, but the **behaviour** differs enough that the PLAN.md 2.4.3 design needs a full iOS pass, including whether the 1-tap action button behaves the same |
| Export and import | Share-sheet and file-picker semantics differ; the round-trip tests need an iOS variant |
| App lock | Needs `NSFaceIDUsageDescription`; the Face ID prompt flow differs from the Android biometric flow |
| **Tier B (ExecuTorch)** | Would need a **second platform channel in Swift**, doubling the ADR-0006 channel work. ExecuTorch does support iOS with CoreML and MPS backends, so the runtime exists; the channel is per-platform and does not port |
| Hard costs | A Mac or a macOS CI runner. An Apple Developer Program membership for anything beyond 7-day free provisioning. App Store review if distributed, which brings health-app policy and a privacy nutrition label |

#### The finding that actually decides this

**iOS has no equivalent of Android's manifest-level permission declaration, so the project's strongest privacy guarantee does not port.** On Android, "this app has no INTERNET permission" is a fact the OS enforces and `assert_no_network.sh` proves in CI on every build. On iOS there is no such declaration to remove and no such artifact to assert against. The closest available substitutes are a dependency audit and, at best, a sandboxed network test, neither of which is proof.

Shipping iOS therefore means either weakening the central claim or making it platform-conditional in `PRIVACY.md`: "on Android, network access is impossible; on iOS, we do not make network calls." Those are materially different promises, and the second one is the ordinary promise every app makes.

#### Lean

**Skip unless a specific real person wants it.** For a personal project on an Android phone this is pure cost against a guarantee that gets weaker. The `.gitignore` already carries the iOS entries, so adding the platform later is a clean diff rather than a rewrite.

Trigger: MVP dogfooded for a month **and** an identified iOS user. Both conditions, not either.
