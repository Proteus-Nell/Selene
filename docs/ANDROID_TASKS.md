# Android Task Breakdown

The `app/` Flutter component of Period-Tracker, split into independently promptable tasks. Python `research/` work is **not** enumerated here; only the two Python artifacts that block Android tasks appear, as `PY-A` and `PY-B`.

**How to use this.** Each task carries a **Prompt to paste**, written to be self-contained so a fresh session with no memory of the planning conversation can execute it. Paste one, let it finish, tick the boxes, move on. Every prompt names the `docs/PLAN.md` sections to read first, so the session loads its own context.

**Companion docs:** [PLAN.md](PLAN.md) · [DECISIONS.md](DECISIONS.md)

---

## Index

| ID | Task | Depends on | Est. |
| --- | --- | --- | --- |
| **Foundation** | | | |
| [AND-01](#and-01-toolchain-and-first-build) | Toolchain and first build | none | 1 |
| [AND-02](#and-02-manifest-hardening-and-the-no-network-proof) | Manifest hardening and the no-network proof | AND-01 | 0.5 |
| [AND-03](#and-03-lint-analysis-and-ci) | Lint, analysis, and CI | AND-01 | 0.5 |
| **Domain core (pure Dart, no Flutter imports)** | | | |
| [AND-04](#and-04-core-primitives) | Core primitives: Clock, Result, civil dates, logger | AND-03 | 1 |
| [AND-05](#and-05-domain-models) | Domain models and the PredictionResult union | AND-04 | 0.5 |
| [AND-06](#and-06-cycle-segmentation-and-features) | Cycle segmentation, validation, derived features | AND-05 | 1 |
| [AND-07](#and-07-tier-a-bayesian-filter-port) | Tier A Bayesian filter port + golden conformance | AND-06, **PY-A** | 2 |
| **Data** | | | |
| [AND-08](#and-08-drift-schema-and-migrations) | Drift schema, DAOs, migrations | AND-05 | 1.5 |
| [AND-09](#and-09-repositories-and-prediction-cache) | Repositories and prediction cache invalidation | AND-07, AND-08 | 1 |
| [AND-10](#and-10-export-and-import) | Export and import with a versioned envelope | AND-08 | 1 |
| **UI** | | | |
| [AND-11](#and-11-app-shell) | App shell: theme, routing, DI, l10n | AND-03 | 1 |
| [AND-12](#and-12-onboarding-and-disclaimer) | Onboarding and first-run disclaimer | AND-11 | 0.5 |
| [AND-13](#and-13-log-screen-and-friction-budget) | Log screen and the friction budget | AND-09, AND-11 | 1.5 |
| [AND-14](#and-14-calendar-screen) | Calendar screen with full semantics | AND-09, AND-11 | 1.5 |
| [AND-15](#and-15-insights-screen) | Insights: prediction, history, self-metrics, chart | AND-09, **PY-B** | 1.5 |
| [AND-16](#and-16-settings-screen) | Settings: export, import, delete-all, prefs, privacy | AND-10, AND-11 | 1 |
| **Platform and release** | | | |
| [AND-17](#and-17-notifications) | Notifications: channels, scheduling, privacy defaults | AND-09, AND-11 | 1.5 |
| [AND-18](#and-18-accessibility-gate) | Accessibility gate in CI | AND-14, AND-15 | 1 |
| [AND-19](#and-19-e2e-smoke-and-release-signing) | E2E smoke test and release signing | AND-16, AND-17 | 1 |
| **Tier B (optional, may never be built)** | | | |
| [AND-20](#and-20-kotlin-executorch-channel) | Kotlin ExecuTorch platform channel | AND-19 | 2-3 |
| [AND-21](#and-21-on-device-trainer-and-gate) | On-device trainer and the per-user gate | AND-20 | 2-3 |

Estimates are in sessions and are deliberately rough. **AND-01 through AND-19 is the MVP.** AND-20 and AND-21 are optional and designed to be droppable with no user-facing effect.

### Python prerequisites (not Android tasks)

| ID | What it produces | Blocks |
| --- | --- | --- |
| **PY-A** | `artifacts/golden/predictor_cases_v1.json`, from the Python reference filter and synthetic generator | AND-07 |
| **PY-B** | `artifacts/priors/priors_v1.json`, the fitted population hyperpriors | AND-15 (and AND-07 in full fidelity) |

**Do PY-A before AND-07.** It is item 3 of the "Next 3 actions" in PLAN.md. If you want to start Android work immediately, AND-01 through AND-06 and AND-08 are all unblocked.

### Ordering notes

- **Strictly sequential:** AND-01 to AND-03 to AND-04.
- **Parallel-safe after AND-05:** the domain branch (AND-06, AND-07) and the data branch (AND-08, AND-10) do not touch each other.
- **AND-11 only needs AND-03**, so the app shell can be built early if you want something on screen before the domain work lands.
- AND-18 is deliberately late because it needs real screens to test, but the lint config in AND-03 sets it up.

---

## Foundation

### AND-01 Toolchain and first build

**Depends on:** none · **Blocks:** everything · **Est:** 1 session

**Goal.** Get `flutter build apk --release` succeeding on this machine.

**Scope.** Install Temurin JDK 17 and pin Flutter to it. Install Flutter via FVM, commit `.fvmrc`. Run `flutter create` into `app/`. Set `minSdk 26`, enable core library desugaring, configure the Gradle JDK toolchain.

**Out of scope.** Any app code, any dependency beyond what `flutter create` generates, CI.

**Done when.**
- [ ] `fvm flutter doctor` reports no Android toolchain issues
- [ ] `fvm flutter build apk --release` produces an APK
- [ ] `.fvmrc` committed; `app/.fvm/` ignored
- [ ] `git check-ignore -v app/lib/main.dart` prints nothing

**Prompt to paste.**

```
Repo: Period-Tracker, a Flutter + Python monorepo. Read docs/PLAN.md section 3.5
("Android build layer") and docs/DECISIONS.md ADR-0001 before starting.

Task AND-01: set up the Android toolchain and get a release APK building.

Critical context: this machine has JDK 25 installed, which the Android Gradle
Plugin does not support and which will fail with a confusing toolchain error.
Flutter is not installed at all.

Do:
- Install Temurin JDK 17 and point Flutter at it with `flutter config --jdk-dir`.
- Install Flutter through FVM, pin the stable version, commit `.fvmrc`.
- Run `flutter create` into app/ with an appropriate package id.
- Set minSdk 26, enable coreLibraryDesugaring, set the Gradle JDK toolchain to 17.

Done when `fvm flutter doctor` is clean for Android and
`fvm flutter build apk --release` produces an APK.

Do not: write app code, add dependencies, or set up CI. Those are AND-02 and AND-03.
```

### AND-02 Manifest hardening and the no-network proof

**Depends on:** AND-01 · **Est:** 0.5 session

**Goal.** Make the offline guarantee structural and machine-verified.

**Scope.** Strip `INTERNET` from the merged release manifest with `tools:node="remove"`. Set `allowBackup="false"` and explicit `dataExtractionRules`. Write `tools/scripts/assert_no_network.sh` to fail on any network or location permission in a built APK.

**Out of scope.** CI wiring (AND-03).

**Done when.**
- [ ] `aapt2 dump permissions` on the release APK shows no INTERNET, no ACCESS_NETWORK_STATE, no location
- [ ] `assert_no_network.sh` exits 0 on the current APK and exits non-zero if INTERNET is temporarily re-added
- [ ] Auto-backup is disabled and the extraction rules are explicit

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 3.5 ("Android build layer") and
section 6.5 ("Privacy and data handling"), plus docs/DECISIONS.md ADR-0004.

Task AND-02: make the no-network guarantee structural and provable.

Context: this app must have zero network capability. Flutter's debug manifest
injects INTERNET for hot reload, so it must be actively removed rather than
merely not added. Android auto-backup would otherwise copy the database to
Google's servers, which breaks the offline guarantee.

Do:
- Add `<uses-permission android:name="android.permission.INTERNET"
  tools:node="remove" />` to the release manifest.
- Set android:allowBackup="false" and add explicit dataExtractionRules.
- Write tools/scripts/assert_no_network.sh: run aapt2 dump permissions on an APK
  path passed as $1, exit non-zero if INTERNET, ACCESS_NETWORK_STATE, or any
  location permission appears.

Done when the script passes on a release build, and provably fails when you
temporarily re-add INTERNET (test this, then revert).

Do not: wire it into CI yet. That is AND-03.
```

### AND-03 Lint, analysis, and CI

**Depends on:** AND-01 · **Est:** 0.5 session

**Goal.** Guardrails exist before there is anything to guard.

**Scope.** `analysis_options.yaml` with `very_good_analysis`, plus `public_member_api_docs` scoped to `lib/domain/`. The `.github/workflows/flutter.yml` job. The `no DateTime.now()` pre-commit hook.

**Out of scope.** The Python workflow, the golden-vector workflow.

**Done when.**
- [ ] `fvm dart format --set-exit-if-changed .` and `fvm flutter analyze` both pass
- [ ] CI runs pub get, build_runner, format, analyze, test, debug APK build, and `assert_no_network.sh`
- [ ] The pre-commit hook rejects a `DateTime.now()` added anywhere in `app/lib/` outside `core/clock.dart`

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md sections 5.1 ("Style and tooling") and
5.6 ("Git workflow"), specifically the CI steps table and the pre-commit config.

Task AND-03: set up Dart lint, analysis, and the Flutter CI workflow.

Do:
- app/analysis_options.yaml using very_good_analysis, with
  public_member_api_docs raised to error for lib/domain/ only.
- .github/workflows/flutter.yml: checkout, Flutter pinned from .fvmrc, JDK 17,
  pub get, build_runner build, dart format --set-exit-if-changed,
  flutter analyze, flutter test --coverage, flutter build apk --debug, then
  tools/scripts/assert_no_network.sh.
- A pre-commit hook (tools/scripts/check_no_datetime_now.sh) that fails if
  DateTime.now() appears anywhere in app/lib/ except core/clock.dart. In a
  date-driven app a stray DateTime.now() makes tests non-deterministic and DST
  bugs unreproducible, so this is enforced rather than documented.

Done when CI is green on the current empty-ish app and the hook demonstrably
rejects a test DateTime.now() (verify, then revert).

Do not: add app dependencies or write feature code.
```

---

## Domain core

> Everything in this phase is **pure Dart with no Flutter imports**, so it tests on the desktop VM with no emulator. Coverage target for `lib/domain/` is 90%.

### AND-04 Core primitives

**Depends on:** AND-03 · **Est:** 1 session

**Goal.** The cross-cutting pieces every later task depends on.

**Scope.** `core/clock.dart` (injectable), `core/result.dart` (`Result<T,E>`), `core/date_utils.dart` (civil-date arithmetic, timezone-naive, DST-safe), `core/logging.dart` (structured, ring buffer, no cycle content ever).

**Out of scope.** Models, persistence, UI.

**Done when.**
- [ ] Property tests pass over DST transitions, leap days, month ends, and year boundaries
- [ ] `daysBetween(a, addDays(a, n)) == n` holds for a wide generated range
- [ ] The logger has no API that can accept a date or symptom value

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md sections 5.5 ("Error handling, structured
logging, and edge cases") and 5.4 ("Testing"), plus the repo tree in section 4
for app/lib/core/.

Task AND-04: build the core primitives in app/lib/core/. Pure Dart, no Flutter
imports.

Do:
- clock.dart: an injectable Clock so nothing calls DateTime.now() directly.
- result.dart: a Result<T,E> type, because in domain code failures are values,
  not exceptions.
- date_utils.dart: civil-date arithmetic. Dates are timezone-naive calendar days,
  NEVER UTC instants, because "the day my period started" is a local calendar day.
- logging.dart: structured logging into a ring buffer plus an optional local file.
  It must be impossible to log cycle content: event names, counts, durations, and
  enum states only.

Testing is the point of this task. Write property-based tests covering DST
transition days, leap days, month-end arithmetic, and year boundaries. Date math
is the highest-probability correctness bug in a calendar app.

Do not: add domain models or persistence.
```

### AND-05 Domain models

**Depends on:** AND-04 · **Est:** 0.5 session

**Goal.** Immutable models and the sealed result union the UI must handle exhaustively.

**Scope.** freezed models: `DayLog`, `CycleRecord`, `Prediction`, `Confidence`. The `PredictionResult` sealed union with variants `Predicted`, `InsufficientData`, `TooIrregular`, `DataInconsistent`.

**Done when.**
- [ ] All models are immutable with generated equality and `copyWith`
- [ ] `PredictionResult` forces exhaustive switch at compile time
- [ ] JSON serialization round-trips for every model

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 5.5 (the edge-case table) and the
repo tree in section 4 for app/lib/domain/models/.

Task AND-05: define the domain models in app/lib/domain/models/ using freezed and
json_serializable. Pure Dart, no Flutter imports.

Models: DayLog (date, flow intensity, symptoms), CycleRecord (start, end, length,
validity flag), Prediction (median date, 50% window, 80% window), Confidence
(high/medium/low).

The important one is PredictionResult, a SEALED union with exactly these
variants: Predicted, InsufficientData, TooIrregular, DataInconsistent. Every
consumer must handle all four exhaustively, enforced by the analyzer. There must
be no way to express "a prediction with no uncertainty attached", because the
product rule is that a bare predicted date is never shown.

Done when all models round-trip through JSON and exhaustive switch is enforced.

Do not: write the prediction logic (AND-07) or persistence (AND-08).
```

### AND-06 Cycle segmentation and features

**Depends on:** AND-05 · **Est:** 1 session

**Goal.** Turn a pile of day logs into an ordered, validated cycle list.

**Scope.** `domain/cycles/segmentation.dart`, `validation.dart`, `features.dart` (median, MAD, trend, regularity class).

**Done when.**
- [ ] Handles gaps, single-day periods, back-to-back logs, out-of-order insertion, duplicates
- [ ] An edit that splits or merges a cycle produces the correct new list
- [ ] Implausible cycles (under 15 or over 90 days) are flagged, not silently accepted
- [ ] 90% coverage on this directory

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 5.5 (the edge-case table is the
spec for this task) and section 5.4 for the testing expectations.

Task AND-06: implement cycle segmentation and derived features in
app/lib/domain/cycles/. Pure Dart, no Flutter imports.

- segmentation.dart: ordered day logs to a list of CycleRecords.
- validation.dart: flag implausible cycles (under 15 days, over 90 days,
  overlapping entries). Flag and down-weight, never silently drop or merge.
- features.dart: median cycle length, MAD, trend, and a regularity class.

The edge cases in PLAN.md 5.5 are the acceptance criteria, not suggestions:
gaps, single-day periods, back-to-back logs, out-of-order insertion, duplicate
dates, and edits that split or merge an existing cycle. Use the Clock from
core/, never DateTime.now().

Target 90% line coverage on this directory.

Do not: implement prediction. That is AND-07.
```

### AND-07 Tier A Bayesian filter port

**Depends on:** AND-06 and **PY-A** · **Est:** 2 sessions

**Goal.** Port the Python reference filter to Dart and prove they agree.

**Scope.** `domain/predict/bayes_filter.dart` (robust scalar Kalman filter on log cycle length, Student-t observation), `personalize.dart` (periodic per-user grid refit), `intervals.dart`, `explain.dart`, `priors.dart` generated from `priors_v1.json` with a checksum guard.

**Blocked until** `artifacts/golden/predictor_cases_v1.json` exists.

**Done when.**
- [ ] Every golden vector matches the Python reference to 1e-9
- [ ] Golden cases include cold start, 1 cycle, an outlier cycle, a 90-day gap, and edited history
- [ ] Constant-28-day synthetic user collapses the posterior to 28 with a narrowing interval
- [ ] Alternating 26/34 user makes the interval **widen**, not narrow
- [ ] App refuses to load a priors file with an unknown `schema_version`

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 8 (the model appendix, which is
the spec), section 2 of DECISIONS.md ADR-0002 (the golden-vector contract), and
docs/MODEL.md if it exists.

Task AND-07: port the Tier A prediction model from Python to Dart in
app/lib/domain/predict/. Pure Dart, no Flutter imports, no ML runtime.

The Python reference implementation is research/src/cyclecore/models/
bayes_filter.py. Your Dart port must agree with it to 1e-9 on every case in
artifacts/golden/predictor_cases_v1.json. If that file does not exist yet, stop
and say so: it is produced by the Python task PY-A and this task is blocked on it.

Build:
- bayes_filter.dart: robust scalar Kalman filter on log cycle length with a
  Student-t observation model (nu=4). Roughly 200 lines, no dependencies.
- personalize.dart: periodic refit of per-user observation and drift variance by
  maximizing one-step-ahead predictive likelihood over a small grid. Disabled
  below 5 cycles.
- intervals.dart: predictive distribution to {median, 50% window, 80% window,
  confidence class}.
- explain.dart: plain-language rationale for each prediction.
- priors.dart: generated from artifacts/priors/priors_v1.json, checksum-guarded.
  Refuse to load an unknown schema_version.

Required tests beyond golden conformance: a constant-28-day synthetic user must
collapse the posterior to 28 with a narrowing interval, and an alternating
26/34 user must make the interval WIDEN. The second test is the one that catches
a broken robustness term.

Do not: touch the Python side. If the reference and the port disagree, the port
is wrong.
```

---

## Data

### AND-08 Drift schema and migrations

**Depends on:** AND-05 · **Est:** 1.5 sessions

**Goal.** Durable local storage with migrations that can never lose data.

**Scope.** Drift tables (`PeriodDays`, `DayLogs`, `Symptoms`, `ModelState`, `Settings`), DAOs, `schemaVersion`, migration steps, committed schema snapshots, `tools/scripts/new_migration.sh`.

**Done when.**
- [ ] Every schema version upgrades cleanly to current, tested against committed snapshots
- [ ] In-memory Drift used for tests, no emulator needed
- [ ] Corrupt-database detection on open, with a side-copy rather than a silent empty start
- [ ] Deletion is a real `DELETE` plus `VACUUM`, not a soft-delete flag

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 4 (repo tree, app/lib/data/),
section 5.4 (the migration-test row), and DECISIONS.md ADR-0004.

Task AND-08: build the persistence layer in app/lib/data/db/ using drift.

Tables: PeriodDays, DayLogs, Symptoms, ModelState (cached posterior), Settings.
Add DAOs, set schemaVersion, write migration steps, and commit schema snapshots.
Write tools/scripts/new_migration.sh to bump the version and dump a snapshot.

Non-negotiable requirements:
- Migration tests for every version upgrading to current, against the committed
  snapshots. A failed migration on a real phone is unrecoverable data loss.
- Tests use in-memory drift so they run on the desktop VM with no emulator.
- Detect a corrupt database on open, back the file up beside itself, and surface
  an import-from-export path. Never start empty and appear to have deleted the
  user's data.
- Deletion is a real DELETE plus VACUUM, never a soft-delete flag.

Important: the database is deliberately UNENCRYPTED per ADR-0004, but all access
must go through a single QueryExecutor construction site so a later SQLCipher
swap is a one-line change rather than a rewrite.

Do not: write repositories (AND-09) or export/import (AND-10).
```

### AND-09 Repositories and prediction cache

**Depends on:** AND-07, AND-08 · **Est:** 1 session

**Goal.** Wire storage to prediction with correct invalidation.

**Scope.** `CycleRepository`, `PredictionRepository` keyed by a hash of the input cycle list so edits invalidate correctly.

**Done when.**
- [ ] Editing any past entry invalidates the cached prediction
- [ ] Overlapping or duplicate entries are rejected at the repository boundary with a specific message
- [ ] A long gap (60+ days with no logs) produces the "we lost track" state rather than silent extrapolation

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 4.1 (the production data flow) and
section 5.5 (the edge-case table).

Task AND-09: build the repository layer in app/lib/data/repositories/.

- CycleRepository: reads and writes day logs, exposes the segmented cycle list.
  Reject overlapping or duplicate entries at this boundary with a specific
  message, never silently merge them.
- PredictionRepository: runs the domain/predict filter and caches the result,
  keyed by a hash of the input cycle list so that editing ANY past entry
  correctly invalidates it. This is the subtle bug to avoid: a stale prediction
  after a backdated correction.

Also handle the long-gap case: 60+ days with no logs must yield the "we lost
track" state, not a silent extrapolation.

Use riverpod providers so these are overridable in tests.

Do not: build UI.
```

### AND-10 Export and import

**Depends on:** AND-08 · **Est:** 1 session

**Goal.** The only backup mechanism this app has. It must be bulletproof.

**Scope.** `data/transfer/export_v1.dart` and `import_v1.dart`, versioned JSON envelope with a schema hash and app version stamp.

**Done when.**
- [ ] Round-trip fuzz test: random valid databases export and re-import identically
- [ ] Import refuses an unknown or newer version with a clear message, never partially imports
- [ ] Export writes only to a user-chosen location via the system picker

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 6.5 (privacy commitments) and
risk R8 in section 7.

Task AND-10: build export and import in app/lib/data/transfer/.

This is the ONLY backup mechanism in the app. There is no cloud sync, so if this
is buggy the user loses everything with no recovery.

- A versioned JSON envelope carrying {schema_version, app_version, exported_utc}
  plus all logs and settings.
- export_v1.dart writes to a user-chosen location through the system file picker.
  Never write silently to shared storage.
- import_v1.dart validates before touching the database. Refuse unknown or newer
  schema versions with a clear message. NEVER partially import: it is all or
  nothing, inside a transaction.

Required test: a round-trip fuzz test that generates random valid databases,
exports, re-imports, and asserts the result is identical.

Do not: build the Settings UI that calls this. That is AND-16.
```

---

## UI

### AND-11 App shell

**Depends on:** AND-03 · **Est:** 1 session

**Goal.** Theme, routing, DI, and localization scaffolding, ready for screens.

**Scope.** `MaterialApp.router`, light and dark themes with contrast-checked tokens, `go_router`, `ProviderScope`, `flutter_localizations` with all strings externalized from day one.

**Done when.**
- [ ] Dark mode works and both themes meet 4.5:1 on body text
- [ ] No hardcoded user-facing string anywhere in `lib/`
- [ ] Route guard hook exists but is a no-op (the app lock will use it later)

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 4 (repo tree for app/lib/),
section 2.4.4 (accessibility), and assumption A4 in section 1.3.

Task AND-11: build the app shell in app/lib/app.dart and main.dart.

- MaterialApp.router with go_router.
- Light and dark themes. Pick colour tokens that already satisfy 4.5:1 on body
  text and 3:1 on UI elements, because AND-18 will enforce this in CI and
  retrofitting a palette later is painful.
- ProviderScope for riverpod.
- flutter_localizations wired up with every user-facing string externalized to
  l10n from the start. English only for now, but retrofitting l10n after the UI
  exists is a multi-day refactor.
- A route-guard hook that is currently a no-op. The deferred app lock will use it
  (see docs/DECISIONS.md, "Deferred note: App lock").

Done when the app builds, dark mode works, and no hardcoded user-facing string
exists in lib/.

Do not: build feature screens.
```

### AND-12 Onboarding and disclaimer

**Depends on:** AND-11 · **Est:** 0.5 session

**Goal.** First run sets expectations honestly.

**Scope.** Disclaimer screen, first cycle entry, deferred notification opt-in.

**Done when.**
- [ ] Disclaimer is a real screen, not a buried EULA, and states the app is not contraception and not medical advice
- [ ] Notification permission is **not** requested here
- [ ] A user can reach a working state having entered one date

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 6.2 (the overclaiming section,
which is the copy spec) and section 2.4.3 (notification permission timing).

Task AND-12: build onboarding in app/lib/features/onboarding/.

Screens: a first-run disclaimer, then a single first-cycle entry.

The disclaimer is a real screen the user reads, not a buried EULA. It must state
plainly that this app is not contraception, not medical advice, and not a
diagnostic tool. Use the non-claims table in PLAN.md 6.2 as the copy spec, and
keep the language gender-neutral throughout ("you", "people who menstruate",
never "women").

Critical: do NOT request POST_NOTIFICATIONS here. Asking at first launch gets
denied by reflex, and Android 13+ makes re-asking after a denial deliberately
hard. That request belongs in AND-17, in context, after the first cycle is logged.

Done when a new user can go from install to a working state having entered one
date.
```

### AND-13 Log screen and friction budget

**Depends on:** AND-09, AND-11 · **Est:** 1.5 sessions

**Goal.** Meet the tap budgets in PLAN.md 2.4.2. These are testable numbers.

**Scope.** Today-state landing screen, persistent primary action, inline day stepper for backdating, symptom chips.

**Done when.**
- [ ] "Period started today" from cold start is 2 taps, verified by counting taps in an integration test
- [ ] Backdating 1 to 3 days is 3 taps or fewer
- [ ] Symptoms for today are 4 taps or fewer
- [ ] Any logged day is editable by long-press

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 2.4.2 (the friction budget table,
which is the spec for this task) and section 2.4.1 for why it matters.

Task AND-13: build the logging screen in app/lib/features/log/.

The tap budgets in 2.4.2 are acceptance criteria, not aspirations. Verify them by
counting taps in an integration test:
- "Period started today" from cold start: 2 taps, under 3 seconds. The app opens
  directly to today's state. No splash, no dashboard interstitial.
- Backdate a start by 1 to 3 days: 3 taps. Use an inline day stepper beside the
  primary action, not a modal date picker.
- Log symptoms for today: 4 taps. Chips, not dropdowns, with the last-used set
  surfaced first.
- Correct a wrong entry: 3 taps, via long-press on the day.

Design for the "I am two days late noticing" case, not the same-day happy path.
Real logging is retrospective, one-handed, and often wrong the first time.

Rationale worth keeping in mind: sparse logs degrade prediction quality directly,
so this is a data-quality requirement, not a polish task.
```

### AND-14 Calendar screen

**Depends on:** AND-09, AND-11 · **Est:** 1.5 sessions

**Goal.** The primary surface, and the one most likely to be inaccessible.

**Scope.** Month grid with period days, predicted window, today marker, long-press edit, full per-cell semantics.

**Done when.**
- [ ] Each day cell announces date **and** state to a screen reader
- [ ] Period, predicted, and today are distinguishable without colour
- [ ] Renders without overflow at `textScaler` 2.0
- [ ] The predicted window renders as a **range**, never a single highlighted day

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 2.4.4 (accessibility) and
section 6.2 (never show a bare predicted date).

Task AND-14: build the calendar screen in app/lib/features/calendar/.

A month grid showing period days, the predicted window, and a today marker, with
long-press to edit any day.

Two requirements that are easy to get wrong and hard to retrofit:

1. Accessibility. A grid of coloured cells announces nothing to a screen reader,
   and this is the app's primary surface. Every day cell needs a hand-written
   Semantics label carrying date AND state, for example "14 March, period day 2,
   inside predicted window". Period, predicted, and today must also be
   distinguishable WITHOUT colour (shape or label), and the layout must survive
   textScaler 2.0 without overflow.

2. The predicted window renders as a RANGE. There is no code path that highlights
   a single predicted day, because that implies a precision the model does not
   have.

Add golden tests in light, dark, and greyscale.
```

### AND-15 Insights screen

**Depends on:** AND-09 and **PY-B** · **Est:** 1.5 sessions

**Goal.** Communicate the prediction honestly, including when it cannot be made.

**Scope.** Prediction display with interval and confidence, cycle history list, self-metrics, an accessible variability chart, the `TooIrregular` state.

**Done when.**
- [ ] All four `PredictionResult` variants render, and `TooIrregular` still shows useful statistics rather than a dead end
- [ ] The chart carries a `Semantics` text summary and has a data-table alternative
- [ ] Self-metrics include the model's own recent accuracy
- [ ] A permanent one-line disclaimer is visible on this screen

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md sections 2.4.5 (metrics without
telemetry), 6.2 (overclaiming), 6.4 (modeling limitations), and risk R17.

Task AND-15: build the insights screen in app/lib/features/insights/.

Show: the current prediction, cycle history with lengths, self-metrics, and a
cycle-length variability chart.

Requirements that carry real weight:

1. All four PredictionResult variants must render. TooIrregular is the dangerous
   one (risk R17): a user with PCOS or perimenopause who sees "we cannot predict
   this" every cycle stops logging, which degrades the data and makes the state
   permanent. TooIrregular must NEVER be a dead end. Always show cycle
   statistics, observed range, and pattern history. Frame variability as
   information, never as user failure.

2. fl_chart paints to a canvas and is INVISIBLE to screen readers. Wrap it in
   Semantics with a text summary, and add a toggleable data-table view of the
   same numbers.

3. Self-metrics per 2.4.5, including the model's own track record ("your last 5
   predictions were within 2 days, 4 times"). Computed on device, never
   transmitted. This is the counterweight to overclaiming: a model that reports
   its own accuracy cannot quietly oversell itself.

4. A permanent one-line disclaimer on this screen, not buried.

Requires artifacts/priors/priors_v1.json (Python task PY-B). If it is missing,
stop and say so.
```

### AND-16 Settings screen

**Depends on:** AND-10, AND-11 · **Est:** 1 session

**Goal.** Give the user real control over their data.

**Scope.** Export, import, delete-all with typed confirmation, notification preferences, log viewer and clear, privacy text, about and attribution.

**Done when.**
- [ ] Delete-all requires typing a confirmation and performs `DELETE` plus `VACUUM`
- [ ] `docs/PRIVACY.md` content is shipped in-app verbatim, including the honest statement about the unencrypted database
- [ ] The log viewer shows there is no cycle content in the logs

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 6.5 (privacy commitments) and
docs/DECISIONS.md ADR-0004, especially the accepted-risk statement.

Task AND-16: build the settings screen in app/lib/features/settings/.

Include: export, import, delete-all data, notification preferences, a log viewer
with a clear button, the privacy statement, and an about/attribution section.

Requirements:
- Delete-all requires typing a confirmation word, then performs a real DELETE
  plus VACUUM.
- Ship the docs/PRIVACY.md text in-app verbatim. It must include the honest
  statement that the database is NOT encrypted, so an unlocked or forensically
  imaged device exposes the data. Do not let the word "private" mislead the user
  about what is actually protected.
- The log viewer exists partly so the user can verify for themselves that no
  cycle content is being logged.
```

---

## Platform and release

### AND-17 Notifications

**Depends on:** AND-09, AND-11 · **Est:** 1.5 sessions

**Goal.** Reliable, private, non-nagging local reminders.

**Scope.** Four notification types across two channels, in-context permission request, lock-screen privacy defaults, 1-tap action button, boot reschedule, missed-reminder detection.

**Done when.**
- [ ] Separate channels so the nudge can be muted without losing predictions
- [ ] `POST_NOTIFICATIONS` requested in context, after the first cycle is logged
- [ ] Lock-screen content defaults to secret, asserted by a test
- [ ] The nudge respects a hard cap of 1 per 7 days
- [ ] The action button logs a period start without launching the app
- [ ] Reschedules on prediction change, on edit, and on `BOOT_COMPLETED`

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 2.4.3 (the notification design
table and the Android requirements list) plus risks R12, R15, and R16.

Task AND-17: build notifications in app/lib/notifications/ using
flutter_local_notifications. Fully local, no FCM, no network.

Four types across two channels, per the 2.4.3 table: window opening, likely
started, logging nudge (default OFF, hard cap 1 per 7 days), and late notice
(informational, and it must NEVER mention pregnancy).

The four requirements that matter most:

1. SEPARATE notification channels per type. One channel for everything means a
   user annoyed by the nudge mutes the predictions too.
2. Request POST_NOTIFICATIONS IN CONTEXT, after the first cycle is logged. Never
   at first launch.
3. Lock-screen privacy is the DEFAULT: VISIBILITY_SECRET or generic text unless
   the user explicitly opts into detailed content. A banner reading "Your period
   is expected tomorrow" is a real data leak and is the one place this project's
   offline privacy story leaks by default. Assert the default in a test.
4. A notification action button that logs a period start in one tap without
   launching the app. This is the highest-leverage item in the whole section.

Also: inexact alarms (not exact, which is restricted), a BOOT_COMPLETED
reschedule, reschedule on every prediction change and edit, and missed-reminder
detection on next open. OEM battery optimizers on Xiaomi, Samsung, and Huawei
silently kill scheduled alarms, so add a Settings note with a deep link.
```

### AND-18 Accessibility gate

**Depends on:** AND-14, AND-15 · **Est:** 1 session

**Goal.** Make accessibility machine-enforced, the way the no-network guarantee is.

**Scope.** `app/test/features/a11y_test.dart` running Flutter's guideline matchers on every screen, text-scale goldens, greyscale golden.

**Done when.**
- [ ] `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, and `labeledTapTargetGuideline` pass on every screen, in CI
- [ ] Goldens pass at `textScaler` 1.0, 1.5, and 2.0
- [ ] A greyscale golden proves no information is conveyed by colour alone

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 2.4.4 (the accessibility table,
which is the spec) and the testing table in section 5.4.

Task AND-18: make accessibility machine-enforced rather than aspirational.

The project already proves its no-network guarantee with an automated APK check
that fails CI. Accessibility gets the same treatment, because flutter_test ships
the matchers.

Do:
- app/test/features/a11y_test.dart running meetsGuideline with
  textContrastGuideline, androidTapTargetGuideline, and labeledTapTargetGuideline
  against every screen.
- Golden tests at textScaler 1.0, 1.5, and 2.0. Most Flutter layouts break at
  200% text scale; fix what breaks.
- A greyscale golden proving no information is conveyed by colour alone.
- Wire all of it into .github/workflows/flutter.yml so it fails the build.

VERIFY the exact matcher names against the pinned Flutter version first; they
have been stable but confirm before building around them.

Fix whatever fails rather than lowering the bar.
```

### AND-19 E2E smoke and release signing

**Depends on:** AND-16, AND-17 · **Est:** 1 session

**Goal.** MVP is shippable and provably works end to end.

**Scope.** `integration_test/e2e_smoke_test.dart`, keystore setup, `key.properties` outside git, release build, APK verification.

**Done when.**
- [ ] E2E: onboard, log 3 cycles, see a prediction window, export, wipe, import, state restored
- [ ] `flutter build apk --release --split-per-abi` produces a signed APK
- [ ] `assert_no_network.sh` passes on the release APK
- [ ] Keystore is backed up outside the repo, and `key.properties` is gitignored

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md sections 3.7 (APK deployment) and 5.4
(the end-to-end smoke test row).

Task AND-19: end-to-end test and release signing. This closes out the MVP.

- integration_test/e2e_smoke_test.dart: onboard, log 3 cycles, assert a
  prediction WINDOW renders, export, delete all data, import, assert the state is
  restored.
- Create a release keystore. Reference it from android/key.properties, which must
  be gitignored (already covered by .gitignore). Back the keystore up somewhere
  outside the repo: losing it means you can never upgrade an installed app in
  place.
- flutter build apk --release --split-per-abi.
- Run tools/scripts/assert_no_network.sh against the release APK.

Done when a signed arm64-v8a APK installs on a real device and the smoke test
passes.
```

---

## Tier B (optional)

> Per [ADR-0006](DECISIONS.md#adr-0006-pytorch-and-executorch-replace-tensorflow-and-litert-entirely), ExecuTorch on-device training is **experimental** and its Flutter package is inference-only, so a Kotlin channel is mandatory. Risk R2 sits at High likelihood. **Both tasks are designed to be deletable**: dropping them removes the ExecuTorch dependency entirely and the MVP is unaffected.

### AND-20 Kotlin ExecuTorch channel

**Depends on:** AND-19 · **Est:** 2-3 sessions

**Goal.** One platform channel exposing both inference and training.

**Done when.**
- [ ] A spike proves `trainStep` runs on a real device **before** any `lib/ml/` code is written
- [ ] One `org.pytorch:executorch-android` dependency, one version, one error surface
- [ ] Deleting the channel plus `lib/ml/` returns the APK to zero ML runtime

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/DECISIONS.md ADR-0006 in full, plus docs/PLAN.md
section 3.5 ("Tier B integration") and risk R2.

Task AND-20: build the Kotlin platform channel for ExecuTorch.

Start with a SPIKE, not with architecture: get a bare trainStep running on a real
device using ExecuTorch's TrainingModule and SGD. These APIs are experimental. If
the spike fails or the API has shifted, stop and report rather than working
around it. Tier B is optional and dropping it costs nothing user-facing.

If the spike succeeds, build ONE Kotlin platform channel at
android/app/src/main/kotlin/.../ExecuTorchChannel.kt over
org.pytorch:executorch-android, exposing exactly four methods: load(assetPath),
infer(features), trainStep(batch), saveCheckpoint(path). Plus the Dart side at
app/lib/ml/executorch_channel.dart.

Deliberately NOT using the executorch_flutter pub package: it is inference-only,
and using it alongside a training channel would mean two independent linkages of
the runtime in one APK with two version pins that can skew.

Pin torch and executorch as a matched pair; they must be bumped together.

Constraint: deleting this file plus lib/ml/ must return the APK to zero ML
runtime. Keep the boundary clean.
```

### AND-21 On-device trainer and gate

**Depends on:** AND-20 · **Est:** 2-3 sessions

**Goal.** Train the residual head locally, and only use it if it earns its place.

**Done when.**
- [ ] The gate correctly **rejects** the ML head on synthetic users where Tier A is better
- [ ] Tier A remains the fallback on every failure path
- [ ] The feature flag defaults off

**Prompt to paste.**

```
Repo: Period-Tracker. Read docs/PLAN.md section 8 (the Tier B paragraph) and
docs/DECISIONS.md ADR-0003 and ADR-0006.

Task AND-21: build the on-device trainer and the activation gate in app/lib/ml/.

- ondevice_trainer.dart: drives trainStep through the Kotlin channel and persists
  the checkpoint locally.
- gate.dart: runs a rolling-origin backtest on the USER'S OWN cycle history and
  activates the ML head only if it beats the Tier A Bayesian baseline.

The gate is the point of this task. It is designed to be able to reject the model
it is gating. Test it on synthetic users where Tier A is known to be better and
assert the gate says no. A gate that always passes is worse than no gate.

Requirements:
- Feature flag defaults OFF.
- Tier A remains the fallback on every failure path: training failure, missing
  checkpoint, channel error, gate rejection.
- Never block the UI on training. It runs in the background and the prediction
  path stays synchronous.

If this never beats Tier A, that is a fully acceptable planned outcome. Say so
and stop rather than tuning until it wins.
```
