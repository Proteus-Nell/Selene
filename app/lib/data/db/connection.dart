/// Database connection and recovery.
///
/// The single place the app opens its database file. Verifies the file before
/// handing it over, quarantines a damaged one rather than deleting it, and
/// refuses a file written by a newer build.
///
/// Pipeline:
///     1. Open the file and run `PRAGMA quick_check`.
///     2. Let the migration run.
///     3. On a newer schema, refuse and return no database at all.
///     4. On damage, move the file aside with its sidecars and open a fresh
///        one, so the old data survives for a later build to read.
///
/// Includes:
///     - DatabaseCorruptException: The integrity check failed.
///     - DatabaseOpenOutcome: The sealed union of what an open produced.
///     - createQueryExecutor: The one construction site ADR-0004 requires.
///     - openAppDatabase, openAppDatabaseWithoutRecovery: The two entry
///       points, foreground and background.
///     - verifyIntegrity: The check itself.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';

/// Name of the database file inside the app's private directory.
const String databaseFileName = 'period_tracker.sqlite';

/// Suffix given to a database file that failed its integrity check.
const String quarantineSuffix = 'corrupt';

/// Database corrupt exception: the file opened but failed `quick_check`.
///
/// Distinct from [SqliteException] because a file can be readable enough to
/// open and still be damaged, and the two arrive by different routes.
///
/// Attributes:
///     detail (String): What `quick_check` reported instead of `ok`.
final class DatabaseCorruptException implements Exception {
  /// Creates the exception with the check output in [detail].
  ///
  /// Args:
  ///     detail (String): What `quick_check` reported instead of `ok`.
  const DatabaseCorruptException(this.detail);

  /// What `quick_check` reported instead of `ok`.
  final String detail;

  @override
  String toString() => 'DatabaseCorruptException: $detail';
}

/// Database open outcome: what happened when the database was opened.
///
/// A sealed union rather than a nullable database, because the two failure
/// states are not errors to swallow: one of them means the user's history is
/// sitting in a quarantined file and the app must offer to restore from an
/// export, and the other means the app must not write to this file at all.
/// Both have to be rendered, so neither can be representable as "just null".
sealed class DatabaseOpenOutcome {
  const DatabaseOpenOutcome();
}

/// Database opened: the ordinary outcome.
///
/// Attributes:
///     database (AppDatabase): The usable database.
final class DatabaseOpened extends DatabaseOpenOutcome {
  /// Wraps the opened [database].
  ///
  /// Args:
  ///     database (AppDatabase): The usable database.
  const DatabaseOpened(this.database);

  /// The usable database.
  final AppDatabase database;
}

/// Database recovered from corruption: the file was set aside and replaced.
///
/// [database] is empty. [quarantinedFile] still holds whatever survived, and
/// it is never deleted: it is the user's data, damaged but theirs, and a later
/// build with better recovery tooling may be able to read more out of it than
/// this one can.
///
/// The UI must say what happened and offer import-from-export. Starting empty
/// and silent would look exactly like the app having deleted everything, which
/// is the single worst thing this app can do to someone (`docs/PLAN.md` 5.5).
/// Attributes:
///     database (AppDatabase): A working but empty database.
///     quarantinedFile (File): The damaged file, kept beside the new one.
final class DatabaseRecoveredFromCorruption extends DatabaseOpenOutcome {
  /// Wraps the fresh [database] and the [quarantinedFile] it replaced.
  ///
  /// Args:
  ///     database (AppDatabase): A working but empty database.
  ///     quarantinedFile (File): The damaged file, kept beside it.
  const DatabaseRecoveredFromCorruption({
    required this.database,
    required this.quarantinedFile,
  });

  /// A working but empty database.
  final AppDatabase database;

  /// The damaged file, kept beside the new one.
  final File quarantinedFile;
}

/// Database refused newer schema: the file is from a later build.
///
/// No database is returned on purpose. Opening it read-write would drop
/// whatever the newer schema holds, which is data loss dressed up as
/// robustness.
///
/// Attributes:
///     storedVersion (int): Schema version found in the file.
///     supportedVersion (int): Newest version this build understands.
final class DatabaseRefusedNewerSchema extends DatabaseOpenOutcome {
  /// Records the version mismatch.
  ///
  /// Args:
  ///     storedVersion (int): Schema version found in the file.
  ///     supportedVersion (int): Newest version this build understands.
  const DatabaseRefusedNewerSchema({
    required this.storedVersion,
    required this.supportedVersion,
  });

  /// Schema version found in the file.
  final int storedVersion;

  /// Newest version this build understands.
  final int supportedVersion;
}

/// **The single [QueryExecutor] construction site.**
///
/// ADR-0004 accepts an unencrypted database on the condition that this stays
/// true: every connection the production app makes is created here, so
/// adopting SQLCipher later is a change to this function plus a one-time
/// re-encrypt migration, rather than an audit of every call site. Tests
/// construct `NativeDatabase.memory()` directly, which is deliberate and does
/// not weaken the guarantee: the point is that no *shipped* code path opens a
/// database any other way.
///
/// The executor runs on the calling isolate, not a background one.
///
/// `NativeDatabase.createInBackground` is drift's usual advice and is the right
/// default for apps with heavy queries. This app's are not: the whole database
/// is a few thousand single-column rows even after a decade of daily logging,
/// and the expensive part of a prediction is the filter arithmetic, which runs
/// on the calling isolate regardless. Against that, a background isolate wraps
/// every error thrown while opening in a `DriftRemoteException` from drift's
/// **experimental** `remote.dart`, so the recovery below would have to unwrap a
/// type the package reserves the right to change, or else silently stop
/// matching and quarantine nothing.
///
/// If this ever does move to a background isolate: the `catch` in
/// [openAppDatabase] must unwrap `DriftRemoteException.remoteCause` first.
/// Without that it compiles, passes review, and never recognises a corrupt
/// database again.
/// Args:
///     file (File): Where the database lives.
///
/// Returns:
///     QueryExecutor: An executor running on the calling isolate.
QueryExecutor createQueryExecutor(File file) => NativeDatabase(file);

/// Return the directory the production database lives in.
///
/// The only use of `path_provider` in the codebase. Application *support*
/// rather than documents: this is app state, not a user-visible document, and
/// on Android both are inside the app's private storage, which is what
/// ADR-0004 relies on.
///
/// Returns:
///     `Future<Directory>`: The application support directory.
Future<Directory> defaultDatabaseDirectory() =>
    getApplicationSupportDirectory();

/// Open the database file and prove it is readable before handing it over.
///
/// The one place the file is opened. Both [openAppDatabase] and
/// [openAppDatabaseWithoutRecovery] go through here, so the integrity check
/// and the migration cannot drift apart between them; all that differs is what
/// each does when this throws.
///
/// Args:
///     file (File): The database file to open.
///
/// Returns:
///     `Future<AppDatabase>`: The opened, verified database.
///
/// Throws:
///     DatabaseCorruptException: If `quick_check` reports damage.
///     DatabaseDowngradeException: If the file is from a newer build.
///     SqliteException: If the file cannot be opened at all.
Future<AppDatabase> _attemptOpen(File file) async {
  final database = AppDatabase(createQueryExecutor(file));
  try {
    await verifyIntegrity(database);
  } on Object {
    // Close before rethrowing, or the failed attempt leaves its background
    // isolate and its handle on the file behind. On Windows that handle would
    // then block the rename that quarantines the very file we are recovering.
    try {
      await database.close();
    } on Object {
      // The database is already known to be unusable; a failure to close it
      // cleanly adds nothing the caller can act on.
    }
    rethrow;
  }
  return database;
}

/// Open the app database without ever quarantining a damaged file.
///
/// The same open, the same integrity check and the same migration as
/// [openAppDatabase], with one deliberate difference: this never quarantines.
/// [openAppDatabase] recovers a damaged file by moving it aside, which is the
/// right call when a person is looking at a screen that can tell them so. This
/// exists for the background isolate behind the notification action, where the
/// same move would relocate someone's entire history with nothing on screen
/// and nobody to tell. Returning null there costs one untaken log; recovering
/// there would cost the history, invisibly.
///
/// The next foreground launch calls [openAppDatabase] and handles the damage
/// in the open, which is where that decision belongs.
///
/// Args:
///     directory (Directory): Where the database file lives.
///
/// Returns:
///     `Future<AppDatabase?>`: The database, or null on any failure at all.
Future<AppDatabase?> openAppDatabaseWithoutRecovery({
  required Directory directory,
}) async {
  try {
    return await _attemptOpen(File(p.join(directory.path, databaseFileName)));
  } on Object {
    return null;
  }
}

/// Open the app database, recovering from a damaged file.
///
/// The sequence is deliberate: verify first, hand the database out second. A
/// corrupt SQLite file often opens without complaint and only fails later, in
/// the middle of a write, so checking up front is what turns "the app crashed
/// and my data is gone" into "the app told me it found a problem and kept the
/// old file".
///
/// Args:
///     directory (Directory): Where the database file lives.
///     clock (Clock): Stamps the quarantined file's name.
///     logger (RingLogger?, optional): Records the outcome. Defaults to null.
///
/// Returns:
///     `Future<DatabaseOpenOutcome>`: One of the three outcomes. Never
///     throws for a damaged or newer file; both are outcomes the UI renders.
Future<DatabaseOpenOutcome> openAppDatabase({
  required Directory directory,
  required Clock clock,
  RingLogger? logger,
}) async {
  final file = File(p.join(directory.path, databaseFileName));
  Future<AppDatabase> attempt() => _attemptOpen(file);

  try {
    final database = await attempt();
    logger?.info(LogEvent.dbOpened);
    return DatabaseOpened(database);
  } on DatabaseDowngradeException catch (e) {
    logger?.error(
      LogEvent.dbOpened,
      fields: <String, LogField>{
        'stored_version': LogField.count(e.storedVersion),
        'supported_version': LogField.count(e.supportedVersion),
      },
    );
    return DatabaseRefusedNewerSchema(
      storedVersion: e.storedVersion,
      supportedVersion: e.supportedVersion,
    );
  } on SqliteException catch (_) {
    // Deliberately narrow. Quarantining on any error at all would move the
    // user's database aside because of, say, a full disk, and that presents
    // exactly like the app having deleted their history.
    return _recover(file: file, clock: clock, logger: logger, attempt: attempt);
  } on DatabaseCorruptException catch (_) {
    return _recover(file: file, clock: clock, logger: logger, attempt: attempt);
  }
}

/// Run `PRAGMA quick_check`, which also forces any pending migration.
///
/// `quick_check` rather than `integrity_check`: it catches the damage that
/// matters, skips the per-index scan, and stays fast enough to run on every
/// cold start, which is the only way this check is worth having.
///
/// Args:
///     database (AppDatabase): The database to check.
///
/// Throws:
///     DatabaseCorruptException: If the check reports anything but `ok`.
Future<void> verifyIntegrity(AppDatabase database) async {
  final rows = await database.customSelect('PRAGMA quick_check').get();
  final result = rows.isEmpty ? null : rows.first.data.values.first;
  if (result != 'ok') {
    throw DatabaseCorruptException('quick_check reported: $result');
  }
}

/// Quarantine the damaged file and open a fresh one in its place.
///
/// Args:
///     file (File): The damaged database file.
///     clock (Clock): Stamps the quarantined file's name.
///     logger (RingLogger?): Records that corruption was found.
///     attempt (`Future<AppDatabase> Function()`): Re-opens the file, which
///         now does not exist and so is created empty.
///
/// Returns:
///     `Future<DatabaseOpenOutcome>` : The recovery outcome, carrying both
///     the empty database and the file it replaced.
Future<DatabaseOpenOutcome> _recover({
  required File file,
  required Clock clock,
  required RingLogger? logger,
  required Future<AppDatabase> Function() attempt,
}) async {
  final quarantined = _quarantine(file, clock);
  logger?.warn(LogEvent.dbCorruptionDetected);
  final database = await attempt();
  return DatabaseRecoveredFromCorruption(
    database: database,
    quarantinedFile: quarantined,
  );
}

/// Move the damaged database aside, sidecars included.
///
/// What must not happen is a `-wal` or `-shm` file being left beside the fresh
/// database: SQLite would replay the write-ahead log into it on the next open,
/// reintroducing the damage and producing a corruption loop that reads as the
/// recovery code being broken.
///
/// In practice SQLite deletes both sidecars itself when the failed connection
/// closes, so these renames usually find nothing to move. They are here for
/// the case where the close failed too, which is exactly when the file is in
/// the worst state and the loop would be hardest to diagnose.
///
/// Args:
///     file (File): The damaged database file.
///     clock (Clock): Supplies the date the target name is stamped with.
///
/// Returns:
///     File: Where the damaged file now lives. A counter is appended if a
///     file of that name already exists, so a second failure on the same day
///     cannot overwrite the first.
File _quarantine(File file, Clock clock) {
  final stamp = clock.today().toIso8601();
  var target = File('${file.path}.$quarantineSuffix-$stamp');
  var attempt = 1;
  while (target.existsSync()) {
    target = File('${file.path}.$quarantineSuffix-$stamp-$attempt');
    attempt++;
  }
  if (file.existsSync()) {
    file.renameSync(target.path);
  }
  for (final suffix in const <String>['-wal', '-shm']) {
    final sidecar = File('${file.path}$suffix');
    if (sidecar.existsSync()) {
      sidecar.renameSync('${target.path}$suffix');
    }
  }
  return target;
}
