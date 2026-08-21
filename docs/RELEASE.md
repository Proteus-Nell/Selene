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

That is the whole procedure. It runs:

```bash
flutter build apk --release --split-per-abi -Prelease-signing-required=true
```

and then, for every APK produced:

1. **`apksigner verify --print-certs`**, failing if the signer is the Android
   debug certificate. A debug-signed release build installs perfectly well on
   the machine that made it, so this is the failure that gets discovered months
   later by a user whose upgrade is refused.
2. **`tools/scripts/assert_no_network.sh`**, failing if the APK declares
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
a universal APK carries all three copies (`docs/PLAN.md` 3.7). Note that Flutter
adds `1000 × ABI` to `versionCode` for split builds, so the per-ABI version
codes are intentionally not equal to the one in `pubspec.yaml`.

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
- [ ] `integration_test/e2e_smoke_test.dart` passes on that device
- [ ] Export writes a file to a directory you chose, and importing it into a
      wiped install restores the same days
- [ ] Notification permission is asked for once, and only after a cycle exists
- [ ] Keystore backups still exist and still open
- [ ] **Release notes carry the re-export warning** — see below
- [ ] No claim in `docs/NUTRITION_SOURCES.md` is still marked `[VERIFY]`

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
`flutter.versionCode` and `flutter.versionName` from it. Bump it before
building — an APK whose `versionCode` is not greater than the installed one
will not install as an upgrade.

`ExportV1.appVersion` records the app version into every export file. Keep it in
step with `pubspec.yaml`: an export that claims the wrong version makes a future
import's compatibility check meaningless.

---

## 5. What CI does and does not cover

CI (`.github/workflows/flutter.yml`) builds the release APKs on every push and
runs `assert_no_network.sh` over all of them, plus a negative control asserting
the *debug* APK fails the same check — without which a broken checker would
leave the build green while proving nothing.

CI has no keystore, so its release APKs are debug-signed and are **build
verification artifacts, not releases**. The only shippable APKs are the ones
`tools/scripts/release.sh` produces on a machine holding the key.
