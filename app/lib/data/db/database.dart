import 'package:drift/drift.dart';
import 'package:period_tracker/data/db/daos/day_log_dao.dart';
import 'package:period_tracker/data/db/daos/model_state_dao.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/tables.dart';
// Used by the generated part file: drift writes the enum types of textEnum
// columns into database.g.dart, which inherits this library's imports.
import 'package:period_tracker/domain/models/day_log.dart';

part 'database.g.dart';

/// Thrown when the stored database was written by a newer build of the app.
///
/// This is not an error to recover from automatically. A newer schema may hold
/// columns and rows this build cannot represent, so opening it read-write would
/// either lose them on the next write or crash halfway through. Refusing is the
/// only option that keeps the user's data intact, and the UI is expected to say
/// plainly that the app needs updating.
final class DatabaseDowngradeException implements Exception {
  /// Creates the exception.
  const DatabaseDowngradeException({
    required this.storedVersion,
    required this.supportedVersion,
  });

  /// Schema version found in the file.
  final int storedVersion;

  /// Newest schema version this build understands.
  final int supportedVersion;

  @override
  String toString() =>
      'DatabaseDowngradeException: the database is at schema v$storedVersion '
      'but this build of the app only understands v$supportedVersion. '
      'Update the app rather than downgrading it.';
}

/// The app's local SQLite database.
///
/// Deliberately **unencrypted**, in app-private storage, per DECISIONS.md
/// ADR-0004. The accompanying guarantees that make that a defensible posture
/// rather than a careless one live elsewhere: no `INTERNET` permission,
/// `allowBackup="false"`, and a real delete rather than a soft-delete flag. The
/// last of those is implemented here, in [DayLogDao.deleteEverything].
///
/// Every executor this class is constructed with comes from `connection.dart`,
/// which is the single construction site ADR-0004 requires so that swapping in
/// SQLCipher later is one file's worth of change.
@DriftDatabase(
  tables: <Type>[DayLogs, Symptoms, ModelStates, Settings],
  daos: <Type>[DayLogDao, ModelStateDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database over the given [QueryExecutor].
  ///
  /// Every executor the shipped app passes here is built by
  /// `createQueryExecutor` in `connection.dart`, which ADR-0004 requires to be
  /// the only construction site. The parameter is called `e` solely because
  /// drift's generated superclass calls it that, and the analyzer requires a
  /// super parameter to match.
  AppDatabase(super.e);

  /// The newest schema version this build understands.
  ///
  /// Bump this with `tools/scripts/new_migration.sh`, which also dumps the
  /// schema snapshot the migration tests replay against. Never bump it by hand:
  /// a version without a committed snapshot is a version nothing tests.
  static const int latestSchemaVersion = 1;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // drift calls onUpgrade whenever the stored version differs from this
      // build's, in either direction, so a downgrade arrives here too.
      if (from > to) {
        throw DatabaseDowngradeException(
          storedVersion: from,
          supportedVersion: to,
        );
      }
      // v1 is the only schema that has ever existed, so there is no upgrade
      // path to run yet and this line is unreachable today. When v2 lands,
      // tools/scripts/new_migration.sh dumps the v1 snapshot and the step goes
      // here, guarded by `if (from <= 1) { ... }` so that every older version
      // walks the full chain. The migration test replays every committed
      // snapshot through this method, which is what stops that chain rotting.
      throw UnsupportedError(
        'no migration path from schema v$from to v$to. Add the step to '
        'AppDatabase.migration.onUpgrade, then run '
        '`flutter test test/data/db/migration_test.dart`, which replays every '
        'committed snapshot and is what just caught this.',
      );
    },
    beforeOpen: (details) async {
      // SQLite defaults foreign keys OFF, per connection, for backwards
      // compatibility. Without this the cascade from DayLogs to Symptoms does
      // not fire and deleting a day silently leaves its symptom rows behind:
      // health data surviving a deletion the user believed was complete.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
