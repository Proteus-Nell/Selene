# Releasing

How a build gets from this repository onto a phone, and what has to be true
before it does. Task AND-19.

This app is **self-distributed as an APK**. There is no Play Store listing, no
staged rollout, and no way to push a fix to someone who has already installed a
broken build. That shapes everything below: the checks are front-loaded because
there is no recall.

---

## 1. The signing key

Android identifies an app by *(application id, signing certificate)*. An upgrade
signed by a different key is not an upgrade — the installer refuses it, and the
only path forward for the user is to uninstall, which deletes their data. This
app has no cloud backup by design (ADR-0004), so that data is gone.

**Losing the keystore therefore strands every installed copy permanently.**
There is no reset, no support channel, and no Play App Signing to fall back on.

### Creating it (once, ever)

```bash
tools/scripts/new_keystore.sh ~/keys/period-tracker-release.jks
```

The script refuses to write the keystore inside the repository, refuses to
overwrite an existing one, and checks that `app/android/key.properties` is
actually gitignored before writing a password into it. It produces:

| File | Where | In git? |
| --- | --- | --- |
| `period-tracker-release.jks` | wherever you pointed it, outside the repo | no, and it must never be |
| `app/android/key.properties` | in the repo tree | **no** — gitignored, holds the password |

`key.properties` is what the Gradle build reads:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/period-tracker-release.jks
```

### Backing it up

Do this immediately, before the first release, not after.

- At least two copies, on different media, at least one off-site.
- Encrypted at rest — the file is the app's identity, and the password is in
  `key.properties` next to it if you back both up together. Back the password up
  **separately** (a password manager entry is fine).
- Record the fingerprint somewhere you can find it later, so a restored file can
  be checked against it:

  ```bash
  keytool -list -v -keystore ~/keys/period-tracker-release.jks | grep SHA256
  ```

A keystore that exists only on the laptop that built the last release is not
backed up.

---

## 2. Building

```bash
tools/scripts/release.sh
```

That is the whole procedure, and the release workflow runs the same script
(section 6). It first refuses a `pubspec.yaml` whose build number is not the one
its version name gives (section 4), then runs:

```bash
flutter build apk --release --split-per-abi \
  -Prelease-signing-required=true -Pforce-version-code-ignoring-abi=true
```

and then, for every APK produced:

1. **`apksigner verify --print-certs`**, failing if the signer is the Android
   debug certificate. A debug-signed release build installs perfectly well on
   the machine that made it, so this is the failure that gets discovered months
   later by a user whose upgrade is refused.
2. **`aapt2 dump badging`**, failing unless the APK's version code is the one
   the version name gives. Every APK of a release has the same code.
3. **`tools/scripts/assert_no_network.sh`**, failing if the APK declares
   `INTERNET` or any other network or location permission. Manifest merging
   pulls in permissions declared by *dependencies*, so this has to be checked on
   the built artifact rather than on our own manifest
   (`docs/PLAN.md` 6.5, [ADR-0004](DECISIONS.md#adr-0004-unencrypted-local-sqlite-with-zero-network-permission)).

`-Prelease-signing-required=true` is what turns the build's debug-key fallback
into a hard error. Without `key.properties`, a plain `flutter build apk
--release` still succeeds and signs with the debug key, on purpose: CI has no
keystore, and a fresh clone should be able to run `flutter run --release`. The
build prints a warning when it does, and `release.sh` never allows it.

Output lands in `app/build/app/outputs/flutter-apk/`:

```
app-arm64-v8a-release.apk    ← the one nearly every current phone wants
app-armeabi-v7a-release.apk
app-x86_64-release.apk        ← emulators
```

Split per ABI rather than universal because the app bundles a native SQLite;
a universal APK carries all three copies (`docs/PLAN.md` 3.7). Flutter would
add `1000 × ABI` to each split's `versionCode`, which is for the Play Store's
multi-APK rules. For a sideloaded app it does harm: the arm64 APK of one release
would outrank the 32-bit APK of the next, and Android refuses an install with a
lower code. `-Pforce-version-code-ignoring-abi=true` turns it off, so every APK
of a release carries the code in `pubspec.yaml`.

---

## 3. Before handing an APK to anyone

Run in the repository:

```bash
cd app && flutter analyze && flutter test
bash tools/scripts/check_no_datetime_now.sh
```

Then on a real device, with the release APK installed:

```bash
cd app && flutter test integration_test/e2e_smoke_test.dart -d <device-id>
```

That is the end-to-end smoke flow — onboard, log three cycles, see a prediction
*window*, export, wipe, import, see the state restored. The same flow runs
headless in CI as `test/e2e_smoke_test.dart` on every push, so it is not a
gate you can forget; what the device run adds is proof that the app installs,
starts, and can write through Android's storage access framework against a real
filesystem, none of which a headless test can tell you.

Checklist, in the order the failures actually happen:

- [ ] `flutter analyze` clean, `flutter test` green
- [ ] `tools/scripts/release.sh` completed — release-signed, no network
      permission
- [ ] APK installs on a device that already has the previous version, **as an
      upgrade** (this is the check that catches a wrong key)
- [ ] After that upgrade, every day logged before it is still there. The first
      launch of a build that encrypts the database (ADR-0018) encrypts the
      existing file in place, and this is the only check that sees it happen on
      a real phone's storage
- [ ] `integration_test/e2e_smoke_test.dart` passes on that device
- [ ] Export writes a file to a directory you chose, and importing it into a
      wiped install restores the same days
- [ ] Notification permission is asked for once: after a cycle exists, or when
      a medicine reminder is set
- [ ] A medicine reminder set a few minutes ahead arrives within a few minutes
      of its time, naming the medicine only with lock-screen detail on. This is
      the only check that runs `MainActivity`'s time zone channel (ADR-0025)
- [ ] Setting that reminder on Android 14 or later asks to let reminders
      arrive on time, opens Android's "Alarms and reminders" screen, and the
      Settings row then says they do (ADR-0026). Refuse it instead and the
      reminder is still kept and still arrives, late, and says so. No test can
      see any of this: the permission does not exist off a device
- [ ] Revoke that permission in Android's settings while the app is open: the
      Settings row goes back to "may arrive late", and reminders keep working
- [ ] Keystore backups still exist and still open
- [ ] **Release notes carry the re-export warning** — see below
- [ ] No claim in `docs/NUTRITION_SOURCES.md` is still marked `[VERIFY]`
- [ ] The medicines bundle comes from a recent openFDA export — see below
- [ ] The herbal supplements reference has been read from NCCIH recently — see
      below
- [ ] No claim in `docs/WEIGHT_SOURCES.md` is still marked `[VERIFY]`
- [ ] No claim in `docs/MOVEMENT_SOURCES.md` is still marked `[VERIFY]` —
      including its three absence claims, which are cleared by reading the
      named guidance and finding no phase-based recommendation in it

### The medicines bundle

The medicines reference is every drug in openFDA's label export, one label each
(ADR-0012), packed into `app/assets/medicines` (ADR-0013). The bundle and the
selection it was built from, `artifacts/medicines/selection_v2.json`, are
committed, and the lookup shows the export's date. Refresh both before a
release:

```bash
python3 tools/scripts/gen_medicines.py --fetch   # downloads ~1.8 GB into data/
python3 tools/scripts/gen_medicines.py --check   # should pass
python3 tools/scripts/gen_medicine_groups.py     # resolves the group names again
python3 tools/scripts/gen_medicine_groups.py --check
```

That needs network, on purpose: it is the one part of this project that talks to
anything, and it runs on a developer machine or in CI, never on the phone. The
download is cached under `data/`, which is never committed. Commit
`artifacts/medicines/selection_v2.json`, `app/assets/medicines/` and
`app/lib/data/reference/medicines_bundled.dart` together; `--check` fails when
they disagree. Commit `app/lib/data/reference/medicine_groups_bundled.dart`
with them: the group names table (ADR-0021) names drugs by the bundle's keys,
and its `--check` fails when a member no longer names a drug in the bundle, or
one listed absent has arrived. Either means editing
`artifacts/medicines/groups_v1.json` against its sources, not around them.

A refresh rewrites most of the bundle, and each one adds up to 13 MB to the
repository's history. Refresh for a release, not on every change. The refresh
prints how many Medication Guides it carried and why it left the rest out
(ADR-0022): a refresh that carries far fewer than the last, 506 of 5,687 drugs
on the 2026-10-28 export, means a guide's layout or openFDA's has changed.

Two things to check by eye after fetching, because no test can:

- The `[VERIFY]` marker on the disclaimer in `gen_medicines.py`. Clearing it
  means opening <https://open.fda.gov/terms/> and confirming the wording is what
  they ask to be carried.
- The counts in the selection's `meta`. A large change in any of them between
  two exports, the number of drugs most of all, means openFDA changed something
  the rules depend on. Look at the rules before using the result.
- The interaction checker's examples (ADR-0014). `medicines_test.dart` fails if
  the pill's label stops naming rifampin, or two NSAIDs stop sharing a class,
  but open the checker too: the pill with rifampin, ibuprofen with naproxen,
  and levothyroxine with the pill should each quote the label.
- The group names' examples (ADR-0021): tranexamic acid with the pill should
  quote "combined hormonal contraceptives", with the FDA sources under it.
  The sources themselves are dated where they were read; one that has moved
  or changed is a reason to check the members it gave.

### The herbal supplements reference

The herbs are NCCIH's Herbs at a Glance fact sheets, in the public domain,
packed into `app/assets/supplements/nccih_herbs.json` (ADR-0023). The A to Z
shows the date they were read. Refresh them before a release:

```bash
python3 tools/scripts/gen_supplements.py --fetch   # about sixty pages, a minute
python3 tools/scripts/gen_supplements.py --check   # should pass
```

Like the medicines' fetch, it needs network and runs on a developer machine,
never on the phone. Commit the asset and
`app/lib/data/reference/supplements_bundled.dart` together; `--check` fails when
they disagree. The fetch refuses to write anything when a sheet has lost its
safety section, says how much of a herb to take, or shares a name with another
herb, and says which.

Two things to check by eye after fetching:

- The count. The 2026-10-28 read carried 56 herbs. Fewer means a page stopped
  carrying the public-domain statement, which leaves it out, or NCCIH changed
  its layout; read the pages before shipping the result.
- St. John's wort with a combined pill, in the checker. The pill's label should
  be quoted naming the herb, and the herb's sheet naming "Birth control pills"
  under the line its list hangs from. `supplements_test.dart` fails if either
  stops, but look at it as a reader would.

### The re-export warning (export format v2)

**This release cannot restore backups taken before it.** Export format v2 adds
conditions, and v1 files are refused rather than partially read — ADR-0011,
decided knowingly. This app has no cloud sync and no Play Store restore, so the
export file *is* the recovery path (risk R8): every backup a user is currently
holding stops working the moment they update.

The app shows a one-time banner on the log screen telling them so, and the
release notes have to say the same thing, because a user who dismisses the
banner without reading it has no second chance:

> This update changes the backup file format. Backups you saved with an earlier
> version can no longer be restored — please export again after updating. Your
> data in the app is not affected.

Do not ship without that line. The banner alone is not enough: it appears once,
it can be dismissed with a tap, and someone restoring onto a new phone after
losing the old one will never have seen it.

The one-time banner is driven by `SettingKey.exportFormatAcknowledged`, seeded
at `onCreate` so that fresh installs are never warned about backups they have
never taken. If a future release changes the export format again, bumping
`exportSchemaVersion` makes the same mechanism fire without any new flag — and
this section needs rewriting for the new version.

---

## 4. Versioning

`version:` in `app/pubspec.yaml` is the single source of truth; Gradle reads
`flutter.versionCode` and `flutter.versionName` from it. An APK whose
`versionCode` is not greater than the installed one will not install as an
upgrade, so the code is not chosen by hand. It is derived from the name:

```
versionCode = major × 10000 + minor × 100 + patch      1.0.0 → 10000, 1.2.3 → 10203
```

A later version always has a higher code, as long as minor and patch stay below
100, which the script enforces. Set a new version with:

```bash
tools/scripts/release_version.py set 1.1.0
```

That writes `1.1.0+10100` into `pubspec.yaml` and into `appVersion` in
`export_v1.dart`, the constant every export file is stamped with. A test holds
the two together: an export that claims the wrong version makes a future
import's compatibility check meaningless. Settings shows the name alone.

`tools/scripts/release_version.py check [<tag>]` is what `release.sh` and the
release workflow run. Without a tag it checks the pubspec follows the rule; with
one, it also checks the tag names the same version and that the version is newer
than every one tagged before it.

---

## 5. What CI does and does not cover

CI (`.github/workflows/flutter.yml`) builds the release APKs on every push and
runs `assert_no_network.sh` over all of them, plus a negative control asserting
the *debug* APK fails the same check — without which a broken checker would
leave the build green while proving nothing.

CI has no keystore, so its release APKs are debug-signed and are **build
verification artifacts, not releases**. Every runner makes its own debug key,
so no two CI builds share a signature: one will not install over another, over a
release, or take a release as an update. The artifact is named
`test-apks-debug-signed-not-for-phones` to say so. The only shippable APKs are
the ones `tools/scripts/release.sh` produces with the key, on a machine that
holds it or in the release workflow below.

---

## 6. GitHub Releases

Pushing a tag such as `v1.1.0` runs `.github/workflows/release.yml`, which
builds that commit with the release key and leaves a **draft** release holding
the APKs, `SHA256SUMS.txt`, and the signing certificate's fingerprint. Because
every release is signed with the same key and has a higher version code than the
last, each one installs over the one before it and the data stays.

### Setting it up (once)

The workflow reads the keystore from four repository secrets, under
**Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded: `base64 -w0 ~/keys/period-tracker-release.jks` (on macOS, `base64 -i <file>`) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias`, `upload` unless you chose otherwise |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |

Use the keystore from section 1, the same one any earlier release was signed
with. A new keystore here strands every copy installed from an earlier release,
exactly as losing the old one would.

A secret is readable by anything that runs in a workflow with access to it. Only
`release.yml` asks for these, and it runs only for a tag, which only someone with
write access can push. Keep it that way: do not add a `pull_request` trigger to a
workflow that reads them.

### Cutting a release

```bash
tools/scripts/release_version.py set 1.1.0     # pubspec.yaml and the export stamp
git commit -am "chore(release): 1.1.0"
# open a PR, let CI pass, merge to main, then from main:
git tag v1.1.0
git push origin v1.1.0
```

The workflow refuses, before building anything, a tag that does not match
`pubspec.yaml`, a version that is not newer than every earlier tag, a tag that
is not on `main`, and a missing secret. It then analyzes and tests the tagged
commit, builds with `release.sh`, renames the APKs
`selene-<version>-<abi>.apk`, and drafts the release with notes on installing,
updating and checking the download, followed by the changes since the last tag.

Then work through the checklist in section 3 with the draft's own APK: above
all, that it installs **as an upgrade** over the previous release on a real
phone. Add the re-export warning to the notes if the export format changed.
Then publish the draft.

### Without the workflow

To keep the key off GitHub altogether, leave the secrets unset and build where
the key is: run `tools/scripts/release.sh`, copy each APK to
`selene-<version>-<abi>.apk`, write `sha256sum selene-*.apk > SHA256SUMS.txt`,
and draft the release by hand:

```bash
gh release create v1.1.0 --draft --title "Selene 1.1.0" --generate-notes \
  selene-1.1.0-*.apk SHA256SUMS.txt
```

Copy the installing and updating notes from a workflow-made release, with this
build's certificate fingerprint. The tag still starts the workflow, which stops
at its first check of the secrets, before building anything.

### What the notes tell people

- **Which APK:** `arm64-v8a` for nearly every phone; `armeabi-v7a` for older
  32-bit ones; `x86_64` for emulators. Any of them updates any earlier release,
  since they share a version code.
- **Updating:** install the new APK over the old one.
- **Coming from a build that was not a release** (a CI artifact, or one built
  with the debug key): Android refuses the install, because the signatures
  differ. Save a backup with *Export a backup*, uninstall, install the release,
  and *Restore from a backup*. Once only: after that, releases update each other.
- **Checking the download:** `sha256sum -c SHA256SUMS.txt`, and the certificate
  fingerprint, which `apksigner verify --print-certs <apk>` prints for any APK.
  It is the same for every release; a different one means the APK is not ours.
