# Period-Tracker: Project Plan

**A fully offline Android period tracker with on-device personalized prediction.**

| Field | Value |
| --- | --- |
| Document status | Draft v1, planning only, no implementation code yet |
| Owner | Mahmoud Yasser Mokhtar Sallam |
| Date | 2026-08-17 |
| Target deliverable | Signed release `.apk`, sideloadable, no network permission |
| Timeline | Unlimited (personal project) |
| Companion docs | [DECISIONS.md](DECISIONS.md) (ADR log), [ANDROID_TASKS.md](ANDROID_TASKS.md) (promptable Android task breakdown) |

---

## 0. TL;DR

Build a Flutter/Dart Android app that stores cycle logs in a local SQLite database, never touches the network, and predicts the next period with a **hierarchical Bayesian state-space model that updates on the user's own data, on the device**. The model's population-level hyperpriors are fitted offline in Python (this is where the RTX 4070 and your Python skills live), exported as a small JSON constants file, and re-implemented in pure Dart. A generated set of **golden test vectors** keeps the Python reference and the Dart production implementation bit-comparable. An ExecuTorch on-device-training head is deferred to Phase 3 and gated behind a per-user backtest so it can only ship if it actually beats the Bayesian baseline.

The single most important product decision: **never show a bare predicted date.** Always show an interval and a confidence state. Period prediction is inherently uncertain and overconfident UI is the main way this class of app causes harm.

---

## 1. Scope reconciliation and assumptions

### 1.1 What changed from the original brief

The task template asked for MediaPipe, webcam capture, glossing limitations, and Deaf community review. Those belong to a sign-language recognition project, not a period tracker. You confirmed the scope. This plan therefore:

- Replaces MediaPipe/webcam with **local user-logged event data**. Section 1 still calls out real PyTorch and ExecuTorch version constraints, because those are the analogous binding constraint on this project.
- Replaces "overclaiming translation capability" with **overclaiming contraceptive and medical capability**, which is the direct analogue and is a genuine regulatory and safety line.
- Replaces "Deaf community involvement" with **involvement of people who menstruate**, including users with PCOS, endometriosis, perimenopause, and trans and nonbinary users.
- Replaces "glossing limitations" with **modeling limitations** (what the model structurally cannot know).

### 1.2 Confirmed decisions (from your answers)

| Question | Your answer | Consequence for this plan |
| --- | --- | --- |
| Scope | Period tracker with on-device ML | Keeps a real Python research pipeline plus a Dart production runtime |
| Prediction approach | On-device personalized learning | No shipped pre-trained global model is required for MVP; the model personalizes from the user's own logs |
| App stack | Flutter / Dart | Monorepo with `app/` (Dart) and `research/` (Python) |
| Privacy posture | Plain local DB, no network | Drift/SQLite unencrypted, zero INTERNET permission, documented accepted risk plus migration path |

### 1.3 Assumptions (stated, not verified with you)

| # | Assumption | Impact if wrong |
| --- | --- | --- |
| A1 | Single user per device. No multi-profile, no account, no sync, ever. | Multi-profile would require a profile dimension in every table; cheap now, expensive later |
| A2 | Android only. No iOS build, no web build, no desktop build (except Flutter desktop as a **test target** for fast unit tests). | iOS adds signing, App Store review, and a second notification stack |
| A3 | Distribution is sideload / personal use. Play Store is optional and out of MVP scope. | Play Store adds a Data Safety declaration, health-app policy review, and a signing key you must never lose |
| A4 | English only for MVP, but the code is localization-ready from day one (`flutter_localizations`, no hardcoded UI strings). | Retrofitting l10n after the UI is built is a multi-day refactor |
| A5 | The app is **not** a contraceptive aid and will not present a "safe day" or a contraceptive fertile window. It may optionally show an estimated ovulation range clearly labelled as an estimate. | Contraceptive claims move this into medical-device regulation |
| A6 | Minimum viable history for personalization is 1 completed cycle; before that the app shows the population prior and says so. | A higher threshold means a longer cold-start dead zone |
| A7 | Your daily driver is Windows 11. WSL2 is optional and is needed only for JAX GPU acceleration. | PyTorch supports native Windows CUDA, so no part of the Tier B path requires WSL2 (see 3.8) |
| A8 | No PHI is ever transmitted, including in crash reports. Crash reporting is local-file only. | Any cloud crash reporter breaks the offline guarantee |

---

## 2. Product scope and MVP definition

### 2.1 MVP (Milestone M3, "usable daily")

- [ ] Log a period start and end date; edit and delete any past entry
- [ ] Log daily flow intensity (none / spotting / light / medium / heavy)
- [ ] Log a small fixed symptom set (cramps, headache, mood, energy, sleep) with intensity 0-3
- [ ] Month calendar view with period days, predicted window, and today marker
- [ ] Next period prediction shown as a **range with a confidence band**, never a single bare date
- [ ] Cycle history list with per-cycle length and a running median / variability readout
- [ ] Local notification reminder N days before the predicted window opens (user-configurable, default 2)
- [ ] Full JSON export and import to a user-chosen file location
- [ ] One-tap "delete all data" with a typed confirmation
- [ ] Zero network permission in the release manifest, verified by an automated APK check
- [ ] Dark mode, gender-neutral copy, and a first-run disclaimer screen
- [ ] "Period started today" reachable in **2 taps from cold start**, and in **1 tap** from a notification action button
- [ ] Backdating a start by 1 to 3 days takes 3 taps or fewer (people log late; design for that, not for the same-day case)
- [ ] Separate notification channels per notification type, so one can be muted without losing the others
- [ ] `POST_NOTIFICATIONS` requested **in context** after the first cycle is logged, never at first launch
- [ ] Notifications reveal **no cycle content on the lock screen** by default, with detailed content behind an explicit opt-in
- [ ] Accessibility CI gate green: contrast, tap-target size, and labelled-tap-target guidelines
- [ ] Calendar day cells and charts carry semantic labels; layout usable at 200% text scale

### 2.2 Explicitly out of MVP

Basal body temperature and cervical-mucus logging, ovulation-test integration, wearable import, PDF reports, home-screen widgets, backup encryption, app lock, multi-profile, cloud anything, Play Store listing, iOS.

Two of these are deliberately queued rather than dismissed: a **home-screen widget** is the highest-value post-MVP change for logging consistency (see 2.4), and an **app lock** is the highest-value post-MVP change for privacy (see [ADR-0004](DECISIONS.md#adr-0004-unencrypted-local-sqlite-with-zero-network-permission)). Both have full notes in the deferred-decision log.

### 2.3 Milestones

| M | Name | Exit criteria | Rough effort |
| --- | --- | --- | --- |
| M0 | Toolchain and skeleton | `flutter build apk --release` succeeds; `uv run pytest` green; CI green on both jobs | 1-2 sessions |
| M1 | Data layer | Drift schema + migrations + repository, 90% test coverage on `domain/cycles` | 2-3 sessions |
| M2 | Prediction core (Tier A) | Dart Bayesian filter passes all golden vectors emitted by Python at 1e-9 tolerance | 3-5 sessions |
| M3 | MVP UI + notifications | Every M3 checkbox above ticked, **including the accessibility CI gate and the 2-tap logging budget**; manual 2-week dogfood started | 5-8 sessions |
| M4 | Research rig | Backtest CLI, MLflow runs, Streamlit backtest explorer, calibration report | 3-4 sessions |
| M5 | Tier B on-device training | ExecuTorch `TrainingModule` runs a train step on device through the Kotlin channel; gate correctly rejects it on synthetic users where it should | 5-10 sessions, optional |
| M6 | Hardening | Export/import round-trip fuzz test, DST/timezone suite, release signing, APK network-permission assertion | 2-3 sessions |

The Android half of this roadmap is decomposed into 21 independently promptable tasks in [ANDROID_TASKS.md](ANDROID_TASKS.md), each with its own scope, out-of-scope list, acceptance criteria, and a ready-to-paste prompt. AND-01 through AND-19 is the MVP; AND-20 and AND-21 are the optional Tier B work.

---

### 2.4 Sustained use, notifications, and accessibility

This section exists because the original draft treated notifications as a single checkbox and accessibility as a value statement in the ethics section, enforced nowhere. Both are load-bearing, and both are now specified and gated.

#### 2.4.1 The honest reframe: logging consistency is a model input

There are no analytics in this project and there is no server, so retention and usage metrics in the conventional sense **cannot be measured here and are not the goal**. What matters is the mechanism underneath them.

**Sparse logs directly degrade prediction quality.** The Tier A filter updates once per completed cycle. A user who misses a start date produces a merged 60-day pseudo-cycle, which the Student-t observation model correctly treats as an outlier and responds to by *widening* the interval. Miss a few and the app returns `TooIrregular`. So making logging effortless is not a growth tactic bolted onto a health app, it is an **ML data-quality requirement**, and it belongs in this plan on those grounds.

**The guardrail that follows.** Do not import engagement mechanics from consumer apps. Streaks, loss-aversion nudges, guilt copy, and daily-open pressure are inappropriate on reproductive health data, where a gap in logging may reflect pregnancy, pregnancy loss, illness, an eating disorder, or simply not wanting to think about it. Optimize for **low friction**, never for **high pressure**. A user who stops logging for three months and returns must be met with "welcome back, let us re-establish your baseline", not a broken streak.

#### 2.4.2 Friction budget

Every number here is a testable budget, not an aspiration. Measure it by counting taps in the integration test.

| Path | Budget | How it is met |
| --- | --- | --- |
| Log "period started today" from cold start | **2 taps, under 3 seconds** | App opens directly to today's state. No splash, no dashboard interstitial. One persistent primary action |
| Log it from a notification | **1 tap** | Notification action button writes the log without launching the app |
| Backdate a start by 1 to 3 days | **3 taps** | An inline day stepper beside the primary action, not a modal date picker |
| Log symptoms for today | **4 taps** | Chips, not dropdowns. Last-used set surfaced first |
| Correct a wrong entry | **3 taps** | Every logged day is long-press editable directly from the calendar |

The design case to optimize is **"I am two days late noticing"**, not the same-day happy path. Real logging is retrospective, one-handed, and often wrong the first time.

#### 2.4.3 Notification design

| Type | Channel | Default | Trigger | Copy rule |
| --- | --- | --- | --- | --- |
| Window opening | `predictions` | On, 2 days before | Predicted window opens | Always a range, never a bare date |
| Likely started | `predictions` | On | Window open and no log for 1 day | Offer the 1-tap log action |
| Logging nudge | `reminders` | **Off** | No log for 7+ days with a cycle in progress. **Hard cap: 1 per 7 days** | Neutral and factual. No streaks, no guilt |
| Late notice | `predictions` | On | 5+ days past window close | Informational only. **Never mentions pregnancy** (see 6.2) |

Android requirements, each a common and costly mistake if skipped:

- **Separate notification channels per type** (Android 8+). Putting everything on one channel means a user annoyed by the nudge mutes the predictions along with it. Channel granularity is the difference between "I turned off one thing" and "I turned off the app".
- **Request `POST_NOTIFICATIONS` in context**, after the first cycle is logged and the value is visible, never at first launch. A first-launch prompt gets denied by reflex, and on Android 13+ re-asking after a denial is deliberately hard.
- **Lock-screen privacy is the default, not an option.** Notifications use `VISIBILITY_SECRET` or generic text ("Period-Tracker") unless the user explicitly opts into detailed content. A banner reading "Your period is expected tomorrow", visible to anyone glancing at the phone, is a real data leak. It is **the one place where this project's otherwise airtight offline privacy story leaks by default**, which is exactly why it is easy to miss: it is a notification-design decision with a privacy consequence.
- Inexact alarms, a `BOOT_COMPLETED` reschedule, and missed-reminder detection on next open, per risk R12.

The **notification action button is the highest-leverage item in this section**: it collapses the most common logging event to one tap, costs very little to build, and needs no widget infrastructure.

#### 2.4.4 Accessibility, machine-enforced

The original draft asserted accessibility as a value. Compare that with how the no-network guarantee is handled: an automated APK check that fails CI. Accessibility gets the same treatment, because Flutter ships the matchers to do it.

| Requirement | Target | Enforcement |
| --- | --- | --- |
| Text contrast | 4.5:1 body, 3:1 large text and UI | `meetsGuideline(textContrastGuideline)` in widget tests, in CI |
| Touch targets | 48dp minimum | `meetsGuideline(androidTapTargetGuideline)` |
| Labelled controls | every tappable has a semantic label | `meetsGuideline(labeledTapTargetGuideline)` |
| Calendar cells | each announces date **and** state ("14 March, period day 2, inside predicted window") | Hand-written `Semantics`. A grid of coloured cells is unreadable to a screen reader, and the calendar is the primary surface |
| Charts | `fl_chart` paints to a canvas and is **invisible** to screen readers | Wrap in `Semantics(label:)` carrying a text summary, plus a toggleable data-table view of the same numbers |
| Never colour alone | period, predicted, and today differ by shape or label too | Greyscale golden test |
| Text scaling | usable to 200% | Golden tests at `textScaler` 1.0, 1.5, and 2.0. Most Flutter layouts break here |
| Reduced motion | honour `MediaQuery.disableAnimations` | Manual review |

**[VERIFY]** the exact matcher names against the Flutter version you pin. They live in `flutter_test` and have been stable, but confirm at M0.

#### 2.4.5 Metrics without telemetry

There are no analytics, so the numbers go to the user instead of to a dashboard. All computed on device, all shown in Insights, none transmitted:

- "You logged 24 of 28 days this cycle."
- "Your last 5 predictions were within 2 days, 4 times." This is the model's own track record, reported honestly. It builds justified trust when the model is good, warns the user when it is not, and motivates logging without any pressure mechanic.
- "Your cycles have varied by about 4 days over the last 6 months."

Showing the model's own error rate to the user is unusual and worth doing. It is the structural counterweight to overclaiming (6.2): a model that continuously reports its own accuracy cannot quietly oversell itself.


## 3. Tech stack, languages, and dependencies

### 3.1 The two-runtime architecture (read this first)

This project has two runtimes and one contract between them.

| | Research runtime | Production runtime |
| --- | --- | --- |
| Language | Python 3.11 | Dart 3.x (Flutter) |
| Runs on | Your desktop (Windows + WSL2) | The user's phone |
| Purpose | Fit population hyperpriors, backtest, evaluate calibration, generate golden vectors, optionally export an ExecuTorch `.pte` | Store data, run the personalized filter, render UI |
| Ships to users | No | Yes |
| Artifacts it produces | `priors_v1.json`, `predictor_cases_v1.json`, `cycle_head_v1.pte` | The `.apk` |

**The contract:** the Python implementation in `research/src/cyclecore/models/bayes_filter.py` is the *reference*. The Dart implementation in `app/lib/domain/predict/` is the *port*. Python emits a JSON file of input/output pairs; both test suites assert against it. If they diverge, CI fails. This is what makes "I trained it in Python but it runs in Dart" safe instead of a source of silent numerical drift.

### 3.2 Python version: **3.11**

| Reason | Detail |
| --- | --- |
| Widest scientific-stack support | PyTorch, ExecuTorch, JAX, NumPyro, and ArviZ all publish 3.11 wheels; 3.13 and 3.14 support lags by months on at least one of them **[VERIFY at setup time]** |
| Your system Python is 3.14.3 | Verified on this machine. Too new for the PyTorch/ExecuTorch/JAX path; do **not** use it for this project. `uv` will install and pin 3.11 alongside it without touching the system install |
| Free-threading noise | 3.13+ free-threaded builds interact badly with some native extensions; 3.11 avoids the question entirely |

Runner-up: **Python 3.12**. Rejected because ExecuTorch has the narrowest supported Python range in this stack and has historically trailed by a minor version, and the only thing 3.12 buys here is marginally faster startup. Revisit if 3.11 hits end-of-life security support before the project ends. **[VERIFY the PyTorch and ExecuTorch support matrices at setup time.]**

#### MediaPipe and TensorFlow: both excluded

- **MediaPipe: not applicable.** MediaPipe Tasks solves vision/audio/text perception. This project has no camera, microphone, or text input. Adding it would add tens of megabytes to the APK for nothing. Explicitly rejected, recorded as a non-decision so it does not get reconsidered.
- **TensorFlow: removed entirely.** It appears in neither runtime and in no dependency group. The stack is PyTorch end to end, per [ADR-0006](DECISIONS.md#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely). This also removes `tf-keras`, the `.tflite` artifact format, `tflite_flutter`, and the LiteRT runtime.

#### PyTorch and ExecuTorch version constraints

These are now the binding constraints, and they apply **only to the optional Tier B path**. The MVP ships no ML runtime at all.

| Constraint | Detail |
| --- | --- |
| ExecuTorch has the narrowest support window | Pin `executorch` and `torch` as a **matched pair**. Each ExecuTorch release targets a specific `torch` version, and mismatching them produces export failures with unhelpful error messages. **[VERIFY the exact pairing for the release you install]** |
| `torch.export()` is the entry point | Export goes `nn.Module` to `torch.export()` to an ATen graph to a `.pte`. Ops outside Core ATen need a custom kernel or a model rewrite. Keep the Tier B head in boring ops (linear, layernorm, gelu) and this never bites you |
| **On-device training is experimental** | `TrainingModule` and the `SGD` optimizer exist on Android and were migrated from Java to Kotlin, with end-to-end Android training tests added. They remain explicitly experimental. Treat every training API detail as **[VERIFY]** when you reach M5 |
| Dart cannot reach the training API | `executorch_flutter` (v0.7.2, MIT, verified publisher, actively released) is **inference-only**: no `TrainingModule`, no optimizer, no fine-tuning. On-device training is reachable only from Kotlin, so a platform channel is **required, not a fallback**. See 3.5 |
| PyTorch has native Windows CUDA | Unlike TensorFlow and JAX. Tier B training experiments run on the RTX 4070 directly on Windows, with no WSL2 involved. See 3.8 |
| `executorch_flutter` forces a Flutter floor | It requires **Flutter 3.38+** (first version with native assets hooks). This sets the minimum for the `.fvmrc` pin if you ever adopt it for inference |

### 3.3 Environment manager: **uv**

Chosen because it resolves and locks in seconds, installs and pins the Python interpreter itself (so 3.11 is guaranteed regardless of the 3.14 on PATH), produces a cross-platform `uv.lock`, and needs no shell activation ritual. `uv 0.11.2` is already installed on this machine.

Runner-up: **conda / mamba**. Rejected because its only real advantage here is shipping CUDA libraries, and the modern `jax[cuda12]` and `torch` wheels bundle their own CUDA. Conda's slower solves and environment.yml drift are not worth it. Keep conda in mind only if you later need a non-Python native dependency that has no wheel.

#### Exact setup commands

Windows (PowerShell), the primary path for authoring code, running tests, and exporting ExecuTorch models. PyTorch CUDA works natively here, so this covers everything except JAX GPU:

```bash
uv python install 3.11
```

```bash
cd research; uv sync --extra edge --group dev
```

```bash
uv run python -c "import numpy, scipy, numpyro; print(numpy.__version__, scipy.__version__, numpyro.__version__)"
```

WSL2 (Ubuntu), the GPU path used for hyperprior fitting and large backtest sweeps:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```bash
cd research && uv sync --extra gpu --group dev
```

```bash
uv run python -c "import jax; print(jax.devices())"
```

Day-to-day:

```bash
uv run pytest -q
```

```bash
uv run cyclecore backtest --config configs/backtest.yaml
```

```bash
uv add --group dev some-package
```

### 3.4 Python dependencies

> **All pins below are starting points and are marked [VERIFY] as a block.** Resolve them once with `uv lock` and commit `uv.lock`; the lockfile, not this table, is the source of truth thereafter.

#### Core (`[project.dependencies]`)

| Package | Pin | Why |
| --- | --- | --- |
| `numpy` | `==2.2.6` | Array backbone for the filter reference implementation |
| `scipy` | `==1.14.1` | `scipy.stats` for Student-t, and `scipy.optimize` for the per-user hyperparameter grid refit |
| `pandas` | `==2.2.3` | Cycle tables, rolling-origin splits, and CSV/Parquet ingest of public datasets |
| `pyarrow` | `==18.1.0` | Parquet IO for interim datasets; far faster and type-safe versus CSV |
| `pydantic` | `==2.10.4` | Runtime-validated schemas for cycle records and for the exported `priors.json` |
| `pydantic-settings` | `==2.7.0` | Typed config from YAML plus env vars, replacing hardcoded constants |
| `typer` | `==0.15.1` | The `cyclecore` CLI (`fit-priors`, `backtest`, `export-golden`) with zero boilerplate |
| `structlog` | `==24.4.0` | Structured JSON logs so every run is machine-parseable and greppable |
| `numpyro` | `==0.16.1` | NUTS/SVI for fitting the population hyperpriors; far better ergonomics than raw Stan and it runs on GPU |
| `jax` | `==0.4.38` | NumPyro's backend. CPU wheel on Windows, `jax[cuda12]` in WSL2 |
| `arviz` | `==0.20.0` | Posterior diagnostics: r-hat, ESS, posterior predictive checks. Non-negotiable if you are doing Bayesian work |
| `mlflow` | `==2.19.0` | Experiment tracking, fully local (`file:./mlruns`), no account, no telemetry |
| `matplotlib` | `==3.10.0` | Calibration plots, reliability diagrams, backtest figures |

#### Dev (`[dependency-groups] dev`)

| Package | Pin | Why |
| --- | --- | --- |
| `ruff` | `==0.8.6` | Lint plus format in one fast binary; replaces black, isort, flake8, pydocstyle, pyupgrade |
| `mypy` | `==1.14.1` | Static types. Strict on `src/cyclecore`, lenient on `notebooks/` |
| `pytest` | `==8.3.4` | Test runner |
| `pytest-cov` | `==6.0.0` | Coverage gate in CI |
| `pytest-xdist` | `==3.6.1` | `-n auto` for the backtest test suite, which is embarrassingly parallel |
| `hypothesis` | `==6.123.2` | Property-based tests. Critical for date math: DST, leap years, month boundaries, out-of-order logs |
| `pre-commit` | `==4.0.1` | Runs ruff/mypy/nbstripout before every commit |
| `nbstripout` | `==0.8.1` | Strips notebook outputs so notebooks stop polluting diffs and cannot leak sample data |
| `pandas-stubs` | `==2.2.3.*` | Types for pandas so mypy is useful rather than noisy |

#### Optional extras

| Extra | Packages | Why |
| --- | --- | --- |
| `edge` | `executorch==1.3.*` plus the `torch` version it pins **[VERIFY the matched pair]** | Tier B only: author the residual head, run `torch.export()`, emit a `.pte`. CUDA works natively on Windows |
| `gpu` | `jax[cuda12]==0.4.38` | WSL2 or Linux only. GPU NUTS for the hyperprior fit and parallel backtest sweeps. **Optional**: the same artifacts are reproducible on CPU |
| `dash` | `streamlit==1.41.1`, `seaborn==0.13.2` | Internal backtest explorer, never shipped |
| `nb` | `jupyterlab==4.3.4`, `ipywidgets` | Exploration |

#### `research/pyproject.toml`

```toml
[project]
name = "cyclecore"
version = "0.1.0"
description = "Reference implementation, priors, and backtests for the Period-Tracker on-device model"
requires-python = "==3.11.*"
license = { text = "MIT" }
dependencies = [
  "numpy==2.2.6",
  "scipy==1.14.1",
  "pandas==2.2.3",
  "pyarrow==18.1.0",
  "pydantic==2.10.4",
  "pydantic-settings==2.7.0",
  "typer==0.15.1",
  "structlog==24.4.0",
  "numpyro==0.16.1",
  "jax==0.4.38",
  "arviz==0.20.0",
  "mlflow==2.19.0",
  "matplotlib==3.10.0",
]

[project.optional-dependencies]
# Tier B only. The `torch` pin is DICTATED by the executorch release; do not
# bump one without the other. [VERIFY the matched pair before locking.]
edge = ["torch==2.9.0", "executorch==1.3.0"]
# JAX GPU for the hyperprior NUTS fit. WSL2 or Linux only, and optional:
# every artifact the app consumes is reproducible on CPU from the same seed.
gpu  = ["jax[cuda12]==0.4.38"]
dash = ["streamlit==1.41.1", "seaborn==0.13.2"]
nb   = ["jupyterlab==4.3.4", "ipywidgets==8.1.5"]

# PyTorch CUDA wheels live on a separate index. This is what makes the RTX 4070
# usable from native Windows, which TensorFlow and JAX cannot do.
# [VERIFY the CUDA tag against your driver at https://pytorch.org/get-started/locally/]
[[tool.uv.index]]
name = "pytorch-cu126"
url = "https://download.pytorch.org/whl/cu126"
explicit = true

[tool.uv.sources]
torch = [{ index = "pytorch-cu126" }]

[project.scripts]
cyclecore = "cyclecore.cli:app"

[dependency-groups]
dev = [
  "ruff==0.8.6",
  "mypy==1.14.1",
  "pytest==8.3.4",
  "pytest-cov==6.0.0",
  "pytest-xdist==3.6.1",
  "hypothesis==6.123.2",
  "pre-commit==4.0.1",
  "nbstripout==0.8.1",
  "pandas-stubs==2.2.3.241126",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/cyclecore"]

[tool.ruff]
line-length = 100
target-version = "py311"
src = ["src", "tests"]

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "D", "UP", "B", "A", "C4", "SIM", "ARG", "PTH", "NPY", "PD", "RUF"]
ignore = ["D203", "D213"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["D", "ARG"]
"notebooks/*" = ["D", "E402"]

[tool.mypy]
python_version = "3.11"
files = ["src/cyclecore"]
strict = true
warn_unreachable = true
plugins = ["pydantic.mypy"]

[[tool.mypy.overrides]]
module = ["numpyro.*", "arviz.*", "mlflow.*", "executorch.*", "streamlit.*"]
ignore_missing_imports = true

[tool.pytest.ini_options]
minversion = "8.0"
addopts = "-ra --strict-markers --cov=cyclecore --cov-report=term-missing --cov-fail-under=85"
testpaths = ["tests"]
markers = [
  "slow: takes more than 5 seconds",
  "gpu: requires a CUDA device",
  "golden: regenerates or checks cross-runtime golden vectors",
]
filterwarnings = ["error::DeprecationWarning"]

[tool.coverage.run]
branch = true
omit = ["src/cyclecore/cli.py", "src/cyclecore/**/plots.py"]
```

#### `research/requirements.txt`

Provided for environments without `uv`. Generate it, do not hand-maintain it:

```bash
uv export --no-hashes --format requirements-txt --extra edge --output-file requirements.txt
```

Resulting shape (abridged; the real file is fully pinned and transitive):

```
# Generated by `uv export`. DO NOT EDIT BY HAND.
# Regenerate with: uv export --no-hashes --format requirements-txt --extra edge -o requirements.txt
-e .
arviz==0.20.0
executorch==1.3.0
jax==0.4.38
jaxlib==0.4.38
matplotlib==3.10.0
mlflow==2.19.0
numpy==2.2.6
numpyro==0.16.1
pandas==2.2.3
pyarrow==18.1.0
pydantic==2.10.4
pydantic-settings==2.7.0
scipy==1.14.1
structlog==24.4.0
torch==2.9.0
typer==0.15.1
```

### 3.5 Non-Python components

#### Flutter / Dart (the shipped app)

Pin the SDK with **FVM** so the Flutter version is as reproducible as `uv.lock`. **As built: Flutter 3.47.0 with Dart 3.13.0**, pinned in `app/.fvmrc` (committed).

Note the location: `.fvmrc` lives in `app/`, next to `pubspec.yaml`, not at the repo root. That is where FVM resolves it from, and it matches the `cd app && fvm flutter ...` form the justfile uses.

| Package | Pin | Why | Runner-up rejected |
| --- | --- | --- | --- |
| `drift` + `drift_flutter` + `sqlite3_flutter_libs` | `^2.22.0` | Type-safe SQLite with compile-checked queries, real migration support, and it runs on desktop so unit tests do not need an emulator | `sqflite`: stringly-typed SQL, no migration tooling, no desktop test story |
| `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` | `^2.6.1` | Compile-safe DI, trivial to override providers in tests, no BuildContext coupling | `bloc`: more ceremony per feature for a single-user app of this size |
| `go_router` | `^14.6.0` | Declarative routing, deep-link ready, testable | Imperative `Navigator`: fine but harder to test route guards (app lock later) |
| `flutter_local_notifications` | `^18.0.1` | Fully local scheduled reminders, no FCM, no network | `awesome_notifications`: heavier, more permissions surface |
| `fl_chart` | `^0.69.2` | Cycle-length trend and variability charts, pure Dart | `syncfusion_flutter_charts`: licensing friction |
| `freezed` + `freezed_annotation` + `json_serializable` | **`^4.0.0-dev.3`** / `^3.1.0` / `^6.14.1` | Immutable domain models, native Dart 3 exhaustive pattern matching (freezed 3 removed `when`/`map`), and free export/import serialization | Hand-written models: more boilerplate, though see the pre-release caveat below |
| `path_provider` | `^2.1.5` | Locate the app-private DB directory |
| `share_plus` / `file_picker` | `^10.1.2` / `^8.1.6` | User-initiated export and import |
| `package_info_plus` | `^8.1.2` | Stamp the app version into every export file |
| `intl` + `flutter_localizations` | sdk-pinned | Date formatting and l10n readiness from day one |
| ExecuTorch via Kotlin channel | `org.pytorch:executorch-android` **[VERIFY coordinate and version]** | Tier B only. Deliberately **not** a pub package, because on-device training is unreachable from Dart | `executorch_flutter ^0.7.2` is inference-only and cannot serve Tier B |

Dev, as built: **`very_good_analysis ^10.3.0`** (adopted; `flutter_lints` was removed rather than kept alongside it), **`build_runner ^2.16.0`**, plus `mocktail ^1.0.4`, `drift_dev` and `integration_test` (sdk) when the data layer and widget tests land.

Also a direct dependency: **`meta ^1.19.0`**, for `@immutable` on the hand-written value types in `lib/core/`. It cannot come from `package:flutter/foundation.dart` because `core/` and `domain/` must not import Flutter (ADR-0002).

> **Pre-release caveat.** `freezed` is pinned to `4.0.0-dev.3` because the current stable, 3.2.5, emits invalid Dart against the Dart 3.13 SDK: it writes `final` onto a named parameter for any collection-typed field, which the front end rejects. Root cause is ecosystem lag, since Dart 3.13 shipped days before this was built and freezed 3.2.5 still resolves `analyzer` 10.2.0. Tracked in the deferred-decision log in [DECISIONS.md](DECISIONS.md#backlog-of-deferred-decisions); move to 4.0.0 stable when it ships.

#### Tier B integration: one Kotlin platform channel, not two runtimes

ExecuTorch's `TrainingModule` and `SGD` are exposed only in Kotlin, so Dart cannot reach them. That leaves two possible shapes:

| Shape | Verdict |
| --- | --- |
| `executorch_flutter` for inference **plus** a Kotlin channel for training | **Rejected.** Two independent linkages of the ExecuTorch runtime in one APK, two version pins that can skew apart, and two error surfaces to debug |
| **One Kotlin platform channel exposing both inference and training** | **Adopted.** A single `org.pytorch:executorch-android` AAR, one version, one error surface. Roughly 150 lines of Kotlin |

The channel exposes exactly four methods: `load(assetPath)`, `infer(features)`, `trainStep(batch)`, and `saveCheckpoint(path)`. Everything above that line is Dart. If Tier B is ever dropped, deleting the channel plus `lib/ml/` removes the ExecuTorch dependency completely and the APK returns to carrying zero ML runtime.

`executorch_flutter` stays on the shortlist for exactly one scenario: Tier B degrading to inference-only, with a head trained offline and shipped fixed. That is not the plan of record.

#### Android build layer

| Item | Value | Reason |
| --- | --- | --- |
| JDK | **21**, the Android Studio JBR (`flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"`) | The binding constraint was never "use 17", it was **"do not use the system JDK 25"**, which AGP does not support. This machine already had JBR 21.0.8, which AGP 9.x fully supports, so it was used instead of installing a second JDK: zero download, and CLI builds match IDE builds. Verified by a successful release build, with `flutter doctor -v` reporting the JBR path. CI uses 21 too, for parity |
| `minSdk` | 26 (Android 8.0) | Native `java.time`, modern notification channels, and still very high device coverage. Lower only if you have a specific old device |
| `compileSdk` / `targetSdk` | **36** (resolved from `flutter.compileSdkVersion`) | Required for Play; also gates notification permission behavior |
| Core library desugaring | enabled | `flutter_local_notifications` requires it |
| Permissions | `POST_NOTIFICATIONS` only | And an explicit **removal** of INTERNET, ACCESS_NETWORK_STATE and ACCESS_WIFI_STATE (see below) |
| Gradle toolchain, as scaffolded | **AGP 9.1.0**, **Gradle 9.3.1**, **Kotlin 2.4.0**, Java 17 bytecode target | Resolved by `flutter create` on Flutter 3.47.0, not chosen by hand. Recorded because these were `[VERIFY]` placeholders in the original draft |
| Desugaring library | `com.android.tools:desugar_jdk_libs:2.1.5` | Needed once `isCoreLibraryDesugaringEnabled` is on |

The manifest must actively strip INTERNET, because Flutter's debug manifest injects it for hot reload and it is easy to let it leak into a merged release manifest:

```xml
<manifest xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.INTERNET" tools:node="remove" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <application android:allowBackup="false" ... />
</manifest>
```

Then assert it in CI (see `tools/scripts/assert_no_network.sh` in the tree). `allowBackup="false"` matters: with it left on, Android's auto-backup can copy the database to Google's servers, which would silently break the offline guarantee.

#### Task runner: `justfile`

Chosen over `make` because GNU Make on Windows is a nuisance and `just` handles PowerShell and bash cleanly.

```just
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

py-setup:      cd research && uv sync --extra edge --group dev
py-test:       cd research && uv run pytest -q
py-lint:       cd research && uv run ruff check . && uv run ruff format --check . && uv run mypy
priors:        cd research && uv run cyclecore fit-priors --config configs/priors.yaml
golden:        cd research && uv run cyclecore export-golden --out ../artifacts/golden/predictor_cases_v1.json
backtest:      cd research && uv run cyclecore backtest --config configs/backtest.yaml
dash:          cd research && uv run streamlit run dashboards/backtest_app.py

app-get:       cd app && fvm flutter pub get
app-gen:       cd app && fvm dart run build_runner build --delete-conflicting-outputs
app-test:      cd app && fvm flutter test --coverage
# `dart format .` is NOT safe here: it walks build/ and crashes on a Gradle
# desugar intermediate with a very long path. Always scope it.
app-lint:      cd app && fvm dart format --output=none --set-exit-if-changed lib test && fvm flutter analyze
app-apk:       cd app && fvm flutter build apk --release
verify-apk:    bash tools/scripts/assert_no_network.sh app/build/app/outputs/flutter-apk/app-release.apk

ci: py-lint py-test app-lint app-test
all: priors golden py-test app-test app-apk verify-apk
```

#### Shell scripts (`tools/scripts/`)

- `assert_no_network.sh`: runs `aapt2 dump permissions` on the release APK and exits non-zero if INTERNET, ACCESS_NETWORK_STATE, or any location permission appears. This is the automated proof of the core privacy claim.
- `sync_priors.sh`: copies `artifacts/priors/priors_v1.json` into `app/assets/priors/` and fails if the checksum in `app/lib/domain/predict/priors_checksum.dart` is stale.
- `new_migration.sh`: bumps the Drift schema version and dumps the schema snapshot used by migration tests.

#### Dockerfile

**Optional and low priority.** A CPU-only `Dockerfile` for `research/` is worth having purely so CI and your machine cannot diverge, but it is not on the MVP path since `uv.lock` already gives you reproducibility. If you add it: `python:3.11-slim`, `COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv`, `uv sync --frozen`. Do **not** dockerize the Flutter build; the Android SDK in Docker on Windows is more pain than it is worth.

#### JavaScript / TypeScript

**None.** There is no web demo. The internal research dashboard is Streamlit, which is Python. Adding a JS toolchain would be a third ecosystem for zero user-facing benefit.

### 3.6 Deployment options compared

The target is an `.apk`, so most of these are evaluated as "does this belong anywhere in this project" rather than "is this the delivery mechanism".

| Option | Verdict | Reason |
| --- | --- | --- |
| **ExecuTorch on-device** | **Primary, for Tier B only** | PyTorch's own edge runtime, reached through a Kotlin platform channel. Keeps one framework end to end: `nn.Module` to `torch.export()` to `.pte` to device, with no cross-framework conversion hop to debug. Small runtime, no server |
| **Pure Dart model (no ML runtime)** | **Primary, for Tier A / MVP** | The Bayesian filter is roughly 200 lines of arithmetic. Shipping a 2 MB inference runtime to do that would be absurd. Zero dependencies, zero conversion risk, fully debuggable, instantly testable |
| **LiteRT (formerly TFLite)** | **Runner-up, rejected** | Its on-device training via SavedModel signatures is more established than ExecuTorch's, and `litert-torch` (the renamed `ai-edge-torch`) would let a PyTorch model feed it. Rejected to keep one framework end to end: the conversion hop is a second place for the model to break, and TensorFlow lineage is out per ADR-0006 |
| **ONNX Runtime Mobile** | Rejected | Solid inference story with working Flutter bindings, but its on-device training API is a separate artifact-generation flow with no Flutter binding at all. That is ExecuTorch's drawback plus a framework hop |
| **MediaPipe Tasks** | Rejected | Perception toolkit. No camera, mic, or text task in this project |
| **Streamlit** | **Adopted, internal only** | The backtest explorer: pick a synthetic or held-out user, scrub through cycles, watch the predictive interval update. Fastest possible path to that tool. Never shipped, never networked beyond localhost |
| **Gradio** | Rejected | Same niche as Streamlit but weaker for multi-panel dashboards; Streamlit's `st.session_state` fits the scrubbing UI better |
| **FastAPI + frontend** | Rejected | A server is the exact thing this project is defined to not have. Any server-based prediction would break the offline requirement and create a data-exfiltration path |

### 3.7 Deployment of the APK itself

```bash
cd app && fvm flutter build apk --release --split-per-abi
```

Sign with a keystore stored outside the repo, referenced from `android/key.properties` (gitignored). Back the keystore up somewhere you will not lose it; losing it means you can never upgrade an installed app in place. For a personal project, `--split-per-abi` plus sideloading the `arm64-v8a` APK is the whole distribution story. An App Bundle (`.aab`) is only needed for Play.

### 3.8 GPU / CUDA notes and the CPU-only fallback

**Honest framing: the GPU is a convenience here, not a requirement.** The shipped model is a low-dimensional state-space model fitted per user on fewer than 100 observations. Nothing in the production path needs CUDA. The RTX 4070 earns its keep on three things:

1. **NUTS sampling of the population hyperprior model** across thousands of synthetic or public-dataset users. Minutes on GPU, tens of minutes on CPU.
2. **Backtest sweeps.** Rolling-origin evaluation across a grid of model variants and thousands of simulated users is embarrassingly parallel; `jax.vmap` over users on GPU is a large win.
3. **Tier B training experiments**, if you go there.

| Constraint | Detail |
| --- | --- |
| JAX CUDA on Windows | Not supported natively. `jax[cuda12]` is Linux-only; use **WSL2 + Ubuntu** **[VERIFY current status]**. Since TensorFlow left the project, this is the *only* remaining reason to run WSL2 at all |
| PyTorch CUDA on Windows | **Supported natively.** Tier B training experiments run on the RTX 4070 straight from Windows. Wheels come from the `pytorch-cu126` index configured in `pyproject.toml`, not from PyPI |
| Driver | Keep the Windows NVIDIA driver current; WSL2 uses the Windows driver, do **not** install a Linux NVIDIA driver inside WSL2 |
| VRAM | 12 GB is far more than this workload needs. Set `XLA_PYTHON_CLIENT_PREALLOCATE=false` so JAX does not grab the whole card |

**CPU-only fallback path (fully supported, must stay green):**

- Every test, the golden-vector export, the priors export, and the ExecuTorch `.pte` export run on CPU. CI runs CPU-only.
- The GPU is selected by config, never hardcoded: `compute.device: auto|cpu|gpu` in `configs/`, resolved by `cyclecore.config`.
- Tests that need a GPU are marked `@pytest.mark.gpu` and skipped by default.
- `uv sync` without `--extra gpu` installs CPU JAX. That is the default on Windows.
- Document in the README that a full `just priors && just backtest` on CPU takes longer but produces identical artifacts (seeded, deterministic).

---

## 4. Repository structure

```
Period-Tracker/
├─ .github/
│  └─ workflows/
│     ├─ python.yml               # ruff, mypy, pytest+coverage on ubuntu-latest
│     ├─ flutter.yml              # format, analyze, test+coverage, build apk (debug)
│     ├─ golden.yml               # regenerates golden vectors and fails if they drift
│     └─ release.yml              # tag-triggered signed release APK
├─ .pre-commit-config.yaml
├─ justfile
├─ README.md
├─ docs/
│  ├─ PLAN.md                     # this file
│  ├─ DECISIONS.md                # ADR log
│  ├─ MODEL.md                    # the math, written once, referenced by both runtimes
│  ├─ PRIVACY.md                  # user-facing privacy statement, shipped in-app verbatim
│  └─ THREAT_MODEL.md
│
├─ app/                           # ===== Flutter app: everything that ships =====
│  ├─ .fvmrc                       # pinned Flutter SDK version (3.47.0)
│  ├─ .fvm/                        # resolved SDK symlink, gitignored
│  ├─ pubspec.yaml
│  ├─ analysis_options.yaml        # very_good_analysis + extra rules for lib/domain
│  ├─ android/
│  │  ├─ app/build.gradle.kts      # minSdk 26, desugaring, signing config, JDK 21 toolchain
│  │  ├─ app/src/main/AndroidManifest.xml   # INTERNET removed, allowBackup=false
│  │  └─ app/src/main/kotlin/.../ExecuTorchChannel.kt
│  │                                # Tier B ONLY. load/infer/trainStep/saveCheckpoint
│  │                                # over org.pytorch:executorch-android. Delete this
│  │                                # file and lib/ml/ to drop ExecuTorch entirely
│  ├─ assets/
│  │  ├─ priors/priors_v1.json     # copied from artifacts/, checksum-verified
│  │  └─ model/cycle_head_v1.pte   # Tier B only
│  ├─ lib/
│  │  ├─ main.dart                 # bootstrap: DB open, migrations, ProviderScope, runApp
│  │  ├─ app.dart                  # MaterialApp.router, theme, l10n wiring
│  │  ├─ core/                     # cross-cutting, no feature knowledge
│  │  │  ├─ logging.dart           # structured local logger, ring buffer + optional file sink
│  │  │  ├─ result.dart            # Result<T,E> so failures are values, not exceptions
│  │  │  ├─ clock.dart             # injectable Clock; NOTHING calls DateTime.now() directly
│  │  │  ├─ date_utils.dart        # civil-date arithmetic, DST-safe, timezone-pinned
│  │  │  └─ settings.dart          # typed app settings
│  │  ├─ data/                     # persistence only, knows nothing about prediction
│  │  │  ├─ db/
│  │  │  │  ├─ database.dart       # Drift database, schemaVersion, migration steps
│  │  │  │  ├─ tables.dart         # PeriodDays, CycleEvents, Symptoms, ModelState, Settings
│  │  │  │  └─ daos/
│  │  │  ├─ repositories/
│  │  │  │  ├─ cycle_repository.dart
│  │  │  │  └─ prediction_repository.dart   # caches posterior state, invalidates on edit
│  │  │  └─ transfer/
│  │  │     ├─ export_v1.dart      # versioned JSON envelope + schema hash
│  │  │     └─ import_v1.dart      # validating importer, refuses unknown versions
│  │  ├─ domain/                   # PURE DART. No flutter imports. 90% coverage target
│  │  │  ├─ models/                # freezed: CycleRecord, DayLog, Prediction, Confidence
│  │  │  ├─ cycles/
│  │  │  │  ├─ segmentation.dart   # day logs -> discrete cycles; handles gaps and edits
│  │  │  │  ├─ validation.dart     # implausible cycle detection (<15d, >90d, overlaps)
│  │  │  │  └─ features.dart       # derived stats: median, MAD, trend, regularity class
│  │  │  └─ predict/
│  │  │     ├─ priors.dart         # generated from priors_v1.json, checksum-guarded
│  │  │     ├─ bayes_filter.dart   # THE MODEL. Port of the Python reference
│  │  │     ├─ personalize.dart    # on-device refit of per-user sigma and drift
│  │  │     ├─ intervals.dart      # predictive quantiles -> UI-facing window
│  │  │     └─ explain.dart        # plain-language rationale for every prediction
│  │  ├─ ml/                       # Tier B ONLY, behind a feature flag
│  │  │  ├─ executorch_channel.dart # Dart side of the Kotlin platform channel
│  │  │  ├─ ondevice_trainer.dart  # drives trainStep, persists the checkpoint
│  │  │  └─ gate.dart              # per-user rolling backtest; ML head must beat Tier A
│  │  ├─ features/                 # one folder per screen: widgets + riverpod controllers
│  │  │  ├─ onboarding/            # disclaimer, first cycle entry, notification opt-in
│  │  │  ├─ log/
│  │  │  ├─ calendar/
│  │  │  ├─ insights/
│  │  │  └─ settings/              # export, import, delete-all, about, privacy text
│  │  ├─ notifications/
│  │  │  └─ scheduler.dart         # reschedules on every prediction change and on boot
│  │  └─ l10n/
│  ├─ test/
│  │  ├─ domain/                   # the bulk of the suite; fast, no Flutter binding
│  │  ├─ golden_vectors_test.dart  # reads artifacts/golden/*.json, asserts parity
│  │  ├─ data/                     # in-memory Drift, migration tests
│  │  └─ features/                 # widget tests + screenshot goldens
│  └─ integration_test/
│     └─ e2e_smoke_test.dart       # onboard -> log 3 cycles -> see prediction -> export
│
├─ research/                      # ===== Python: nothing here ships =====
│  ├─ pyproject.toml
│  ├─ requirements.txt            # generated by `uv export`
│  ├─ uv.lock                     # committed
│  ├─ configs/
│  │  ├─ priors.yaml
│  │  ├─ backtest.yaml
│  │  └─ tierb.yaml
│  ├─ src/cyclecore/
│  │  ├─ config.py                # pydantic-settings; every constant lives here
│  │  ├─ seeds.py                 # one seed_everything() used by every entrypoint
│  │  ├─ data/
│  │  │  ├─ schema.py             # pydantic models shared by loaders
│  │  │  ├─ public_loader.py      # public dataset ingest + normalization
│  │  │  ├─ synthetic.py          # generative simulator (THE dataset de-risk)
│  │  │  └─ splits.py             # rolling-origin, per-user, leakage-proof
│  │  ├─ features/build.py
│  │  ├─ models/
│  │  │  ├─ bayes_filter.py       # REFERENCE IMPLEMENTATION. The port target
│  │  │  ├─ hyperpriors.py        # NumPyro model + NUTS fit -> population priors
│  │  │  ├─ baselines.py          # last-cycle, mean-of-N, median-of-N. Must be beaten
│  │  │  └─ tierb/                # nn.Module head, torch.export(), .pte emission
│  │  ├─ eval/
│  │  │  ├─ metrics.py            # MAE, CRPS, interval coverage, PIT
│  │  │  ├─ backtest.py           # rolling-origin driver, MLflow-logged
│  │  │  └─ plots.py              # reliability diagram, coverage-vs-history-length
│  │  ├─ export/
│  │  │  ├─ priors_json.py        # -> artifacts/priors/priors_v1.json
│  │  │  ├─ golden_vectors.py     # -> artifacts/golden/predictor_cases_v1.json
│  │  │  └─ executorch_export.py  # -> artifacts/models/cycle_head_v1.pte
│  │  └─ cli.py                   # typer app: fit-priors, backtest, export-golden, sim
│  ├─ tests/
│  │  ├─ test_date_math.py        # hypothesis-driven
│  │  ├─ test_segmentation.py
│  │  ├─ test_contracts.py        # shape + dtype + range contracts
│  │  ├─ test_overfit_one_user.py # the "overfit one batch" analogue
│  │  ├─ test_calibration.py      # coverage of nominal intervals on simulated data
│  │  ├─ test_golden_roundtrip.py
│  │  └─ test_e2e_smoke.py
│  ├─ notebooks/                  # exploration only, outputs stripped, never imported
│  └─ dashboards/backtest_app.py  # Streamlit
│
├─ artifacts/                     # ===== the Python -> Dart contract. COMMITTED =====
│  ├─ priors/priors_v1.json
│  ├─ golden/predictor_cases_v1.json
│  └─ models/cycle_head_v1.pte
│
├─ data/                          # GITIGNORED, never committed
│  ├─ raw/                        # downloaded public datasets, untouched
│  ├─ interim/                    # normalized parquet
│  ├─ processed/                  # model-ready
│  └─ DATASETS.md                 # provenance, license, download URL, checksum (COMMITTED)
│
└─ tools/scripts/
   ├─ assert_no_network.sh
   ├─ check_no_datetime_now.sh    # forbids DateTime.now() outside core/clock.dart
   ├─ sync_priors.sh
   └─ new_migration.sh
```

### 4.1 Data flow

**Production flow (on device, per prediction):**

```
User taps "period started"
  -> features/log writes a DayLog row via CycleRepository (Drift/SQLite, app-private)
  -> domain/cycles/segmentation.dart rebuilds the ordered list of CycleRecords
  -> domain/cycles/validation.dart flags implausible cycles and marks them low-weight
  -> domain/predict/bayes_filter.dart runs the forward filter over log-cycle-lengths,
     starting from priors.dart (population) and folding in every observed cycle
  -> domain/predict/personalize.dart periodically refits per-user (sigma, drift) by
     maximizing the filter's one-step-ahead predictive likelihood over a small grid
  -> domain/predict/intervals.dart converts the predictive distribution into
     {median date, 50% window, 80% window, confidence class}
  -> PredictionRepository caches the posterior + prediction, keyed by a hash of the
     input cycle list, so edits invalidate correctly
  -> features/calendar + features/insights render the WINDOW (never a bare date)
  -> notifications/scheduler reschedules the local reminder
```

**Research flow (offline, produces committed artifacts):**

```
Public dataset (data/raw)  ─┐
                            ├─> data/public_loader.py -> normalized parquet (data/interim)
Synthetic simulator ────────┘
        |
        v
 models/hyperpriors.py  (NumPyro NUTS, GPU in WSL2)
        |
        +--> export/priors_json.py ------> artifacts/priors/priors_v1.json --> app/assets
        |
        v
 eval/backtest.py (rolling-origin, per user)
        |
        +--> MLflow run: params, MAE, CRPS, 50/80/95% coverage, reliability plot
        |
        v
 export/golden_vectors.py -----> artifacts/golden/predictor_cases_v1.json
        |                                        |
        +--> pytest asserts Python == golden     +--> flutter test asserts Dart == golden
```

The one rule that keeps this clean: **`app/lib/domain/` may not import Flutter, and `research/` may not import anything about the app.** The only thing crossing the boundary is JSON in `artifacts/`.

---

## 5. Programming guidelines

### 5.1 Style and tooling

**Python**

| Concern | Choice | Notes |
| --- | --- | --- |
| Lint + format | `ruff check` + `ruff format` | One tool, one config, no black/isort/flake8 stack. Line length 100 |
| Type hints | Required on every public function | `from __future__ import annotations` not needed on 3.11 for most cases |
| Type checking | `mypy --strict` on `src/cyclecore` | Third-party stubs waived via targeted `overrides`, never a blanket `ignore_errors` |
| Docstrings | **Google style**, enforced by ruff `D` rules with `convention = "google"` | Chosen over NumPy style because it is more compact and reads better in IDE hovers. Required on all public functions, classes, and modules; exempt in `tests/` and `notebooks/` |

**Dart**

| Concern | Choice |
| --- | --- |
| Format | `dart format --output=none --set-exit-if-changed lib test` in CI. No debate, no config. **Scoped to `lib test` deliberately**: a bare `dart format .` crashes walking `build/` after an Android build |
| Lint | `very_good_analysis` plus `public_member_api_docs: error` scoped to `lib/domain/` |
| Types | Sound null safety, no `dynamic` outside JSON boundaries, `implicit-casts: false` |
| Docs | `///` doc comments on everything public in `domain/` |

**`.pre-commit-config.yaml`**

```yaml
default_install_hook_types: [pre-commit, commit-msg]
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ["--maxkb=2048"]
      - id: check-merge-conflict
      - id: no-commit-to-branch
        args: ["--branch", "main"]

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.6
    hooks:
      - id: ruff
        args: [--fix]
        files: ^research/
      - id: ruff-format
        files: ^research/

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.14.1
    hooks:
      - id: mypy
        files: ^research/src/
        additional_dependencies: [pydantic==2.10.4, pandas-stubs]

  - repo: https://github.com/kynan/nbstripout
    rev: 0.8.1
    hooks:
      - id: nbstripout

  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.6.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]

  - repo: local
    hooks:
      - id: dart-format
        name: dart format
        entry: bash -c 'cd app && fvm dart format --output=none --set-exit-if-changed lib test'
        language: system
        files: ^app/.*\.dart$
        pass_filenames: false
      - id: flutter-analyze
        name: flutter analyze
        entry: bash -c 'cd app && fvm flutter analyze'
        language: system
        files: ^app/.*\.dart$
        pass_filenames: false
      - id: no-datetime-now
        name: forbid DateTime.now() outside core/clock.dart
        entry: bash tools/scripts/check_no_datetime_now.sh
        language: system
        files: ^app/lib/.*\.dart$
```

That last hook is not paranoia. In a date-driven app, a stray `DateTime.now()` inside domain logic makes tests non-deterministic and makes DST bugs unreproducible. Route every clock read through an injectable `Clock`.

### 5.2 Config management: **pydantic-settings**

One typed settings tree per entrypoint, loaded from YAML in `configs/` with env-var override. Every number that a reviewer might want to change (prior means, grid bounds, backtest horizons, interval levels) lives there, never inline.

```python
class PriorConfig(BaseModel):
    log_mean_center: float = 3.3673   # log(29.0)
    log_mean_sd: float = 0.12
    obs_sd_scale: float = 0.06
    drift_sd_scale: float = 0.02
    student_t_df: float = 4.0

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="CYCLECORE_", yaml_file="configs/priors.yaml")
    seed: int = 20260817
    device: Literal["auto", "cpu", "gpu"] = "auto"
    priors: PriorConfig = PriorConfig()
    mlflow_uri: str = "file:./mlruns"
```

Runner-up: **Hydra**. Genuinely better for large sweeps (`--multirun`, composable config groups) and I would pick it for a lab-scale project. Rejected here because this project has one model family and maybe a dozen config knobs; Hydra's directory-changing behavior and its interaction with pytest cost more than its sweep syntax saves. If backtest sweeps grow past roughly 50 configurations, revisit.

The **Dart side has no config system**. Model constants come from the generated `priors.dart`, and user settings live in the database. Adding a config framework to the app would be pure ceremony.

### 5.3 Reproducibility

| Item | Approach |
| --- | --- |
| Global seeding | `cyclecore.seeds.seed_everything(seed)` sets `random`, `numpy.random.default_rng`, `PYTHONHASHSEED`, and returns a `jax.random.PRNGKey`. Called first in every CLI entrypoint. Never call a global JAX RNG; always thread the key explicitly |
| Determinism flags | JAX: `XLA_FLAGS=--xla_gpu_deterministic_ops=true` for GPU runs **[VERIFY flag name for your JAX version]**. PyTorch: `torch.use_deterministic_algorithms(True)` plus `torch.backends.cudnn.deterministic = True`, and note that the first of those **raises unless** `CUBLAS_WORKSPACE_CONFIG=:4096:8` is set in the environment |
| Dataset versioning | `data/` is gitignored. `data/DATASETS.md` is committed and records, for each dataset: source URL, download date, license, SHA256, row count, and the exact normalization commit. A dataset is "versioned" by that checksum. **DVC is deliberately not used**: one small dataset does not justify it |
| Model/artifact versioning | Artifacts are versioned by filename (`priors_v1.json`) and carry an embedded `{schema_version, git_sha, created_utc, source_dataset_sha256}` header. The app refuses to load a priors file whose `schema_version` it does not know |
| Experiment tracking | **MLflow**, local file store (`file:./mlruns`), `mlruns/` gitignored |
| Notebooks | Outputs stripped on commit. Notebooks may import from `src/` but nothing in `src/` may import from a notebook |

**MLflow chosen over Weights and Biases** for one decisive reason: W&B is cloud-first, and this is a project whose entire premise is that reproductive-health data never leaves the device. Even though research runs use public or synthetic data, keeping a hard "no telemetry, no accounts, no uploads" rule across the whole repo means there is no path by which a stray real-data run gets uploaded. MLflow's local file store gives you runs, params, metrics, and artifacts with zero network. Runner-up W&B has a nicer UI and better sweep tooling; rejected on the privacy-invariant grounds above.

**What to log per run:**

| Category | Fields |
| --- | --- |
| Params | full resolved config (flattened), seed, model variant, prior version, dataset SHA256, git SHA, dirty-worktree flag |
| Metrics | MAE and median AE of predicted start date (days); CRPS; empirical coverage at 50/80/95%; PIT histogram KS statistic; per-history-length breakdown (n=1,2,3,5,10,20+ cycles); per-regularity-class breakdown; fit wall time; on-device-equivalent flop estimate |
| Artifacts | reliability diagram, coverage-vs-history-length plot, per-user error distribution, the exported `priors.json`, ArviZ `InferenceData` summary (r-hat, ESS) |
| Tags | `runtime=cpu|gpu`, `dataset=public|synthetic`, `tier=A|B` |

Anything that cannot be reconstructed from params plus seed plus dataset hash is a reproducibility bug.

### 5.4 Testing

**Coverage targets:** `research/src/cyclecore` **85%** line coverage, enforced by `--cov-fail-under=85`. `app/lib/domain` **90%**, `app/lib` overall **70%**, enforced in `flutter.yml` via `lcov` filtering. Generated files (`*.g.dart`, `*.freezed.dart`) are excluded.

| Test class | Where | What it asserts |
| --- | --- | --- |
| **Unit: preprocessing** | `tests/test_segmentation.py`, `app/test/domain/segmentation_test.dart` | Day logs to cycles: gaps, single-day periods, back-to-back logs, edits that split or merge a cycle, out-of-order insertion, duplicate dates |
| **Unit: date math (hypothesis)** | `tests/test_date_math.py` | Property tests: `daysBetween(a, add(a, n)) == n` for all n and all dates; DST transition days; leap days; month-end arithmetic; timezone change mid-cycle. This is where date bugs actually live |
| **Contract: shape and dtype** | `tests/test_contracts.py` | Feature builder output has exact expected columns, dtypes, no NaN, monotone cycle index, and value ranges. Fails loudly on schema drift rather than producing a silently wrong model |
| **Overfit on one batch (analogue)** | `tests/test_overfit_one_user.py` | Feed a synthetic user with constant 28-day cycles: after 10 cycles the posterior mean must be within 0.05 days of 28 and the 80% interval width must shrink below 2 days. Feed a user with alternating 26/34: the interval must **widen**, not narrow. For Tier B, the literal version: train on 1 batch for 200 steps, assert loss < 1e-3 |
| **Calibration** | `tests/test_calibration.py` | On 2,000 simulated users from the generative model, empirical coverage of the nominal 50/80/95% intervals must land within +/- 3 percentage points. This is the single most important test in the repo |
| **Golden cross-runtime** | `tests/test_golden_roundtrip.py` + `app/test/golden_vectors_test.dart` | Python and Dart produce identical filter output to 1e-9 on every case in `predictor_cases_v1.json`. Cases include cold start, 1 cycle, irregular history, an outlier cycle, a 90-day gap, and edited history |
| **End-to-end smoke (Python)** | `tests/test_e2e_smoke.py` | `synthetic user JSON -> CLI -> prediction JSON` in under 30 seconds, asserting output schema and sane ranges |
| **End-to-end smoke (app)** | `app/integration_test/e2e_smoke_test.dart` | Onboard, log 3 cycles, assert a prediction window renders, export, wipe, import, assert state restored |
| **Migration tests** | `app/test/data/migration_test.dart` | Every Drift schema version upgrades to the current one against a committed schema snapshot. Non-negotiable: a failed migration on a real user's phone is unrecoverable data loss |
| **Widget goldens** | `app/test/features/` | Screenshot goldens for calendar and insights in light and dark, to catch layout regressions |
| **Accessibility guidelines** | `app/test/features/a11y_test.dart` | `meetsGuideline` for contrast, tap-target size, and labelled tap targets on every screen. Fails CI, exactly like the no-network APK check |
| **Text-scale goldens** | `app/test/features/` | Calendar and insights render without overflow at `textScaler` 1.0, 1.5, and 2.0 |
| **Notification scheduling** | `app/test/notifications/` | Correct reschedule on prediction change, on edit, and on boot; the nudge respects its 1-per-7-days cap; lock-screen visibility defaults to secret |

Test speed budget: the full `pytest` suite excluding `-m slow` must run in under 60 seconds; `flutter test` under 90 seconds. If they get slower, the calibration and sweep tests move behind `-m slow` and run in CI only.

### 5.5 Error handling, logging, and edge cases

**Error handling philosophy:** in `domain/`, failures are **values**, not exceptions. `PredictionResult` is a sealed union: `Predicted`, `InsufficientData`, `TooIrregular`, `DataInconsistent`. The UI must handle every variant, and the analyzer enforces exhaustive `switch`. Exceptions are reserved for genuine bugs and for the storage layer.

**Structured logging:** `structlog` in Python emitting JSON lines. In Dart, a small logger writing structured records into an in-memory ring buffer plus an optional rotating local file, never uploaded, viewable and clearable from Settings. **Never log dates, symptom values, or any cycle content.** Log event names, counts, durations, and enum states only. A log line reading `prediction_computed n_cycles=7 confidence=medium ms=3` is useful; one containing the user's period dates is a privacy incident stored on disk.

**Edge cases that must be handled explicitly** (the analogue of "no hand detected / low confidence"):

| Case | Required behavior |
| --- | --- |
| Zero logged cycles | Show the population prior explicitly labelled "based on typical cycles, not yours yet". Never hide the fact that it is not personalized |
| One logged cycle | Predict, but with a wide interval and `confidence: low`. Say "this will get more accurate" |
| Highly irregular history (MAD above threshold) | Return `TooIrregular`. Show a range plus a plain statement that cycles vary too much to predict narrowly. **Do not narrow the interval to look confident** |
| Implausible cycle (under 15 or over 90 days) | Flag it, ask the user to confirm or correct, and down-weight it in the filter until confirmed |
| Long gap (no logs for 60+ days) | Do not silently extrapolate. Show "we lost track", prompt to log, and reset the filter's forecast horizon |
| Overlapping or duplicate entries | Reject at the repository boundary with a specific message, never silently merge |
| Device clock moved backwards, or timezone change | Store all dates as timezone-naive civil dates (a local calendar day is what a user means by "the day my period started"), never as UTC instants. Detect a backwards clock jump and warn rather than corrupting the history |
| Notification permission denied | App works fully; only the reminder is disabled, with a single non-nagging explanation |
| Corrupt or partially written database | Detect on open, back the file up beside itself, and offer import-from-export rather than starting empty and appearing to have deleted the user's data |
| Import file from a newer app version | Refuse with a clear version message. Never partially import |

### 5.6 Git workflow

**Branch naming:** `<type>/<short-kebab-summary>` where type is one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `exp`. Examples: `feat/drift-schema-v1`, `exp/hyperprior-student-t`, `fix/dst-cycle-length-off-by-one`. `exp/` branches are for research spikes and may be deleted unmerged.

**Conventional Commits**, enforced by the `commit-msg` hook. Scopes: `app`, `domain`, `predict`, `data`, `research`, `ci`, `docs`, `deps`.

```
feat(predict): add Student-t observation model to the on-device filter
fix(domain): correct cycle length across a DST boundary
chore(deps): bump drift to 2.22.1
docs(adr): record decision to replace TensorFlow with PyTorch and ExecuTorch
```

Breaking changes to the export format or the DB schema get a `!` and a `BREAKING CHANGE:` footer, because those are the only two things in this project that can destroy user data.

**PR checklist** (`.github/pull_request_template.md`):

- [ ] Tests added or updated; `just ci` passes locally
- [ ] Coverage did not drop below the configured floor
- [ ] If `bayes_filter.py` or `bayes_filter.dart` changed: golden vectors regenerated **and** the other runtime updated in the same PR
- [ ] If a DB table changed: schema version bumped, migration written, migration test added
- [ ] If the export format changed: version bumped, importer handles both versions, round-trip test added
- [ ] No new package permission; `just verify-apk` still passes
- [ ] No new network-capable dependency (checked `pubspec.lock` diff)
- [ ] No user cycle content added to any log line
- [ ] User-facing copy reviewed for medical overclaiming and gendered language
- [ ] ADR added or updated if this changed an architectural decision

**CI steps**

| Workflow | Steps |
| --- | --- |
| `python.yml` | checkout, `astral-sh/setup-uv` with cache, `uv sync --frozen --group dev`, `ruff check`, `ruff format --check`, `mypy`, `pytest -n auto --cov`, upload coverage |
| `flutter.yml` | checkout, **assert the workflow and `app/.fvmrc` agree on the Flutter version**, JDK 21 via `actions/setup-java`, `subosito/flutter-action`, `flutter pub get`, `build_runner build`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --coverage` (will include the accessibility gate and text-scale goldens at AND-18), `check_no_datetime_now.sh`, debug **and** release APK builds, `assert_no_network.sh` on the release APK, then a **negative control** asserting the debug APK *fails* that same check |
| `golden.yml` | regenerate golden vectors from Python and `git diff --exit-code artifacts/golden/`. Fails if the committed vectors are stale |
| `release.yml` | tag-triggered: build signed release APK from secrets, attach to a GitHub release |

### 5.7 README requirements

The root `README.md` must contain, in this order: a one-paragraph description leading with **offline and local-only**; a screenshot; an explicit **"what this app is not"** section (not contraception, not medical advice, not a diagnostic); quickstart for the app (`fvm flutter run`) and for research (`uv sync`); the repo map with a one-line description per top-level folder; a link to `docs/PLAN.md`, `docs/MODEL.md`, and `docs/PRIVACY.md`; the privacy summary with the permission list; how to export and delete your data; how to build the APK; how to run tests; the license; and an explicit statement that no analytics, crash reporting, or network calls exist, with the CI check that proves it.

---

## 6. Ethics and responsibility

Menstrual data is among the most sensitive categories of personal data a phone can hold. It reveals sexual activity, pregnancy, pregnancy loss, fertility treatment, gender identity, and chronic illness. Treat every decision in this project as if the data will one day be read by someone the user did not choose.

### 6.1 Dataset consent and licensing

- **Nothing enters `data/raw/` without a recorded license.** `data/DATASETS.md` must have, before first use: source URL, license text or link, whether participants consented to secondary research use, download date, SHA256, and row count. If any of those is unknown, the dataset is not used.
- **Candidate public data** (all marked **[VERIFY]** for slug, license, and provenance before use):
  - A Kaggle dataset commonly circulated as "Menstrual Cycle Data" (file `FedCycleData071012.csv`, roughly 159 participants and 1,600+ cycles, originating from a natural family planning study). **[VERIFY exact Kaggle slug, license, and the original study's consent terms.]**
  - Published *summary statistics* from large app-derived studies, notably Bull et al., "Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles", npj Digital Medicine (2019), and Symul et al. (2019) on fertility-awareness app data. **[VERIFY exact figures before baking them into priors.]** Summary statistics are the safest possible input: they carry no individual records at all.
- **Do not scrape any app's user data, ever**, including from public forums or exported datasets of dubious provenance. If the participants could not reasonably have known their cycle data would be used to train a model, do not use it.
- **The synthetic generator is the primary dataset, not a fallback.** `data/synthetic.py` produces users with configurable regularity, drift, anovulatory cycles, missed logs, and outliers. It requires zero consent, has no license risk, cannot be taken offline, and can be made arbitrarily adversarial. Public data is used only to sanity-check that the simulator's marginals resemble reality. This inverts the usual dependency and removes an entire class of ethical and operational risk.
- **Attribution:** any dataset used gets attributed in the README and in the in-app About screen.

### 6.2 The overclaiming risk (the most important section here)

A period predictor is one API call away from claiming to be a contraceptive. It must not.

**Hard non-claims, to be enforced in code review and in copy:**

| Never say | Why |
| --- | --- |
| "Safe days", "you can't get pregnant", "protected" | Contraceptive efficacy claims. Apps making them are regulated medical devices in the US and EU. Natural Cycles is FDA-cleared for contraception after clinical trials; this app has none of that and must not imply equivalence |
| "You are ovulating today" | Ovulation cannot be determined from cycle dates alone. At best a *probable range* can be estimated, and even that assumes a typical luteal phase |
| "You are pregnant" or "you may be pregnant" | A late period has many causes. This is a diagnosis and it is not the app's to make |
| "You have PCOS" or any condition name as a conclusion | Diagnosis. The app may say "your cycles are more variable than typical, which is worth discussing with a clinician" |
| A bare predicted date with no interval | Implies a precision the model does not have. This is the everyday form of overclaiming and the easiest to slip into |

**Enforced behaviors:**

- Every prediction ships with an interval and a confidence class. There is no code path that renders a point estimate alone.
- A first-run disclaimer screen, and a permanent one-line disclaimer on the insights screen. Not a buried EULA.
- The word "fertile" appears only with the qualifier "estimated" and only alongside a statement that it must not be used to prevent pregnancy.
- If ovulation estimation is added at all, it is off by default.

### 6.3 Community involvement and inclusive design

The analogue of "nothing about us without us" applies directly. A cycle-tracking app built by one person without input from the people who will use it will get the copy, the defaults, and the edge cases wrong.

- **Recruit 3 to 5 reviewers before calling MVP done**, deliberately including at least one person with irregular cycles (PCOS, endometriosis, thyroid, or perimenopause). Their cycles are exactly the ones the model handles worst and the copy insults most easily.
- **Gender-neutral copy throughout.** Trans men and nonbinary people menstruate. Write "you" and "people who menstruate", never "women" in UI strings. This costs nothing and materially changes who can use the app.
- **No shaming, no cutesy euphemism, no forced positivity.** Plain language: "period", "bleeding", "cramps".
- **Never guess at pregnancy, pregnancy loss, or sexual activity in copy.** A missed period is a data state, not a life event to comment on.
- **Accessibility is part of inclusion**, and it is machine-enforced rather than aspirational. Contrast, tap-target size, labelled controls, calendar and chart semantics, text scaling to 200%, and never-colour-alone are specified with their CI gates in **2.4.4**. A colour-only calendar is unusable with a screen reader, and `fl_chart` output is invisible to one by default.
- Feedback is collected by the user talking to you. There is no in-app feedback channel, because that would need the network.

### 6.4 Modeling limitations, stated honestly

Document these in `docs/MODEL.md` and summarize them in-app. The model observes **only self-reported bleeding dates and symptoms**. It structurally cannot know about: hormonal contraception (which often removes true cycles entirely), pregnancy and postpartum, breastfeeding, perimenopause, PCOS and endometriosis, thyroid and other endocrine conditions, medications, significant weight change, eating disorders, acute stress, illness, travel across timezones, or adolescence (cycles are typically irregular for years after menarche). Each of these breaks the "cycles are a noisy stationary-ish process" assumption the filter is built on.

Consequences that must be built, not just written down: the model widens rather than narrows under instability; a `TooIrregular` state exists and is shown; and the app says what it is doing ("this prediction is based on your last 6 cycles, which have varied by about 5 days") rather than presenting a number from nowhere.

### 6.5 Privacy and data handling

The app processes everything locally. The concrete commitments:

| Commitment | Enforcement |
| --- | --- |
| No network access of any kind | INTERNET permission removed from the manifest; `assert_no_network.sh` in CI; no network-capable dependency permitted in `pubspec.lock` |
| No analytics, no crash reporting, no telemetry | Reviewed in the PR checklist; MLflow local-only keeps the same rule in `research/` |
| No cloud backup | `android:allowBackup="false"` and explicit `dataExtractionRules` so Android auto-backup cannot copy the DB off-device |
| Data is only ever exported by an explicit user action | Export writes to a user-chosen location via the system file picker; no silent writes to shared storage |
| Retention is entirely the user's | No server retention exists. In-app: delete a single day, delete a cycle, or delete everything with a typed confirmation. Deletion is a real `DELETE` plus a `VACUUM`, not a soft-delete flag |
| Logs contain no cycle content | Reviewed per PR; logs are viewable and clearable in Settings |
| Minimal permissions | `POST_NOTIFICATIONS` only |

**Threat model, stated plainly (`docs/THREAT_MODEL.md`):**

| Threat | Covered by this design? |
| --- | --- |
| Network interception or server breach | Yes, completely. There is no network and no server |
| A curious person picking up an unlocked phone | **No.** There is no app lock in MVP. Documented gap; app lock is the first post-MVP privacy feature |
| Device seized and forensically imaged, or legal compulsion | **Partially.** Android full-disk encryption protects a powered-off device. Once unlocked, the database is plaintext. This is the accepted risk of the chosen posture. This matters concretely for users in jurisdictions where reproductive health data has been sought in legal proceedings, a documented concern in the US since 2022 |
| Malicious app on the same device | Yes for a non-rooted device (Android app sandbox); no on a rooted or compromised device |
| Backup exfiltration via cloud | Yes, `allowBackup="false"` |

**On the plaintext database:** you chose the plain local DB, so that is what this plan specifies, and the tradeoff is recorded rather than relitigated. Two things make it a defensible choice rather than a careless one: (1) the migration path is designed in from day one, so switching to SQLCipher later is a swap of the Drift `QueryExecutor` plus a one-time re-encrypt migration, not a rewrite; and (2) the honest risk statement above ships in `PRIVACY.md` so the user is not misled about what "private" means here. If your threat model ever includes device seizure, revisit ADR-0004.

---

## 7. Risks and mitigations

Likelihood and impact: L / M / H.

| # | Risk | L | I | Mitigation | Fallback if it happens |
| --- | --- | --- | --- | --- | --- |
| R1 | **Public dataset is unavailable, unlicensed, or has unclear consent.** Kaggle datasets vanish and provenance is often undocumented | H | M | Build `synthetic.py` **first**, in M4, and make it the primary training and evaluation substrate. Record checksums and licenses in `DATASETS.md` before any use. Mirror any approved dataset locally | Ship on synthetic data plus published summary statistics for the priors. The model is low-dimensional enough that well-chosen priors from literature figures are sufficient. Nothing blocks |
| R2 | **ExecuTorch on-device training is experimental and may change shape or break.** The `torch`/`executorch` version pairing and the Kotlin `TrainingModule` API are the least stable things in this stack | H | M | Tier B is deliberately Phase 3, feature-flagged, and isolated behind a 4-method Kotlin channel. Pin `torch` and `executorch` as a matched pair and bump them together, never separately. Spike a bare `trainStep` on a real device before writing any of `lib/ml/` | Drop Tier B entirely: the MVP has zero ML dependency, and deleting the channel plus `lib/ml/` is a clean removal with no user-facing effect. Or degrade Tier B to inference-only with a head trained offline, which is a stable non-experimental ExecuTorch path and can use `executorch_flutter` directly |
| R3 | **Class and population imbalance: the training and evaluation data over-represents regular cycles** from fertility-aware users, so the model looks great and fails for the people who most need it | H | H | Stratify every backtest by regularity class and report metrics **per stratum**, never pooled. Make the simulator produce a realistic share of irregular and anovulatory users. Gate any model change on "did the irregular stratum get worse" | Restrict confident predictions to the regular stratum and return `TooIrregular` for the rest. A wide honest interval beats a narrow wrong one |
| R4 | **Overfitting to a narrow population** (the dataset-equivalent of overfitting to one signer): priors fitted on one study's participants do not transfer | M | H | Priors are weakly informative by construction, and the per-user posterior dominates after roughly 3 cycles. Test transfer explicitly: fit priors on simulator population A, evaluate on population B | Widen the priors toward uninformative. The cost is a slightly worse cold start, which is the right thing to trade away |
| R5 | **Python and Dart implementations silently diverge** after an edit to one side | M | H | Golden vectors committed in `artifacts/golden/`, asserted by both test suites, plus a CI job that regenerates them and fails on drift. PR checklist item makes it explicit | The golden test fails and blocks the merge, which is the mitigation working. Recovery is a one-line fix in whichever runtime drifted |
| R6 | **Overconfident predictions cause real harm** (a user relies on the app to avoid pregnancy, or is distressed by a "late" flag) | M | H | Interval-always UI with no point-estimate code path; explicit non-claims list in 6.2; calibration test as a merge gate; first-run disclaimer; no pregnancy inference | Widen all intervals globally via a single config constant, and add a stronger in-app warning. The lever exists and is one number |
| R7 | **Date, timezone, and DST bugs** corrupt cycle lengths. This is the highest-probability *correctness* bug in any calendar app | H | M | Store timezone-naive civil dates, never UTC instants. Injectable `Clock` with a lint rule banning `DateTime.now()` in domain code. Hypothesis-driven property tests over DST boundaries, leap days, and month ends | Bugs are caught by the property suite before release. Post-release, a data-repair migration recomputes derived lengths from stored dates, which are the source of truth |
| R8 | **Data loss with no cloud backup.** Phone lost or reset means all history gone, and there is no server to restore from | M | H | Export/import is an MVP feature, not a nice-to-have. Prompt for an export after every 3 completed cycles. Round-trip fuzz test. DB corruption detection on open with automatic side-copy | The user restores from their last export. If they never exported, the data is gone; this is the honest cost of no-cloud and belongs in the README |
| R9 | **Scope creep.** Fertility windows, BBT, wearables, widgets, encryption, iOS, Play Store all feel small individually | H | M | The MVP checklist in 2.1 is frozen. Everything else goes into a `docs/BACKLOG.md` and is not touched until every M3 box is ticked. Milestones have explicit exit criteria | If M3 slips badly, cut Tier B (M5) and the Streamlit dashboard (M4) entirely. Neither is on the user-facing path |
| R10 | ~~**Android build toolchain friction on this machine.**~~ **RESOLVED at AND-01.** JDK 25 was present and unsupported by AGP; Flutter was not installed; the `.gitignore` ignored `lib/` and `build/` and would have excluded every Dart source file | H | M | Pinned the Android Studio JBR 21 rather than installing a second JDK, installed Flutter 3.47.0 via FVM, and rewrote `.gitignore` with the Python patterns scoped to `research/`. Verified: `git check-ignore -v app/lib/main.dart` prints nothing, and a release APK builds | n/a, resolved. The residual finding is that ecosystem lag behind a days-old Dart release is real: see the freezed pre-release caveat in 3.5 |
| R11 | **On-device personalization is unstable at n=1 to 3 cycles**, producing wild interval swings that destroy trust | M | M | The per-user hyperparameter refit is disabled below 5 cycles; the model falls back to population-level sigma and drift. Interval width is floored by a config constant. Calibration is measured per history length | Freeze the per-user refit entirely and ship the population-hyperparameter filter, which is still fully personalized in its mean estimate |
| R12 | **Notification reliability on Android.** OEM battery optimizers (Xiaomi, Samsung, Huawei) silently kill scheduled local notifications | H | L | Use inexact alarms and reschedule on app open and on `BOOT_COMPLETED`. Detect a missed reminder on next open. Add a Settings note about battery optimization with a deep link to the system screen | Downgrade the reminder to an in-app banner on next open. The reminder is a convenience, not the product |
| R13 | **Tier B never beats the Bayesian baseline** after significant effort | M | L | The gate in `ml/gate.dart` is designed to reject it: the ML head only activates if it beats Tier A on the user's own rolling backtest. Effort is capped at one milestone | Delete `ml/` and ship Tier A. This is a fully acceptable outcome and the plan is structured so it costs nothing user-facing |
| R14 | **Solo-project motivation decay** on an unlimited timeline with no external deadline | M | M | Milestones are sized in sessions, not weeks. M3 produces something you use daily, which is the real motivation engine. Dogfood from M3 onward | Ship M3 and stop. It is a complete, useful app. M4 to M6 are genuinely optional |
| R15 | **Notification opt-out cascade.** One noisy notification type causes the user to disable notifications app-wide, losing the useful predictions along with the nudge | M | M | Separate channels per type (2.4.3), the nudge defaulted **off** with a hard 1-per-7-days cap, and no notification that is not either actionable or a prediction | Detect a long stretch with notifications disabled and surface the reminder as an in-app banner on next open instead. The reminder is a convenience, not the product |
| R16 | **Lock-screen notification leaks cycle content.** A visible banner exposes reproductive health data to anyone near the phone, bypassing every other privacy control in the project | M | H | `VISIBILITY_SECRET` or generic text by **default**, detailed content only behind an explicit opt-in, and a scheduling test that asserts the default (5.4) | The setting is one toggle and one config constant, so a regression is a one-line fix. It is defaulted safe precisely because the failure mode is silent |
| R17 | **`TooIrregular` becomes demotivating.** A user with PCOS or perimenopause who sees "we cannot predict this" every cycle stops logging, which degrades the data further and makes the state permanent. A compound ethics, sustained-use, and model-quality failure | M | H | `TooIrregular` must never be a dead end: it always shows cycle statistics, observed range, and pattern history, so the app stays useful without a point prediction. Copy frames variability as information, never as user failure. Recruit an irregular-cycle reviewer at MVP (6.3) | Widen the intervals and keep predicting rather than refusing, accepting worse calibration in exchange for the app staying useful. Expose it as a user setting: "always show a prediction, even when uncertain" |

---

## 8. Appendix: the model, concretely

This is the shape of `bayes_filter.py` and `bayes_filter.dart`. Full derivation goes in `docs/MODEL.md`.

**State space on log cycle length.** Let `y_i = log(length of cycle i in days)`.

```
Level:       mu_i   = mu_{i-1} + w_i,      w_i ~ Normal(0, q^2)      # slow drift
Observation: y_i    ~ StudentT(nu, mu_i, s)                          # heavy tails
```

Working in logs keeps lengths positive and makes variability multiplicative, which matches how cycle variation actually behaves. The Student-t observation (nu fixed at 4) is what makes a single 55-day cycle after a run of 29s widen the interval instead of dragging the mean, which a Gaussian would do.

- **Inference:** a scalar Kalman filter with an IRLS-style robust reweighting step for the t-likelihood. O(1) per cycle, closed form, roughly 200 lines of Dart, no dependencies.
- **Population priors** (`priors_v1.json`): `mu_0 ~ Normal(log 29, tau^2)`, plus priors on `q` and `s`, fitted offline with NumPyro NUTS. This is the only thing the research pipeline ships into the app.
- **On-device personalization:** every K cycles (K=5 default), refit `(s_user, q_user)` by maximizing the filter's one-step-ahead predictive log-likelihood over a small 2D grid. A few thousand floating-point operations. This is genuine on-device learning: it runs on the phone, on the user's data, and nothing leaves the device.

  > **Measured at PY-A, and it changes how you should read this section.** The refit is **required for correctness, not an enhancement**. Without it the filter learns a user's mean but never their variability, because `obs_var` is a population constant, so every user converges to the same interval width. Backtest on 400 simulated users, nominal 80% coverage:
  >
  > | stratum | without refit | with refit |
  > | --- | --- | --- |
  > | pooled | 0.78 | 0.80 |
  > | regular | 0.90 | 0.86 |
  > | irregular | **0.41** | **0.67** |
  >
  > Note the trap: the pooled figure without the refit was 0.78, which would have passed a pooled gate at plus or minus 3 points while the model covered 41% of outcomes for irregular users behind a label saying 80%. This is the concrete evidence for the "never report pooled" rule, and for treating calibration rather than MAE as the primary metric. The residual gap for irregular users is tracked by a strict xfail in `research/tests/test_calibration.py`; closing it needs a time-varying variance, not a finer grid.
- **Output:** the one-step-ahead predictive distribution over `y_{n+1}`, converted to a start-date distribution and then to `{median, p25-p75 window, p10-p90 window, confidence class}`.
- **Confidence class:** derived from predictive interval width and history length. `high` (80% window under 4 days), `medium` (under 8), `low` (under 14), `TooIrregular` above that.
- **Baselines it must beat** in backtest, or the complexity is not justified: last-cycle-length, mean-of-last-3, mean-of-last-6, median-of-last-6. Report all of them in every MLflow run.
- **Primary metric is calibration (interval coverage), not MAE.** A model with 1.5-day MAE and 60% coverage on its nominal 80% interval is worse for this product than one with 2.0-day MAE and 79% coverage.

**Tier B (Phase 3, optional):** a small model predicting the *residual* of the Bayesian forecast from features the filter ignores (recent symptom patterns, seasonality, cycle-to-cycle autocorrelation), trained on device via ExecuTorch's `TrainingModule` and `SGD` through the Kotlin channel, checkpointed locally, and activated only if `ml/gate.dart` finds it beats Tier A on the user's own rolling-origin backtest. Structuring it as a gated residual head means the worst case is that it is never activated, which costs the user nothing.

---

## 9. Next 3 actions

Tasks AND-01 through AND-07 are complete (see [ANDROID_TASKS.md](ANDROID_TASKS.md)): toolchain, manifest hardening with a CI-proven no-network guarantee, lint and CI, core primitives, domain models, cycle segmentation, and the Tier A filter port. Both Python prerequisites are done too: `artifacts/golden/predictor_cases_v1.json` (PY-A) and `artifacts/priors/priors_v1.json` (PY-B) are committed, and the golden file regenerates byte-identically from the reference. 390 Dart tests pass and `lib/domain/` is at 100% line coverage. The release-APK and no-network CI gates from AND-02 are untouched by the domain work and still run on every push.

The two-runtime contract is now real rather than planned: every float in the golden vectors matches between the Python reference and the Dart port bit for bit, comfortably inside the 1e-9 the contract allows. What remains next:

1. **Build the persistence layer (AND-08).** Drift tables, DAOs, `schemaVersion`, migration steps against committed snapshots, and corrupt-database detection on open. It is the only remaining MVP dependency that nothing else can start without, and the migration tests are the part that must not be hurried: a failed migration on a real phone is unrecoverable data loss.

2. **Wire storage to prediction (AND-09).** `CycleRepository` and a `PredictionRepository` keyed by a hash of the input cycle list, so an edit to any logged day invalidates the cached posterior. `Intervals.forHistory` already returns the filter state and refit alongside the windows, which is what the cache stores; this task is also where predicted cycle *lengths* become predicted *dates*, since the anchor date lives in the data layer.

3. **Put something on screen (AND-11, then AND-15).** The app shell can start in parallel with AND-08 because it only needs AND-03. AND-15 is the first screen that shows a prediction, and it is where the honesty rules in 6.2 stop being prose and start being UI: all four `PredictionResult` variants render, and `TooIrregular` shows the user their own statistics rather than a dead end.

**Add a golden-drift CI job when convenient.** ADR-0002 calls for a job that regenerates the artifacts from `research/` and fails if the committed files differ. `flutter test` already fails when the Dart port and the committed golden vectors disagree, and CI fails when the generated priors constants drift from the artifact, so the remaining uncovered case is narrow: the committed artifacts going stale against the Python source that produced them.
