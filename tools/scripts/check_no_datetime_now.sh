#!/usr/bin/env bash
#
# Fail if DateTime.now() appears anywhere in app/lib/ except core/clock.dart.
#
#   usage: tools/scripts/check_no_datetime_now.sh
#
# Why this is enforced rather than merely documented: this is a date-driven app,
# and a stray DateTime.now() in domain or UI code makes tests non-deterministic
# and makes DST and timezone bugs unreproducible. Risk R7 in docs/PLAN.md rates
# date arithmetic as the highest-probability correctness bug in the project.
#
# Every clock read goes through the injectable Clock in lib/core/clock.dart.
# See docs/PLAN.md 5.1 (pre-commit config) and 5.5 (edge cases).
#
# Used as a pre-commit hook and in CI (.github/workflows/flutter.yml).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/app/lib"
ALLOWED="core/clock.dart"

if [[ ! -d "$LIB" ]]; then
  echo "check_no_datetime_now: $LIB does not exist yet, nothing to check."
  exit 0
fi

# Exclude the one legitimate site, plus generated code which we do not hand-edit.
hits="$(
  grep -rn --include='*.dart' -E 'DateTime\.now\(\)' "$LIB" 2>/dev/null \
    | grep -v "/${ALLOWED}:" \
    | grep -v '\.g\.dart:' \
    | grep -v '\.freezed\.dart:' \
    || true
)"

if [[ -n "$hits" ]]; then
  {
    echo "FAIL: DateTime.now() found outside app/lib/${ALLOWED}"
    echo ""
    echo "$hits"
    echo ""
    echo "Inject Clock from lib/core/clock.dart instead:"
    echo "    final today = clock.today();"
    echo ""
    echo "A direct DateTime.now() makes tests non-deterministic and DST bugs"
    echo "unreproducible. See docs/PLAN.md 5.1 and 5.5, and risk R7."
  } >&2
  exit 1
fi

echo "OK: no DateTime.now() outside app/lib/${ALLOWED}"
exit 0
