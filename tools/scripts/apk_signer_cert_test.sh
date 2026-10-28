#!/usr/bin/env bash
#
# Check that tools/scripts/apk_signer_cert.sh reads an apksigner report, and
# refuses one it cannot read.
#
#   usage: tools/scripts/apk_signer_cert_test.sh [path-to-apk_signer_cert.sh]
#
# Runs in CI (.github/workflows/flutter.yml), because the release path it
# guards runs only when a tag is pushed, and this is the half of it that can be
# checked without a key, an Android SDK or a release.
#
# The real apksigner cannot be exercised here without a release APK, and the
# bug this covers was an apksigner whose output nobody had seen: cutting v1.1.0
# found build-tools 37.0.0 answering silently, which release.sh read as an
# empty report and accepted. So the stand-ins are the shapes that matter: a
# silent one, a normal one, one answering on stderr, a debug-signed one, a
# failing one, and one whose label survives while its value moves. What is
# asserted is that only a readable report is ever called a pass.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="${1:-$REPO_ROOT/tools/scripts/apk_signer_cert.sh}"
if [[ ! -f "$HELPER" ]]; then
  echo "ERROR: helper not found: $HELPER" >&2
  exit 2
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APK="$WORK/fake.apk"
printf 'not really an apk' > "$APK"

DIGEST=6ec9d8045980fb7f1e23a677a1d9368fdbe4efacc5ccd4850bb9873608f6daec

make_stub() {
  local name="$1"; shift
  local path="$WORK/$name"
  { echo '#!/usr/bin/env bash'; cat; } > "$path"
  chmod +x "$path"
  echo "$path"
}

silent="$(make_stub silent <<'STUB'
exit 0
STUB
)"

# Build-tools up to 36, which numbered the signers.
numbered="$(make_stub numbered <<'STUB'
echo "Verifies"
echo "Verified using v1 scheme (JAR signing): false"
echo "Verified using v2 scheme (APK Signature Scheme v2): true"
echo "Signer #1 certificate DN: CN=Period Tracker, OU=Unknown, O=Unknown"
echo "Signer #1 certificate SHA-256 digest: 6ec9d8045980fb7f1e23a677a1d9368fdbe4efacc5ccd4850bb9873608f6daec"
echo "Signer #1 certificate SHA-1 digest: 0123456789abcdef0123456789abcdef01234567"
STUB
)"

# Build-tools 37.0.0, which names the signature scheme instead. Copied from
# what it actually printed in the release run for v1.1.0, which is the shape
# that broke the old parsing: there is a colon before "certificate" now, and
# the signer is no longer numbered.
scheme_named="$(make_stub scheme_named <<'STUB'
echo "V2 Signer: certificate DN: CN=Period Tracker, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"
echo "V2 Signer: certificate SHA-256 digest: 6ec9d8045980fb7f1e23a677a1d9368fdbe4efacc5ccd4850bb9873608f6daec"
echo "V2 Signer: certificate SHA-1 digest: 823b635a4f9243655a2c4ec564a8b7ce46333cea"
echo "V2 Signer: certificate MD5 digest: 4a2b56e3b4b484c87bfada9336814733"
STUB
)"

# One signer per scheme, the same certificate said twice, which is what an APK
# signed with both v2 and v3 looks like.
two_schemes="$(make_stub two_schemes <<'STUB'
echo "V2 Signer: certificate DN: CN=Period Tracker"
echo "V2 Signer: certificate SHA-256 digest: 6ec9d8045980fb7f1e23a677a1d9368fdbe4efacc5ccd4850bb9873608f6daec"
echo "V3 Signer: certificate DN: CN=Period Tracker"
echo "V3 Signer: certificate SHA-256 digest: 6EC9D8045980FB7F1E23A677A1D9368FDBE4EFACC5CCD4850BB9873608F6DAEC"
STUB
)"

# Two schemes, two different certificates: key rotation, where answering with
# whichever came first would put one of two real fingerprints in the notes.
rotated="$(make_stub rotated <<'STUB'
echo "V2 Signer: certificate SHA-256 digest: 6ec9d8045980fb7f1e23a677a1d9368fdbe4efacc5ccd4850bb9873608f6daec"
echo "V3 Signer: certificate SHA-256 digest: 1111111111111111111111111111111111111111111111111111111111111111"
STUB
)"

# The report on stderr instead of stdout, which a one-stream read would miss.
on_stderr="$(make_stub on_stderr <<'STUB'
echo "Signer #1 certificate DN: CN=Period Tracker" >&2
echo "Signer #1 certificate SHA-256 digest: 6EC9D8045980FB7F1E23A677A1D9368FDBE4EFACC5CCD4850BB9873608F6DAEC" >&2
STUB
)"

debug_signed="$(make_stub debug_signed <<'STUB'
echo "Signer #1 certificate DN: CN=Android Debug, O=Android, C=US"
echo "Signer #1 certificate SHA-256 digest: 1111111111111111111111111111111111111111111111111111111111111111"
STUB
)"

failing="$(make_stub failing <<'STUB'
echo "DOES NOT VERIFY" >&2
exit 1
STUB
)"

label_only="$(make_stub label_only <<'STUB'
echo "Signer #1 certificate DN: CN=Period Tracker"
echo "Signer #1 certificate SHA-256 digest: (moved elsewhere)"
STUB
)"

pass=0
fail=0
check() {
  local what="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ok    $what"
    pass=$(( pass + 1 ))
  else
    echo "  FAIL  $what"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    fail=$(( fail + 1 ))
  fi
}

run() {
  APKSIGNER="$1" bash "$HELPER" "${@:2}" "$APK" 2>"$WORK/err"
}

echo "a silent apksigner (build-tools 37.0.0's behaviour)"
out="$(run "$silent" --digest)"; status=$?
check "fails instead of returning nothing" 1 "$status"
check "prints no digest" "" "$out"
check "says what it could not read" 0 \
  "$(grep -q 'could not read the signing certificate' "$WORK/err"; echo $?)"
check "names the apksigner it used" 0 \
  "$(grep -q "apksigner: $silent" "$WORK/err"; echo $?)"
check "says there was nothing to read" 0 \
  "$(grep -q 'nothing on either stream' "$WORK/err"; echo $?)"

echo "a numbered report (build-tools 36 and earlier)"
out="$(run "$numbered" --digest)"; status=$?
check "succeeds" 0 "$status"
check "prints the digest, lowercase hex" "$DIGEST" "$out"
out="$(run "$numbered")"; status=$?
check "prints the whole report without --digest" 0 "$status"
check "the report carries the DN" 0 \
  "$(grep -q 'CN=Period Tracker' <<<"$out"; echo $?)"

echo "a scheme-named report (build-tools 37.0.0)"
out="$(run "$scheme_named" --digest)"; status=$?
check "succeeds" 0 "$status"
check "prints the same digest, past the second colon" "$DIGEST" "$out"
out="$(run "$scheme_named")"; status=$?
check "prints the report" 0 "$status"
check "which release.sh can still read a DN out of" 0 \
  "$(grep -qiE 'certificate DN:' <<<"$out"; echo $?)"

echo "one signer per scheme, the same certificate twice"
out="$(run "$two_schemes" --digest)"; status=$?
check "answers once" 0 "$status"
check "with that certificate, however it was cased" "$DIGEST" "$out"

echo "two schemes with two different certificates"
out="$(run "$rotated" --digest)"; status=$?
check "refuses to choose one" 1 "$status"
check "and says there was more than one" 0 \
  "$(grep -q 'more than one signing certificate' "$WORK/err"; echo $?)"

echo "a report on stderr rather than stdout"
out="$(run "$on_stderr" --digest)"; status=$?
check "is still read" 0 "$status"
check "and lowercased" "$DIGEST" "$out"

echo "a debug-signed APK"
out="$(run "$debug_signed")"; status=$?
check "is reported, for release.sh to refuse" 0 "$status"
check "with the debug DN release.sh greps for" 0 \
  "$(grep -q 'CN=Android Debug' <<<"$out"; echo $?)"

echo "an apksigner that fails"
out="$(run "$failing" --digest)"; status=$?
check "fails too" 1 "$status"
check "and quotes what it said" 0 \
  "$(grep -q 'DOES NOT VERIFY' "$WORK/err"; echo $?)"

echo "a label whose value has moved"
out="$(run "$label_only" --digest)"; status=$?
check "is not turned into a fingerprint" 1 "$status"
check "and says so" 0 \
  "$(grep -q 'no SHA-256 certificate digest' "$WORK/err"; echo $?)"

echo "a missing APK"
APKSIGNER="$numbered" bash "$HELPER" --digest "$WORK/nope.apk" >/dev/null 2>&1
check "is refused" 2 "$?"

echo ""
echo "$pass passed, $fail failed"
(( fail == 0 ))
