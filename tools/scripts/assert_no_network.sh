#!/usr/bin/env bash
#
# Fail if a built APK declares any network-capable or location permission.
#
#   usage: tools/scripts/assert_no_network.sh <path-to-apk>
#
# This is the machine proof behind the central privacy claim in docs/PLAN.md 6.5
# and DECISIONS.md ADR-0004: the app cannot reach the network because the OS
# will not let it. Asserting it here means the guarantee cannot regress silently
# when a plugin is added, since any dependency may declare INTERNET in its own
# manifest and manifest merging would otherwise pull it into the release APK.
#
# Runs locally and in CI (.github/workflows/flutter.yml).

set -euo pipefail

APK="${1:-}"
if [[ -z "$APK" ]]; then
  echo "usage: $0 <path-to-apk>" >&2
  exit 2
fi
if [[ ! -f "$APK" ]]; then
  echo "ERROR: APK not found: $APK" >&2
  exit 2
fi

# Locate aapt2: PATH first, then the highest-versioned build-tools in the SDK.
find_aapt2() {
  if command -v aapt2 >/dev/null 2>&1; then
    command -v aapt2
    return 0
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
    local found
    found="$(find "$sdk/build-tools" -maxdepth 2 -name 'aapt2*' -type f 2>/dev/null | sort -V | tail -1)"
    if [[ -n "$found" ]]; then
      echo "$found"
      return 0
    fi
  fi
  return 1
}

AAPT2="$(find_aapt2 || true)"
if [[ -z "$AAPT2" ]]; then
  echo "ERROR: aapt2 not found." >&2
  echo "       Set ANDROID_HOME (or ANDROID_SDK_ROOT), or put aapt2 on PATH." >&2
  exit 2
fi

# Any of these breaks the offline guarantee.
FORBIDDEN='android.permission.INTERNET
android.permission.ACCESS_NETWORK_STATE
android.permission.ACCESS_WIFI_STATE
android.permission.CHANGE_NETWORK_STATE
android.permission.CHANGE_WIFI_STATE
android.permission.ACCESS_FINE_LOCATION
android.permission.ACCESS_COARSE_LOCATION
android.permission.ACCESS_BACKGROUND_LOCATION'

DUMP="$("$AAPT2" dump permissions "$APK")"

violations=0
while IFS= read -r perm; do
  [[ -z "$perm" ]] && continue
  if grep -qF -- "$perm" <<<"$DUMP"; then
    echo "FORBIDDEN PERMISSION: $perm" >&2
    violations=$(( violations + 1 ))
  fi
done <<<"$FORBIDDEN"

if (( violations > 0 )); then
  {
    echo ""
    echo "FAIL: $APK declares $violations forbidden permission(s)."
    echo "This app must have no network capability whatsoever."
    echo "See docs/PLAN.md 6.5 and docs/DECISIONS.md ADR-0004."
  } >&2
  exit 1
fi

echo "OK: $(basename "$APK") declares no network or location permission."
echo "    verified with: $AAPT2"
exit 0
