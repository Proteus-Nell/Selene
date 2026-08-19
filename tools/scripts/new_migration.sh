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

current="$(grep -oP 'static const int latestSchemaVersion = \K[0-9]+' "$DATABASE_DART" || true)"
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

echo "Bumping schema version $current -> $next"
sed -i.bak \
  "s/static const int latestSchemaVersion = $current;/static const int latestSchemaVersion = $next;/" \
  "$DATABASE_DART"
rm -f "$DATABASE_DART.bak"

cd "$APP_DIR"

echo "Regenerating drift code"
"${DART[@]}" run build_runner build

echo "Dumping the v$next schema snapshot"
"${DART[@]}" run drift_dev schema dump lib/data/db/database.dart "$SCHEMA_DIR/"

echo "Regenerating migration-test helpers"
"${DART[@]}" run drift_dev schema generate "$SCHEMA_DIR/" "$HELPER_DIR/"

"${DART[@]}" format "$HELPER_DIR" >/dev/null

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
