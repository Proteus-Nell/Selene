// Schema migration tests (docs/PLAN.md 5.4).
//
// Non-negotiable, and the reason is worth restating where the test lives: a
// failed migration on a real phone is unrecoverable data loss. There is no
// server copy, so if an upgrade drops a table the user's history is simply
// gone. Every schema version the app has ever shipped therefore has a committed
// snapshot in `drift_schemas/`, and this file replays each one forward into the
// current schema.
//
// Regenerate the snapshots with `tools/scripts/new_migration.sh`.

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';

import 'generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('every shipped schema version is snapshotted', () {
    // The versions the helper knows are exactly the snapshots in
    // drift_schemas/. If someone bumps schemaVersion without dumping a
    // snapshot, this fails immediately and says so, rather than the migration
    // tests below silently covering one version less than they should.
    expect(
      GeneratedHelper.versions,
      List<int>.generate(AppDatabase.latestSchemaVersion, (i) => i + 1),
      reason:
          'schemaVersion is ${AppDatabase.latestSchemaVersion} but the '
          'committed snapshots are ${GeneratedHelper.versions}. Run '
          'tools/scripts/new_migration.sh.',
    );
  });

  for (final version in GeneratedHelper.versions) {
    test('a v$version database upgrades to the current schema', () async {
      final connection = await verifier.startAt(version);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      // Runs the real MigrationStrategy, then compares the resulting schema
      // against the committed snapshot of the target version, column by column.
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    });
  }

  test('a freshly created database matches its own snapshot', () async {
    // onCreate takes a different path through drift than onUpgrade does, so a
    // schema that migrates correctly can still be created wrongly. This is the
    // case that covers a brand new install.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
  });

  test('the live schema matches what the generated code expects', () async {
    // Catches a table edited without regenerating: drift compares every table,
    // column, type and constraint it believes in against what SQLite actually
    // created.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });
}
