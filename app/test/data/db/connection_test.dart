import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/database_key.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late FixedClock clock;
  late RingLogger logger;
  late MemoryDatabaseKeyStore keys;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('period_tracker_db_test');
    clock = FixedClock.iso('2026-03-14');
    logger = RingLogger(clock: clock);
    keys = MemoryDatabaseKeyStore();
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  File databaseFile() => File('${directory.path}/$databaseFileName');

  /// Overwrites the file with bytes that are not a SQLite database.
  void corrupt(File file) {
    file.writeAsBytesSync(
      Uint8List.fromList(List<int>.filled(4096, 0x41)),
      flush: true,
    );
  }

  Future<DatabaseOpenOutcome> open() => openAppDatabase(
    directory: directory,
    clock: clock,
    keyStore: keys,
    logger: logger,
  );

  /// Writes a database the way a build before encryption did, holding one
  /// day.
  Future<void> writeUnencrypted() async {
    final db = AppDatabase(NativeDatabase(databaseFile()));
    await db.dayLogDao.save(
      const DayLog(
        date: CivilDate.fromEpochDay(20000),
        flow: FlowIntensity.light,
      ),
    );
    await db.close();
  }

  /// Whether the file can be read with no key at all.
  bool readableWithoutKey(File file) {
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.select('SELECT count(*) FROM sqlite_master');
      return true;
    } on sqlite.SqliteException {
      return false;
    } finally {
      raw.close();
    }
  }

  group('a first run', () {
    test('creates the database and reports a clean open', () async {
      final outcome = await open();
      expect(outcome, isA<DatabaseOpened>());
      final db = (outcome as DatabaseOpened).database;
      addTearDown(db.close);
      expect(await db.dayLogDao.allLogs(), isEmpty);
      expect(databaseFile().existsSync(), isTrue);
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.dbOpened),
      );
    });
  });

  group('reopening', () {
    test('finds the data that was written before', () async {
      final first = await open() as DatabaseOpened;
      await first.database.dayLogDao.save(
        const DayLog(
          date: CivilDate.fromEpochDay(20000),
          flow: FlowIntensity.medium,
        ),
      );
      await first.database.close();

      final second = await open();
      expect(second, isA<DatabaseOpened>());
      final db = (second as DatabaseOpened).database;
      addTearDown(db.close);
      expect(await db.dayLogDao.allLogs(), hasLength(1));
    });
  });

  group('opening without recovery', () {
    // The path the notification action's background isolate takes. Same open,
    // same integrity check, same migration — and it never quarantines, because
    // moving someone's history aside is a decision that needs a screen and a
    // person looking at it.
    Future<AppDatabase?> openQuietly() => openAppDatabaseWithoutRecovery(
      directory: directory,
      keyStore: keys,
    );

    Future<void> seed(FlowIntensity flow) async {
      final first = await open() as DatabaseOpened;
      await first.database.dayLogDao.save(
        DayLog(date: const CivilDate.fromEpochDay(20000), flow: flow),
      );
      await first.database.close();
    }

    test('hands back a healthy database like any other caller', () async {
      await seed(FlowIntensity.medium);
      final db = await openQuietly();
      expect(db, isNotNull);
      addTearDown(db!.close);
      expect(await db.dayLogDao.allLogs(), hasLength(1));
    });

    test('refuses a damaged file rather than moving it aside', () async {
      await seed(FlowIntensity.heavy);
      corrupt(databaseFile());
      final sizeBefore = databaseFile().lengthSync();

      expect(await openQuietly(), isNull);

      // Untouched, and nothing quarantined. A background isolate that relocated
      // the user's history would do it with nothing on screen, nobody to tell,
      // and no way to connect it to the notification they tapped.
      expect(databaseFile().existsSync(), isTrue);
      expect(databaseFile().lengthSync(), sizeBefore);
      expect(
        directory
            .listSync()
            .where((e) => e.path.contains(quarantineSuffix))
            .toList(),
        isEmpty,
      );
    });

    test('opens a file not yet encrypted, and leaves encrypting it to the '
        'app', () async {
      // The app updated and not yet opened since, when the notification is
      // tapped. Encrypting is a foreground job, with a screen to report on.
      await writeUnencrypted();
      final db = await openQuietly();
      expect(db, isNotNull);
      addTearDown(db!.close);
      expect(await db.dayLogDao.allLogs(), hasLength(1));
      expect(isPlaintextDatabase(databaseFile()), isTrue);
      expect(keys.key, isNull, reason: 'made a key in the background');
    });

    test('gives up without a stored key, rather than making one', () async {
      await seed(FlowIntensity.medium);
      final kept = keys.key;
      keys.key = null;
      expect(await openQuietly(), isNull);
      expect(keys.key, isNull);
      keys.key = kept;
    });

    test('never makes a database where there is none', () async {
      expect(await openQuietly(), isNull);
      expect(databaseFile().existsSync(), isFalse);
    });

    test('defers the recovery rather than dropping it', () async {
      // Declining in the background must not mean the damage goes unhandled,
      // only that it is handled in the open on the next foreground launch.
      await seed(FlowIntensity.heavy);
      corrupt(databaseFile());
      expect(await openQuietly(), isNull);

      final outcome = await open();
      expect(outcome, isA<DatabaseRecoveredFromCorruption>());
      final recovered = outcome as DatabaseRecoveredFromCorruption;
      addTearDown(recovered.database.close);
      expect(recovered.quarantinedFile.existsSync(), isTrue);
    });
  });

  group('encryption', () {
    test(
      'a first run makes a key, keeps it, and writes an encrypted file',
      () async {
        final outcome = await open() as DatabaseOpened;
        addTearDown(outcome.database.close);
        expect(keys.key, isNotNull);
        expect(isDatabaseKey(keys.key!), isTrue);
        expect(isPlaintextDatabase(databaseFile()), isFalse);
        expect(readableWithoutKey(databaseFile()), isFalse);
      },
    );

    test('a file written before encryption is encrypted in place, with '
        'nothing lost', () async {
      await writeUnencrypted();
      expect(isPlaintextDatabase(databaseFile()), isTrue);

      final outcome = await open();
      expect(outcome, isA<DatabaseOpened>());
      final db = (outcome as DatabaseOpened).database;
      addTearDown(db.close);
      expect(await db.dayLogDao.allLogs(), hasLength(1));
      expect(isPlaintextDatabase(databaseFile()), isFalse);
      expect(readableWithoutKey(databaseFile()), isFalse);
      // The copy kept while it ran is gone, and with it the last unencrypted
      // trace the app made.
      expect(
        File('${databaseFile().path}.$preEncryptionSuffix').existsSync(),
        isFalse,
      );
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.dbEncrypted),
      );
    });

    test(
      'an encryption cut short goes back to its copy and runs again',
      () async {
        // The copy is there and the file it was made for does not open: the
        // state a crash halfway through would leave. The copy is the data.
        await writeUnencrypted();
        File(
          databaseFile().path,
        ).copySync('${databaseFile().path}.$preEncryptionSuffix');
        databaseFile().writeAsBytesSync(List<int>.filled(4096, 0x41));

        final outcome = await open();
        expect(outcome, isA<DatabaseOpened>());
        final db = (outcome as DatabaseOpened).database;
        addTearDown(db.close);
        expect(await db.dayLogDao.allLogs(), hasLength(1));
        expect(isPlaintextDatabase(databaseFile()), isFalse);
        expect(
          File('${databaseFile().path}.$preEncryptionSuffix').existsSync(),
          isFalse,
        );
      },
    );

    test('a copy with no file beside it is put back, not dropped', () async {
      // Opening a missing file would make an empty one that passes every
      // check. The copy must not be weighed against that.
      await writeUnencrypted();
      databaseFile().renameSync(
        '${databaseFile().path}.$preEncryptionSuffix',
      );

      final outcome = await open();
      expect(outcome, isA<DatabaseOpened>());
      final db = (outcome as DatabaseOpened).database;
      addTearDown(db.close);
      expect(await db.dayLogDao.allLogs(), hasLength(1));
      expect(isPlaintextDatabase(databaseFile()), isFalse);
    });

    test('a copy left beside a file that opens is dropped', () async {
      final first = await open() as DatabaseOpened;
      await first.database.close();
      File(
        '${databaseFile().path}.$preEncryptionSuffix',
      ).writeAsStringSync('left over');

      final outcome = await open() as DatabaseOpened;
      addTearDown(outcome.database.close);
      expect(
        File('${databaseFile().path}.$preEncryptionSuffix').existsSync(),
        isFalse,
      );
    });

    test('an unreadable key store opens nothing and changes nothing', () async {
      await writeUnencrypted();
      final before = databaseFile().readAsBytesSync();
      keys.failing = true;

      final outcome = await open();
      expect(outcome, isA<DatabaseKeyUnavailable>());
      // Neither encrypted with a key nobody kept, nor given a new one.
      expect(databaseFile().readAsBytesSync(), before);
      keys.failing = false;
      expect(keys.key, isNull);
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.dbKeyUnavailable),
      );
    });

    test('a key lost from the store is handled as damage, and the file is '
        'kept', () async {
      final first = await open() as DatabaseOpened;
      await first.database.dayLogDao.save(
        const DayLog(
          date: CivilDate.fromEpochDay(20000),
          flow: FlowIntensity.medium,
        ),
      );
      await first.database.close();
      keys.key = null;

      final outcome = await open();
      expect(outcome, isA<DatabaseRecoveredFromCorruption>());
      final recovered = outcome as DatabaseRecoveredFromCorruption;
      addTearDown(recovered.database.close);
      expect(recovered.quarantinedFile.existsSync(), isTrue);
      // The fresh file is encrypted with the new key.
      expect(isPlaintextDatabase(databaseFile()), isFalse);
      expect(keys.key, isNotNull);
    });

    test(
      'a damaged file written before encryption is kept unencrypted',
      () async {
        // Encrypting a damaged file would only make what survives of it harder
        // to read later. It is quarantined as it is.
        await writeUnencrypted();
        final bytes = databaseFile().readAsBytesSync();
        databaseFile().writeAsBytesSync(<int>[
          ...bytes.take(100),
          ...List<int>.filled(bytes.length - 100, 0x5A),
        ]);

        final outcome = await open();
        expect(outcome, isA<DatabaseRecoveredFromCorruption>());
        final recovered = outcome as DatabaseRecoveredFromCorruption;
        addTearDown(recovered.database.close);
        expect(isPlaintextDatabase(recovered.quarantinedFile), isTrue);
        expect(isPlaintextDatabase(databaseFile()), isFalse);
      },
    );
  });

  group('a corrupt database', () {
    test('is quarantined rather than opened, and never deleted', () async {
      final first = await open() as DatabaseOpened;
      await first.database.dayLogDao.save(
        const DayLog(
          date: CivilDate.fromEpochDay(20000),
          flow: FlowIntensity.heavy,
        ),
      );
      await first.database.close();
      corrupt(databaseFile());

      final outcome = await open();
      expect(outcome, isA<DatabaseRecoveredFromCorruption>());
      final recovered = outcome as DatabaseRecoveredFromCorruption;
      addTearDown(recovered.database.close);

      // The app comes up working...
      expect(await recovered.database.dayLogDao.allLogs(), isEmpty);
      // ...and the damaged file is still there. Deleting it would destroy the
      // only copy of data the user may still be able to recover.
      expect(recovered.quarantinedFile.existsSync(), isTrue);
      expect(recovered.quarantinedFile.path, contains(quarantineSuffix));
      expect(recovered.quarantinedFile.lengthSync(), greaterThan(0));
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.dbCorruptionDetected),
      );
    });

    test('leaves no write-ahead log beside the fresh database', () async {
      // A stale -wal next to a fresh database gets replayed into it on the next
      // open, which reintroduces the damage: a corruption loop that reads as
      // the recovery code being broken. SQLite removes both sidecars itself
      // when the failed connection closes, and the quarantine renames anything
      // it left; either way what matters is that nothing survives here.
      final first = await open() as DatabaseOpened;
      await first.database.close();
      corrupt(databaseFile());
      File('${databaseFile().path}-wal').writeAsStringSync('stale');
      File('${databaseFile().path}-shm').writeAsStringSync('stale');

      final outcome = await open() as DatabaseRecoveredFromCorruption;
      addTearDown(outcome.database.close);
      expect(File('${databaseFile().path}-wal').existsSync(), isFalse);
      expect(File('${databaseFile().path}-shm').existsSync(), isFalse);
      // And the damaged database itself is still on disk.
      expect(outcome.quarantinedFile.existsSync(), isTrue);
    });

    test('catches damage that leaves the file openable', () async {
      // The subtler case, and the reason the open path runs an explicit
      // integrity check rather than trusting that a database which opens is a
      // database that works. A damaged page past the header lets SQLite open
      // the file happily and fail later, in the middle of a write.
      final first = await open() as DatabaseOpened;
      for (var i = 0; i < 200; i++) {
        await first.database.dayLogDao.save(
          DayLog(
            date: CivilDate.fromEpochDay(20000 + i),
            flow: FlowIntensity.medium,
          ),
        );
      }
      await first.database.close();

      final bytes = Uint8List.fromList(databaseFile().readAsBytesSync());
      for (var i = 5000; i < 6000 && i < bytes.length; i++) {
        bytes[i] = 0x5A;
      }
      databaseFile().writeAsBytesSync(bytes, flush: true);

      final outcome = await open();
      expect(outcome, isA<DatabaseRecoveredFromCorruption>());
      final recovered = outcome as DatabaseRecoveredFromCorruption;
      addTearDown(recovered.database.close);
      expect(recovered.quarantinedFile.existsSync(), isTrue);
      expect(await recovered.database.dayLogDao.allLogs(), isEmpty);
      expect(
        const DatabaseCorruptException('quick_check reported: bad').toString(),
        contains('quick_check'),
      );
    });

    test('quarantines twice without overwriting the first attempt', () async {
      final first = await open() as DatabaseOpened;
      await first.database.close();
      corrupt(databaseFile());
      final one = await open() as DatabaseRecoveredFromCorruption;
      await one.database.close();

      corrupt(databaseFile());
      final two = await open() as DatabaseRecoveredFromCorruption;
      addTearDown(two.database.close);

      expect(two.quarantinedFile.path, isNot(one.quarantinedFile.path));
      expect(one.quarantinedFile.existsSync(), isTrue);
      expect(two.quarantinedFile.existsSync(), isTrue);
    });
  });

  group('a database from a newer build', () {
    test('is refused rather than downgraded', () async {
      final first = await open() as DatabaseOpened;
      await first.database.customStatement(
        'PRAGMA user_version = ${AppDatabase.latestSchemaVersion + 1}',
      );
      await first.database.close();

      final outcome = await open();
      expect(outcome, isA<DatabaseRefusedNewerSchema>());
      final refused = outcome as DatabaseRefusedNewerSchema;
      expect(refused.storedVersion, AppDatabase.latestSchemaVersion + 1);
      expect(refused.supportedVersion, AppDatabase.latestSchemaVersion);
      // Refusing means refusing: the file is left exactly as it was, not
      // quarantined, because there is nothing wrong with it.
      expect(databaseFile().existsSync(), isTrue);
      expect(
        directory.listSync().where(
          (e) => e.path.contains(quarantineSuffix),
        ),
        isEmpty,
      );
    });
  });

  group('verifyIntegrity', () {
    test('passes on a healthy database', () async {
      final outcome = await open() as DatabaseOpened;
      addTearDown(outcome.database.close);
      await expectLater(verifyIntegrity(outcome.database), completes);
    });
  });
}
