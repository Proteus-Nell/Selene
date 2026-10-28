#!/usr/bin/env bash
#
# Build the release APKs and refuse to hand over anything unshippable.
#
#   usage: tools/scripts/release.sh
#
# Four things have to be true of an APK before it is worth installing on
# someone's phone, and all four have failed silently in other projects:
#
#   1. It is signed with the real release key, not the debug key. A debug-signed
#      "release" build installs fine on the machine that made it, which is
#      exactly why nobody notices until an upgrade is refused.
#   2. Its version code is the one its version name gives, and the same in
#      every APK of the release, so it installs over any earlier release
#      whichever architecture either was built for (release_version.py).
#   3. It declares no network permission (docs/PLAN.md 6.5, ADR-0004).
#   4. It is split per ABI, so the download does not carry three copies of the
#      native SQLite the app never uses (docs/PLAN.md 3.7).
#
# The release workflow (.github/workflows/release.yml) runs this same script
# with the key from the repository's secrets. See docs/RELEASE.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$REPO_ROOT/app"
OUT="$APP/build/app/outputs/flutter-apk"

if [[ ! -f "$APP/android/key.properties" ]]; then
  echo "ERROR: app/android/key.properties not found." >&2
  echo "       Run tools/scripts/new_keystore.sh first, or see docs/RELEASE.md." >&2
  exit 2
fi

# The version code is derived from the version name. A pubspec that breaks the
# rule is refused before anything is built.
version="$(python3 "$REPO_ROOT/tools/scripts/release_version.py" check)"
EXPECTED_CODE="$(sed -n 's/^code=//p' <<<"$version")"

# -Prelease-signing-required=true turns the build's debug-key fallback into a
# hard failure, so this cannot quietly produce an unshippable APK.
#
# -Pforce-version-code-ignoring-abi=true stops Flutter adding 1000 x ABI to each
# split's version code. With it added, the arm64 APK of one release has a
# higher code than the 32-bit APK of the next, and Android refuses that as a
# downgrade.
( cd "$APP" && flutter build apk --release --split-per-abi \
    -Prelease-signing-required=true \
    -Pforce-version-code-ignoring-abi=true )

shopt -s nullglob
apks=("$OUT"/app-*-release.apk)
if (( ${#apks[@]} == 0 )); then
  echo "ERROR: no release APKs were produced in $OUT" >&2
  exit 1
fi

find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return 0
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
    local found
    # `sort -V` is a GNU extension that BSD sort (macOS) does not have. Sorting
    # on a zero-padded key built from the version directory name gets the same
    # answer with only POSIX tools, and without it "9.0.0" sorts above "34.0.0".
    found="$(find "$sdk/build-tools" -maxdepth 2 -name 'apksigner' -type f 2>/dev/null |
      awk -F/ '{
        for (i = 1; i <= NF; i++) if ($i == "build-tools") v = $(i + 1)
        split(v, part, ".")
        printf "%09d%09d%09d\t%s\n", part[1], part[2], part[3], $0
      }' | sort | tail -1 | cut -f2)"
    [[ -n "$found" ]] && { echo "$found"; return 0; }
  fi
  return 1
}

find_aapt2() {
  if command -v aapt2 >/dev/null 2>&1; then
    command -v aapt2
    return 0
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
    local found
    found="$(find "$sdk/build-tools" -maxdepth 2 -name 'aapt2*' -type f 2>/dev/null |
      awk -F/ '{
        for (i = 1; i <= NF; i++) if ($i == "build-tools") v = $(i + 1)
        split(v, part, ".")
        printf "%09d%09d%09d\t%s\n", part[1], part[2], part[3], $0
      }' | sort | tail -1 | cut -f2)"
    [[ -n "$found" ]] && { echo "$found"; return 0; }
  fi
  return 1
}

APKSIGNER="$(find_apksigner || true)"
if [[ -z "$APKSIGNER" ]]; then
  echo "ERROR: apksigner not found. Set ANDROID_HOME or put it on PATH." >&2
  exit 2
fi
AAPT2="$(find_aapt2 || true)"
if [[ -z "$AAPT2" ]]; then
  echo "ERROR: aapt2 not found. Set ANDROID_HOME or put it on PATH." >&2
  exit 2
fi

for apk in "${apks[@]}"; do
  echo ""
  echo "== $(basename "$apk")"

  certs="$("$APKSIGNER" verify --print-certs "$apk")"
  # The Android debug key is a fixed, publicly known certificate. Shipping an
  # APK signed with it means anyone can sign an update for this app.
  if grep -qi 'CN=Android Debug' <<<"$certs"; then
    echo "ERROR: $(basename "$apk") is signed with the ANDROID DEBUG KEY." >&2
    echo "       This must not be distributed. Check app/android/key.properties." >&2
    exit 1
  fi
  echo "$certs" | grep -i 'Signer #1 certificate DN' || true

  code="$("$AAPT2" dump badging "$apk" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p" | head -1)"
  if [[ "$code" != "$EXPECTED_CODE" ]]; then
    echo "ERROR: $(basename "$apk") has version code '$code', not $EXPECTED_CODE." >&2
    exit 1
  fi
  echo "Version code $code"

  bash "$REPO_ROOT/tools/scripts/assert_no_network.sh" "$apk"
done

echo ""
echo "All ${#apks[@]} release APK(s) are release-signed and network-free:"
for apk in "${apks[@]}"; do
  printf '  %s  %s\n' "$(du -h "$apk" | cut -f1)" "$apk"
done
