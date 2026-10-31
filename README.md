# Selene

> **App:** Selene, a menstrual cycle tracker for Android that works entirely offline.\
> **Platform:** Android, built with Flutter 3.47 and Dart. Distributed as a signed APK; there is no Play Store listing.\
> **Prediction:** A Bayesian model that learns from your own logs on the phone, starting from population averages fitted in Python.\
> **Privacy:** No internet permission at all, and the database is encrypted on the phone. Nothing leaves the phone unless you export it, or confirm a search that opens in your browser. See the [Privacy Policy](PRIVACY_POLICY.md).\
> **Medicines reference:** The safety sections of 5,687 US drug labels from openFDA, bundled into the app.\
> **Herbs reference:** NCCIH's public-domain fact sheets on 56 herbal supplements, such as St. John's wort, bundled into the app.\
> **Github Link:** [Github Link](https://github.com/Proteus-Nell/Selene)

## App Functionalities

- **Logs** period days, flow, and physical, mental, and emotional symptoms. Intercourse can optionally be logged.
- **Predicts** the next period as a date range with a confidence level. The prediction starts from population averages and adjusts to your own cycles as you log them.
- **Explains** what you logged: cycle phases on the calendar, insights from your own history, and conditions such as PMOS (formerly PCOS) or hormonal contraception recorded alongside it.
- **Looks up medicines and herbs:** US drug labelling, searched or browsed A to Z, and NCCIH's fact sheets on herbal supplements. It compares two or more medicines, or a herb and a medicine, based on what their labels and fact sheets state, and flags pairs among the medicines you record.
- **Makes a summary for a doctor:** a PDF of period dates, cycle lengths, symptoms, conditions, and medicines over a span you choose, or the same as spreadsheet files. Intercourse details are excluded.
- **Notifications and reminders:** before a period is due, once if one is late, and at the times you set for each medicine. Notifications are made by the phone itself, and the lock screen shows no detail unless you turn it on.
- **Privacy & data consolidation:** no account, no sync, no analytics. The database is encrypted on the phone, a backup can be protected with a passphrase, and an optional app lock asks for your fingerprint or PIN before showing anything.

Selene is not a contraceptive and does not give medical advice. It never tells you when you cannot get pregnant, and its medicine pages show US labelling, which can differ from the packet in front of you.

## Installing and updating

Download the APK from the [latest release](https://github.com/Proteus-Nell/Selene/releases/latest): `selene-<version>-arm64-v8a.apk` suits nearly every phone. To update, install the newer APK over the old one; your data stays. Every release is signed with the same key and has a higher version code than the one before, which is what Android checks.

An APK from anywhere else, such as a CI run, is signed with a different key, and Android will not let a release install over it. If that is what you have, save a backup in **Settings, Export a backup**, uninstall it, install the release, and use **Settings, Restore from a backup**. This is needed once. Each release's notes give the signing certificate's fingerprint, and `SHA256SUMS.txt` beside the APKs lets you check the download.

## Project Directory Structure

```text
Selene/
├── app/                              # The Flutter app (Selene)
│   ├── lib/
│   │   ├── main.dart                 # Opens the database, then starts the app
│   │   ├── core/                     # Clock, dates, theme, logging
│   │   ├── data/                     # Database, repositories, export and import, the summary, reference readers
│   │   ├── domain/                   # Cycle maths and the prediction model, in plain Dart
│   │   ├── features/                 # One folder per screen: today, calendar, log, insights, learn, lookup...
│   │   ├── notifications/            # Local reminders, re-registered after a restart
│   │   ├── routing/                  # Navigation and the bottom bar
│   │   ├── security/                 # The optional app lock
│   │   └── l10n/                     # Every string the user reads (app_en.arb)
│   ├── assets/medicines/             # The bundled openFDA labels, compressed
│   ├── assets/supplements/           # NCCIH's fact sheets on herbs
│   ├── test/                         # Unit, widget, golden and end-to-end tests
│   └── integration_test/             # The smoke flow, run on a device
│
├── research/                         # Python package `cyclecore`: priors, golden vectors, backtests
├── artifacts/                        # What the Python side and the generators hand to the app
│   ├── priors/priors_v1.json         # Population priors the app compiles in
│   ├── golden/                       # Test vectors that keep the Python and Dart models identical
│   └── medicines/selection_v2.json   # Which label stands for each drug
├── tools/scripts/                    # Generators, release build and privacy checks
├── docs/                             # Plan, decisions (ADRs), privacy statement, release guide, sources
├── .github/workflows/flutter.yml     # CI: checks, tests and test APKs on every push
├── .github/workflows/release.yml     # Releases: signed APKs for a version tag, as a draft
├── LICENSE                           # MIT License
├── PRIVACY_POLICY.md                 # Privacy Policy
└── README.md                         # Project overview (this file)
```
- The prediction model exists twice: a Python reference in `research/`, and the Dart version the app runs. Golden test vectors fail the build if the two ever disagree.
- Everything the app needs ships inside it: the model's priors, the medicines and herbs references, and every string. Nothing is fetched at runtime as the release build has no way to fetch anything.

---

## Setup, Build & Directions

The app can be built and tested without touching the Python side. Steps 4 and 5 are only needed to change the bundled data or to ship a release.

### Step 1: Environment Setup
You will need the Flutter SDK, a JDK, and the Android SDK for the app. Python 3.11 and [uv](https://docs.astral.sh/uv/) are only needed for the research side.

**Option A: FVM (Recommended)**

```
# The Flutter version is pinned in app/.fvmrc, and CI fails if the two drift
cd app
fvm install
fvm flutter pub get
```

**Option B: Flutter on your PATH**

- Install Flutter **3.47.0** directly, plus JDK 21 (CI uses Temurin 21) and the Android SDK, then:

    ```
    cd app
    flutter pub get
    ```

**Research side (optional)**

```
cd research
uv sync --group dev
uv run pytest -q
```

### Step 2: Running the App
```
cd app
flutter run
```
* **File Role:**

    `lib/main.dart` opens the local database, handles a corrupt or newer-version file rather than crashing, and starts the app. Everything the user records is stored in that database, in the app's private storage on the phone.

    * **Note**: debug builds declare the internet permission so that hot reload works. Release builds have it removed, and CI checks every release APK for it.
* **Output:** A debug build running on a connected phone or emulator.

### Step 3: Checks & Tests
```
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd ..
bash tools/scripts/check_no_datetime_now.sh
python3 tools/scripts/gen_priors_dart.py --check
python3 tools/scripts/gen_medicines.py --check
```
* **File Role:**

    The CI runs on every push and pull request and also builds the release APKs in addition to checking that none of them declare a network permission.

### Step 4: Regenerating the Bundled Data
Only needed when the priors, the medicines data, or the herbs data change.

```
# Population priors, and the golden vectors that pin the Dart model to them
cd research
uv run cyclecore fit-priors
uv run cyclecore export-golden
cd ..
python3 tools/scripts/gen_priors_dart.py

# Medicines: downloads openFDA's label export (about 1.8 GB, kept under data/, never committed)
python3 tools/scripts/gen_medicines.py --fetch
python3 tools/scripts/gen_medicine_groups.py

# Herbs: reads NCCIH's Herbs at a Glance fact sheets, about sixty pages
python3 tools/scripts/gen_supplements.py --fetch
```
* **File Role:**

    - `cyclecore fit-priors` fits the model's population priors and writes `artifacts/priors/priors_v1.json`. `export-golden` writes the test vectors from the Python reference.
    - `gen_priors_dart.py` compiles the priors into `app/lib/domain/predict/priors_bundled.dart`.
    - `gen_medicines.py --fetch` picks one label for each drug by fixed rules, and packs the labels' safety sections into compressed chunks with a search index. `gen_medicine_groups.py` then resolves the group names table, such as which drugs are NSAIDs, against the new bundle.
    - `gen_supplements.py --fetch` reads NCCIH's fact sheets and keeps their text up to "Keep in Mind", leaving out the photographs, which are not in the public domain. It refuses a sheet that says how much of a herb to take.
    - The two `--fetch` steps are the only parts of the project that use the network. They run on a developer machine, never on the phone.
* **Output:** Updated files under `artifacts/`, `app/assets/medicines/`, `app/assets/supplements/` and the generated Dart, committed together. `--check` fails while they disagree.

### Step 5: Release Build
```
tools/scripts/new_keystore.sh ~/keys/period-tracker-release.jks   # once, ever
tools/scripts/release_version.py set 1.1.0                        # a new version
tools/scripts/release.sh                                          # or push the tag v1.1.0
```
* **File Role:**

    `release_version.py` writes the version, with a version code derived from its name, so each release outranks the last. `release.sh` builds one APK per CPU architecture and refuses to hand over anything unshippable: an APK signed with the debug key, one with the wrong version code, or one that declares a network permission. Pushing a version tag runs the same script in the release workflow, with the key held in the repository's secrets, and leaves a draft release.

    * **Note**: losing the keystore strands every installed copy, because Android refuses an update signed with a different key. Back it up before the first release. [`docs/RELEASE.md`](docs/RELEASE.md) has the full checklist and the secrets the workflow needs.
* **Output:** Signed APKs in `app/build/app/outputs/flutter-apk/`, named `app-<abi>-release.apk`, or a draft release named `Selene <version>`.

---

## Documentation

| Document | What it covers |
| --- | --- |
| [`docs/PLAN.md`](docs/PLAN.md) | Project plan: scope, model, privacy posture and milestones |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Architecture decision records |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | The privacy statement shown inside the app.|
| [`docs/RELEASE.md`](docs/RELEASE.md) | Signing, release checks and refreshing the medicines data |
| [`docs/ANDROID_TASKS.md`](docs/ANDROID_TASKS.md) | The Android work, broken into tasks |
| [`docs/NUTRITION_SOURCES.md`](docs/NUTRITION_SOURCES.md), [`MOVEMENT_SOURCES.md`](docs/MOVEMENT_SOURCES.md), [`WEIGHT_SOURCES.md`](docs/WEIGHT_SOURCES.md) | The sources behind the reference pages in Learn |
| [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) | The privacy policy |

---

## License

Selene is released under the [MIT License](LICENSE).

Three things bundled with it possess their own terms:

- The Figtree font, under the SIL Open Font License 1.1 ([`app/assets/fonts/OFL.txt`](app/assets/fonts/OFL.txt)).
- The drug labelling, from openFDA, under [openFDA's terms](https://open.fda.gov/terms/).
- The herb fact sheets, from the US National Center for Complementary and Integrative Health's [Herbs at a Glance](https://www.nccih.nih.gov/health/herbsataglance), which are in the public domain. Note that their photographs are not, and are not bundled.
