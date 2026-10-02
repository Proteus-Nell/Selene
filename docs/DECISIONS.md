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
| [0004](#adr-0004-unencrypted-local-sqlite-with-zero-network-permission) | Unencrypted local SQLite with zero network permission | Accepted | 2026-08-17 |
| [0005](#adr-0005-uv-with-python-311-wsl2-for-gpu-work-jdk-17-pinned-for-android-mlflow-local-only) | uv + Python 3.11, WSL2 for GPU, JDK 17 pinned, MLflow local-only | Accepted; clause 2 (WSL2 scope) narrowed by [0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely) | 2026-08-17 |
| [0006](#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely) | PyTorch and ExecuTorch replace TensorFlow and LiteRT entirely | Accepted | 2026-08-17 |
| [0007](#adr-0007-named-cycle-phases-shown-by-default-ovulation-estimation-still-opt-in) | Named cycle phases shown by default, ovulation estimation still opt-in | Accepted | 2026-08-20 |
| [0008](#adr-0008-app-lock-gates-the-interface-and-does-not-encrypt-the-database) | App lock gates the interface and does not encrypt the database | Accepted | 2026-08-20 |
| [0009](#adr-0009-medicines-reference-data-is-generated-at-build-time-from-openfda) | Medicines reference data is generated at build time from openFDA | Accepted; allowlist superseded by [0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) | 2026-08-20 |
| [0010](#adr-0010-long-term-conditions-are-recorded-not-modelled) | Long-term conditions are recorded, not modelled | Accepted | 2026-08-20 |
| [0011](#adr-0011-export-v2-refuses-v1-files) | Export v2 refuses v1 files | Accepted | 2026-08-20 |
| [0012](#adr-0012-the-medicines-reference-covers-every-drug-one-label-each-chosen-by-rule) | The medicines reference covers every drug, one label each, chosen by rule | Accepted | 2026-10-02 |
| [0013](#adr-0013-the-medicines-bundle-is-compressed-chunks-and-an-index-searched-on-the-phone) | The medicines bundle is compressed chunks and an index, searched on the phone | Accepted | 2026-10-02 |

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

**Status:** Accepted, 2026-08-17
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

**Status:** Accepted, 2026-08-20
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

## Backlog of deferred decisions

Recorded so they are not silently re-litigated. Promote to a numbered ADR when the decision is actually made.

| Topic | Trigger to decide | Current lean |
| --- | --- | --- |
| [App lock](#deferred-note-app-lock) | First post-MVP privacy work | **Do it first.** Closes the largest gap in ADR-0004. See the note below |
| SQLCipher migration | If the threat model changes, or before any wider distribution | Do it; the migration path is designed in |
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
