#!/usr/bin/env bash
#
# Print what signed a built APK, and refuse to be quiet about not knowing.
#
#   usage: tools/scripts/apk_signer_cert.sh [--digest] <path-to-apk>
#
# Without --digest, prints apksigner's whole certificate report on stdout.
# With it, prints only the signing certificate's SHA-256 digest, lowercase hex
# and no colons, which is the form apksigner itself prints.
#
# Why this is a script of its own. The release path asked apksigner this same
# question in two places, tools/scripts/release.sh and the release workflow,
# each with its own copy of the parsing. Cutting v1.1.0 on 2026-10-29 found out
# what that costs: the runner's newest build-tools was 37.0.0, whose apksigner
# answered in a way neither copy read, and both failed in the wrong direction.
# release.sh took an empty report, found no "CN=Android Debug" in it, and
# declared the APKs release-signed on no evidence at all. The workflow reported
# APKs "not all signed by one certificate" whose certificates it had never
# managed to read.
#
# So: one implementation, and it fails closed. A report this script cannot
# recognise is an error naming the apksigner that produced it and quoting it in
# full, because the next person to hit a new build-tools should be told what it
# said rather than left to guess from a wrong message.
#
# Set APKSIGNER to use a particular one. Otherwise PATH is tried, then the
# highest-versioned build-tools under ANDROID_HOME or ANDROID_SDK_ROOT. Gradle
# signs with the build-tools its AGP pins, which is not necessarily this one,
# so the choice is reported on stderr wherever it matters.

set -euo pipefail

DIGEST_ONLY=false
if [[ "${1:-}" == "--digest" ]]; then
  DIGEST_ONLY=true
  shift
fi

APK="${1:-}"
if [[ -z "$APK" ]]; then
  echo "usage: $0 [--digest] <path-to-apk>" >&2
  exit 2
fi
if [[ ! -f "$APK" ]]; then
  echo "ERROR: APK not found: $APK" >&2
  exit 2
fi

find_apksigner() {
  if [[ -n "${APKSIGNER:-}" ]]; then
    echo "$APKSIGNER"
    return 0
  fi
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

TOOL="$(find_apksigner || true)"
if [[ -z "$TOOL" ]]; then
  echo "ERROR: apksigner not found." >&2
  echo "       Set ANDROID_HOME (or ANDROID_SDK_ROOT), put apksigner on PATH," >&2
  echo "       or set APKSIGNER to the one to use." >&2
  exit 2
fi

# Both streams. apksigner has put its warnings on stderr and its report on
# stdout, and a version that moves part of the report is the failure this
# script exists to survive: a report read from one stream only is how an empty
# one came to look like a clean one.
status=0
REPORT="$("$TOOL" verify --print-certs "$APK" 2>&1)" || status=$?

# A report with no signer in it proves nothing, whether apksigner failed or
# answered in an unfamiliar shape. Either way this is not a pass.
if (( status != 0 )) || ! grep -qiE '^Signer #[0-9]+ certificate' <<<"$REPORT"; then
  {
    echo "ERROR: could not read the signing certificate of $(basename "$APK")."
    echo "       apksigner: $TOOL"
    echo "       exit status: $status"
    echo "       what it said:"
    if [[ -z "$REPORT" ]]; then
      echo "         (nothing on either stream)"
    else
      sed 's/^/         /' <<<"$REPORT"
    fi
    echo "       An APK whose signer cannot be read must not be distributed:"
    echo "       see docs/RELEASE.md section 1."
  } >&2
  exit 1
fi

if [[ "$DIGEST_ONLY" == false ]]; then
  echo "$REPORT"
  exit 0
fi

# Tolerant of the label's case and of the spacing after the colon, both of
# which are apksigner's to change and neither of which carries meaning.
DIGEST="$(grep -iE '^Signer #1 certificate SHA-256 digest:' <<<"$REPORT" |
  head -1 | sed 's/^[^:]*: *//' | tr -d '[:space:]' | tr 'A-F' 'a-f')"

# 32 bytes, hex. Checked rather than assumed, so a label that matches while the
# value has moved cannot become a fingerprint in the release notes.
if [[ ! "$DIGEST" =~ ^[0-9a-f]{64}$ ]]; then
  {
    echo "ERROR: no SHA-256 certificate digest in the report for" \
      "$(basename "$APK")."
    echo "       apksigner: $TOOL"
    echo "       what it said:"
    sed 's/^/         /' <<<"$REPORT"
  } >&2
  exit 1
fi

echo "$DIGEST"
