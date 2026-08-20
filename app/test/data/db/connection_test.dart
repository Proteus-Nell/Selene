import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  late Directory directory;
  late FixedClock clock;
  late RingLogger logger;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('period_tracker_db_test');
    clock = FixedClock.iso('2026-03-14');
    logger = RingLogger(clock: clock);
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  File databaseFile() => File('${directory.path}/$databaseFileName');

  Future<DatabaseOpenOutcome> open() =>
      openAppDatabase(directory: directory, clock: clock, logger: logger);

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

  group('a corrupt database', () {
    /// Overwrites the file with bytes that are not a SQLite database.
    void corrupt(File file) {
      file.writeAsBytesSync(
        Uint8List.fromList(List<int>.filled(4096, 0x41)),
        flush: true,
      );
    }

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
