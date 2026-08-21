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
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart';

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

  test('a v1 database keeps its data across the upgrade', () async {
    // migrateAndValidate compares schema shape, not contents — a migration that
    // dropped and recreated day_logs would pass every test above it and lose
    // every day the user had logged. On a phone that is unrecoverable: there is
    // no server copy. So the upgrade is run against a database with rows in it.
    //
    // schemaAt rather than startAt, because each newConnection() is a fresh
    // open over the same underlying database. Writing through one connection
    // and then migrating on a second is what makes the migration actually run;
    // reusing a single connection leaves it already opened, and the upgrade
    // silently never fires.
    final schema = await verifier.schemaAt(1);

    final v1 = DatabaseAtV1(schema.newConnection());
    await v1.customStatement(
      "INSERT INTO day_logs (epoch_day, flow) VALUES (20000, 'heavy')",
    );
    await v1.customStatement(
      'INSERT INTO symptoms (epoch_day, symptom, severity) '
      "VALUES (20000, 'cramps', 'severe')",
    );
    await v1.customStatement(
      'INSERT INTO settings (setting_key, setting_value) '
      "VALUES ('onboarding_complete', 'true')",
    );
    await v1.close();

    // Read back through the real DAOs, not the generated schema classes: what
    // matters is that the shipping code can still read what the user wrote.
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);

    final logs = await db.dayLogDao.allLogs();
    expect(logs, hasLength(1));
    expect(logs.single.flow, FlowIntensity.heavy);
    expect(logs.single.severityOf(Symptom.cramps), SymptomSeverity.severe);
    expect(
      await db.settingsDao.readBool(
        SettingKey.onboardingComplete,
        orElse: false,
      ),
      isTrue,
    );
    // And the new table exists and is empty, rather than absent.
    expect(await db.select(db.conditions).get(), isEmpty);
    // The v4 column arrives as null on every existing row, which is the true
    // answer: those days were written before the app could record it, so
    // "not recorded" is what they mean. A default would have the app assert
    // something about the user's private life that they never said.
    expect(
      logs.single.intercourse,
      isNull,
      reason: 'the v4 migration invented a value for a day written before it',
    );
  });

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
