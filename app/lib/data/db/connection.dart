/// Database connection and recovery.
///
/// The single place the app opens its database file. Unlocks it with the key
/// the Keystore holds, encrypts a file written before encryption, verifies the
/// file before handing it over, quarantines a damaged one rather than deleting
/// it, and refuses a file written by a newer build.
///
/// Pipeline:
///     1. Read the key, or make and store one if there is none.
///     2. Encrypt the file in place if it was written before encryption,
///        keeping a copy until the encrypted file is proven (ADR-0018).
///     3. Open the file with the key and run `PRAGMA quick_check`.
///     4. Let the migration run.
///     5. On a newer schema, refuse and return no database at all.
///     6. On damage, move the file aside with its sidecars and open a fresh
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
import 'package:period_tracker/data/db/database_key.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Name of the database file inside the app's private directory.
const String databaseFileName = 'period_tracker.sqlite';

/// Suffix given to a database file that failed its integrity check.
const String quarantineSuffix = 'corrupt';

/// Suffix of the copy kept while a file written before encryption is
/// encrypted. It exists only for the moment the encryption runs, and is
/// restored from if that was interrupted.
const String preEncryptionSuffix = 'pre-encryption';

/// The first 16 bytes of every unencrypted SQLite file.
const String _plaintextHeader = 'SQLite format 3\u0000';

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

/// Database key unavailable: the key store could not be read.
///
/// No database is returned. The key may still be in the store, and opening
/// without it would mean making a new one, after which the existing file could
/// never be opened again. Nothing is written, and the next launch tries again.
final class DatabaseKeyUnavailable extends DatabaseOpenOutcome {
  /// Creates the outcome.
  const DatabaseKeyUnavailable();
}

/// **The single [QueryExecutor] construction site.**
///
/// ADR-0004 asked for this to stay true so that adopting encryption would be a
/// change to this function plus a one-time re-encrypt migration, rather than an
/// audit of every call site, and ADR-0018 is that change: every connection the
/// production app makes is created here, and unlocked here. The library is
/// SQLite3 Multiple Ciphers, selected in `pubspec.yaml`, with the ChaCha20
/// cipher named explicitly so a change of its default could not lock an
/// existing file. Tests construct `NativeDatabase.memory()` directly, which is
/// deliberate and does not weaken the guarantee: the point is that no
/// *shipped* code path opens a database any other way.
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
///     key (String?): The key, from [newDatabaseKey]. Null opens the file
///         unencrypted, which only the background isolate does, and only for
///         a file the foreground has not encrypted yet.
///
/// Returns:
///     QueryExecutor: An executor running on the calling isolate.
QueryExecutor createQueryExecutor(File file, {required String? key}) =>
    NativeDatabase(
      file,
      setup: key == null ? null : (database) => _unlock(database, key),
    );

/// Give a connection its key, before anything reads the file.
///
/// Args:
///     database (sqlite.Database): The raw connection.
///     key (String): The key. Refused unless it is the shape
///         [newDatabaseKey] makes, because a pragma cannot take a bound
///         parameter and nothing else may reach the SQL.
void _unlock(sqlite.Database database, String key) {
  _requireKeyShape(key);
  database
    ..execute("PRAGMA cipher = 'chacha20'")
    ..execute("PRAGMA hexkey = '$key'");
}

/// Refuse a key that is not the shape [newDatabaseKey] makes.
///
/// A pragma cannot take a bound parameter, so the key is spliced into the SQL,
/// and this is what keeps anything but hex digits out of it.
///
/// Throws:
///     ArgumentError: For any other string. The key is not in the message.
void _requireKeyShape(String key) {
  if (!isDatabaseKey(key)) {
    throw ArgumentError.value('<redacted>', 'key', 'is not a database key');
  }
}

/// Whether [file] is an SQLite database written before encryption.
///
/// Args:
///     file (File): The database file.
///
/// Returns:
///     bool: True when the file starts with SQLite's plain header. False for
///     an encrypted file, whose first bytes are random, and for no file.
bool isPlaintextDatabase(File file) {
  if (!file.existsSync()) return false;
  final handle = file.openSync();
  try {
    final head = handle.readSync(_plaintextHeader.length);
    return String.fromCharCodes(head) == _plaintextHeader;
  } finally {
    handle.closeSync();
  }
}

/// Encrypt a database written before encryption, in place.
///
/// `PRAGMA hexrekey` rewrites every page inside one transaction, so SQLite's
/// journal already makes it all or nothing. The copy is a second line, for a
/// failure the journal cannot see, such as a file the rekey reports done that
/// then fails to open: it is kept until the encrypted file has opened with the
/// key and passed `quick_check`, and restored if it does not. A file that is
/// already damaged is left as it is, for the ordinary quarantine to keep.
///
/// Args:
///     file (File): The unencrypted database file.
///     key (String): The key to encrypt it with.
///     logger (RingLogger?): Records that it happened.
///
/// Throws:
///     SqliteException: If the encrypted file does not open, after the
///         unencrypted one has been put back.
void _encryptInPlace(File file, String key, RingLogger? logger) {
  _requireKeyShape(key);
  final copy = File('${file.path}.$preEncryptionSuffix');
  final plain = sqlite.sqlite3.open(file.path);
  try {
    final check = plain.select('PRAGMA quick_check');
    if (check.isEmpty || check.first.values.first != 'ok') return;
    file.copySync(copy.path);
    plain
      ..execute("PRAGMA cipher = 'chacha20'")
      ..execute("PRAGMA hexrekey = '$key'");
  } finally {
    plain.close();
  }
  _finishEncryption(file, key);
  logger?.info(LogEvent.dbEncrypted);
}

/// Prove an encrypted file opens, then drop the copy kept while it was made.
///
/// Also what a launch does on finding a copy left by an encryption that was
/// interrupted: if the file opens with the key, the copy is no longer needed;
/// if it does not, the copy is the user's data, and it goes back.
///
/// Args:
///     file (File): The database file.
///     key (String): The key it should open with.
///
/// Throws:
///     SqliteException: If the file does not open with the key, after the
///         copy has been put back.
void _finishEncryption(File file, String key) {
  final copy = File('${file.path}.$preEncryptionSuffix');
  if (!copy.existsSync()) return;
  if (!file.existsSync()) {
    // Opening a file that is not there would make an empty one, which would
    // pass its check and take the copy with it. The copy is the data.
    copy.renameSync(file.path);
    return;
  }
  try {
    final encrypted = sqlite.sqlite3.open(file.path);
    try {
      _unlock(encrypted, key);
      final check = encrypted.select('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw sqlite.SqliteException(
          extendedResultCode: 11,
          message: 'the encrypted copy failed quick_check',
        );
      }
    } finally {
      encrypted.close();
    }
  } on sqlite.SqliteException {
    for (final suffix in const <String>['-journal', '-wal', '-shm']) {
      final sidecar = File('${file.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
    copy.renameSync(file.path);
    rethrow;
  }
  copy.deleteSync();
}

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
///     key (String?): The key it opens with, or null for a file not yet
///         encrypted.
///
/// Returns:
///     `Future<AppDatabase>`: The opened, verified database.
///
/// Throws:
///     DatabaseCorruptException: If `quick_check` reports damage.
///     DatabaseDowngradeException: If the file is from a newer build.
///     SqliteException: If the file cannot be opened at all.
Future<AppDatabase> _attemptOpen(File file, {required String? key}) async {
  final database = AppDatabase(createQueryExecutor(file, key: key));
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
/// For the same reason it never makes a key and never encrypts. A file not
/// yet encrypted, because the app has not been opened since the update that
/// encrypts it, is opened as it is. An encrypted one needs the stored key, and
/// without one the day goes unlogged rather than this isolate making a key the
/// file was never encrypted with.
///
/// Args:
///     directory (Directory): Where the database file lives.
///     keyStore (DatabaseKeyStore): Where the key is kept.
///
/// Returns:
///     `Future<AppDatabase?>`: The database, or null on any failure at all.
Future<AppDatabase?> openAppDatabaseWithoutRecovery({
  required Directory directory,
  required DatabaseKeyStore keyStore,
}) async {
  try {
    final file = File(p.join(directory.path, databaseFileName));
    if (isPlaintextDatabase(file)) return await _attemptOpen(file, key: null);
    if (!file.existsSync()) return null;
    final key = await keyStore.read();
    if (key == null) return null;
    return await _attemptOpen(file, key: key);
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
/// A file written before encryption is encrypted first (ADR-0018). A key
/// lost from the store, which leaves an encrypted file nothing can open, looks
/// like damage and is handled as damage: the file is kept aside and the user
/// is offered their last export.
///
/// Args:
///     directory (Directory): Where the database file lives.
///     clock (Clock): Stamps the quarantined file's name.
///     keyStore (DatabaseKeyStore): Where the key is kept.
///     logger (RingLogger?, optional): Records the outcome. Defaults to null.
///
/// Returns:
///     `Future<DatabaseOpenOutcome>`: One of the four outcomes. Never
///     throws for a damaged or newer file, or an unreadable key store; each
///     is an outcome the UI renders.
Future<DatabaseOpenOutcome> openAppDatabase({
  required Directory directory,
  required Clock clock,
  required DatabaseKeyStore keyStore,
  RingLogger? logger,
}) async {
  final file = File(p.join(directory.path, databaseFileName));

  final String key;
  try {
    final stored = await keyStore.read();
    if (stored != null) {
      key = stored;
    } else {
      key = newDatabaseKey();
      await keyStore.write(key);
    }
  } on DatabaseKeyUnavailableException {
    logger?.error(LogEvent.dbKeyUnavailable);
    return const DatabaseKeyUnavailable();
  }

  // Two steps, each on its own. A copy left by an encryption that was cut
  // short goes back if the file does not open with the key, and the copy that
  // goes back is unencrypted, so the second step then encrypts it again.
  try {
    _finishEncryption(file, key);
  } on sqlite.SqliteException {
    // Restored. Encrypted below.
  } on FileSystemException {
    // Left as it was, for the next launch to finish.
  }
  try {
    if (isPlaintextDatabase(file)) _encryptInPlace(file, key, logger);
  } on sqlite.SqliteException {
    // Put back unencrypted, and opened that way below.
  } on FileSystemException {
    // A full disk, say. Opened unencrypted below.
  }

  // Whatever is still unencrypted now, because it was already damaged or the
  // encryption could not run, is opened unencrypted rather than with a key it
  // could never open with: a healthy file goes on working and is encrypted on
  // a later launch, and a damaged one is quarantined as damage, not as a
  // wrong key. Asked on every attempt, so that the fresh file a quarantine
  // leaves room for is made encrypted.
  Future<AppDatabase> attempt() =>
      _attemptOpen(file, key: isPlaintextDatabase(file) ? null : key);

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
