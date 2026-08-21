#!/usr/bin/env bash
#
# Start a new database schema version (task AND-08).
#
#   usage: tools/scripts/new_migration.sh
#
# Run this AFTER editing app/lib/data/db/tables.dart, not before. It does the
# bookkeeping that a schema change needs and that is easy to half-finish:
#
#   1. bumps AppDatabase.latestSchemaVersion
#   2. regenerates the drift code for the new tables
#   3. dumps a JSON snapshot of the new schema into app/drift_schemas/
#   4. regenerates the migration-test helpers from every committed snapshot
#
# The snapshots are the reason the migration tests can prove that a database
# written by any shipped version still upgrades cleanly. A version without a
# committed snapshot is a version nothing tests, and a failed migration on a
# real phone is unrecoverable data loss: there is no server copy to restore
# from. See docs/PLAN.md 5.4 and DECISIONS.md ADR-0004.
#
# What this script deliberately does NOT do is write the migration itself. That
# is a judgement call about the user's data and it belongs in the `onUpgrade`
# body in app/lib/data/db/database.dart, by hand, with a test.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$REPO_ROOT/app"
DATABASE_DART="$APP_DIR/lib/data/db/database.dart"
SCHEMA_DIR="drift_schemas"
HELPER_DIR="test/data/db/generated_migrations"

# Prefer fvm when the project pins a Flutter version through it, so the codegen
# runs on the same SDK as the build. Fall back to a plain `dart` on PATH.
if command -v fvm >/dev/null 2>&1 && [[ -f "$APP_DIR/.fvmrc" ]]; then
  DART=(fvm dart)
else
  DART=(dart)
fi

if [[ ! -f "$DATABASE_DART" ]]; then
  echo "ERROR: $DATABASE_DART not found." >&2
  exit 2
fi

# sed rather than `grep -oP`: PCRE mode is a GNU extension and the default grep
# on macOS does not have it, which would make bumping the schema a thing that
# only works on Linux.
current="$(sed -n 's/.*static const int latestSchemaVersion = \([0-9][0-9]*\).*/\1/p' "$DATABASE_DART" | head -1)"
if [[ -z "$current" ]]; then
  echo "ERROR: could not read latestSchemaVersion from $DATABASE_DART." >&2
  echo "       Has the constant been renamed?" >&2
  exit 2
fi
next=$(( current + 1 ))

if [[ -f "$APP_DIR/$SCHEMA_DIR/drift_schema_v$next.json" ]]; then
  echo "ERROR: $SCHEMA_DIR/drift_schema_v$next.json already exists." >&2
  echo "       Schema v$next has already been started. Edit its migration in" >&2
  echo "       lib/data/db/database.dart instead of running this again." >&2
  exit 2
fi

# The version has to be bumped before the codegen runs, because drift reads the
# constant to decide what version it is dumping. That makes every step after
# this one a step that can leave the repo half-bumped: a constant at v$next with
# no snapshot behind it. The next run would then read $next as its baseline and
# start v$((next + 1)), quietly skipping a version — which is precisely the
# half-finished bookkeeping this script exists to prevent, so it undoes its own
# edit on the way out unless it reached the end.
restore_version() {
  local status=$?
  if (( status != 0 )); then
    echo >&2
    echo "FAILED partway through. Putting latestSchemaVersion back to $current" >&2
    echo "so the next run starts v$next rather than skipping to v$((next + 1))." >&2
    sed -i.bak \
      "s/static const int latestSchemaVersion = $next;/static const int latestSchemaVersion = $current;/" \
      "$DATABASE_DART"
    rm -f "$DATABASE_DART.bak"
    rm -f "$APP_DIR/$SCHEMA_DIR/drift_schema_v$next.json"
  fi
}

echo "Bumping schema version $current -> $next"
sed -i.bak \
  "s/static const int latestSchemaVersion = $current;/static const int latestSchemaVersion = $next;/" \
  "$DATABASE_DART"
rm -f "$DATABASE_DART.bak"
trap restore_version EXIT

cd "$APP_DIR"

# `dart` comes from the Flutter SDK here. Saying so is worth four lines: the
# failure without it is "dart: command not found" *after* the version has
# already been bumped, which reads as a broken script rather than a missing
# PATH entry.
if ! command -v "${DART[0]}" >/dev/null 2>&1; then
  echo "ERROR: ${DART[0]} is not on PATH." >&2
  echo "       The Dart SDK ships inside Flutter, so this usually means" >&2
  echo "       Flutter's bin/ is not exported. Try:" >&2
  echo "         export PATH=\"/path/to/flutter/bin:\$PATH\"" >&2
  exit 2
fi

echo "Regenerating drift code"
"${DART[@]}" run build_runner build

echo "Dumping the v$next schema snapshot"
"${DART[@]}" run drift_dev schema dump lib/data/db/database.dart "$SCHEMA_DIR/"

if [[ ! -f "$SCHEMA_DIR/drift_schema_v$next.json" ]]; then
  echo "ERROR: the dump did not produce $SCHEMA_DIR/drift_schema_v$next.json." >&2
  echo "       A version with no snapshot is a version nothing tests, so this" >&2
  echo "       stops rather than carrying on." >&2
  exit 2
fi

echo "Regenerating migration-test helpers"
"${DART[@]}" run drift_dev schema generate "$SCHEMA_DIR/" "$HELPER_DIR/"

"${DART[@]}" format "$HELPER_DIR" >/dev/null

trap - EXIT

cat <<EOF

Schema v$next started. Three things are still yours to do:

  1. Write the upgrade in the onUpgrade body of lib/data/db/database.dart.
     Every older version has to reach v$next, so guard each step by the version
     it applies from rather than assuming the previous one.

  2. Run the migration tests. They replay every committed snapshot forward:

       flutter test test/data/db/migration_test.dart

  3. Commit $SCHEMA_DIR/drift_schema_v$next.json together with the table change.
     A snapshot committed later is a snapshot of the wrong thing.

Per docs/PLAN.md 5.6, a schema change is a breaking change: mark the commit with
a ! and a BREAKING CHANGE footer.
EOF
