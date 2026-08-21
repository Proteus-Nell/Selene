import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/data/transfer/import_v1.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  final clock = FixedClock.iso('2026-06-30');
  late AppDatabase db;

  final sampleLog = DayLog(
    date: CivilDate.parseIso8601('2026-03-14'),
    flow: FlowIntensity.medium,
    symptoms: const <Symptom, SymptomSeverity>{
      Symptom.cramps: SymptomSeverity.moderate,
    },
  );

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A valid envelope as a mutable JSON tree, ready to be damaged.
  Future<Map<String, Object?>> validDocument() async {
    await db.dayLogDao.save(sampleLog);
    final text = ExportV1.encode(
      await ExportV1.build(database: db, clock: clock),
    );
    return jsonDecode(text)! as Map<String, Object?>;
  }

  Future<ImportRefused> refusalFor(Map<String, Object?> document) async {
    final result = ImportV1.inspect(jsonEncode(document));
    expect(result.isErr, isTrue, reason: 'expected a refusal');
    return result.errorOrNull!;
  }

  group('the export stamp', () {
    test('matches the version in pubspec.yaml', () {
      // The stamp is a constant so that exporting needs no platform plugin.
      // This is what stops it drifting from the real version, which would make
      // every "which build wrote this?" answer wrong.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
      expect(appVersion, match!.group(1));
    });

    test('records the database schema version too', () async {
      final envelope = await ExportV1.build(database: db, clock: clock);
      expect(envelope.databaseSchemaVersion, AppDatabase.latestSchemaVersion);
    });
  });

  group('the shape fingerprint', () {
    test('describes the fields actually written', () async {
      // Rebuilt from the real serialised keys, so changing the envelope, the
      // day-log shape or the condition shape without updating the constant
      // fails here rather than at a user's next restore.
      final envelope = await ExportV1.build(database: db, clock: clock);
      final envelopeKeys = envelope.toJson().keys.toList()..sort();
      final dayLogKeys = sampleLog.toJson().keys.toList()..sort();
      final conditionKeys = ConditionRecord(
        id: 0,
        condition: Condition.pcos,
        start: CivilDate.parseIso8601('2026-01-01'),
      ).toJson().keys.toList()..sort();
      expect(
        exportSchemaFingerprint,
        'v$exportSchemaVersion;envelope[${envelopeKeys.join(",")}];'
        'day_log[${dayLogKeys.join(",")}];'
        'condition[${conditionKeys.join(",")}]',
      );
    });

    test('deliberately does not cover the enum members', () {
      // If it did, adding one symptom in a later release would invalidate every
      // backup any user had ever taken.
      for (final symptom in Symptom.values) {
        expect(exportSchemaFingerprint, isNot(contains(symptom.name)));
      }
    });
  });

  group('writing a file', () {
    test('writes only where it is told', () async {
      final directory = Directory.systemTemp.createTempSync('export_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      await db.dayLogDao.save(sampleLog);

      final destination = File('${directory.path}/backup.json');
      final logger = RingLogger(clock: clock);
      final envelope = await ExportV1.writeTo(
        destination,
        database: db,
        clock: clock,
        logger: logger,
      );

      expect(destination.existsSync(), isTrue);
      expect(envelope.dayLogs, hasLength(1));
      expect(directory.listSync(), hasLength(1));
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.exportWritten),
      );
      // The log line records counts, never content.
      expect(logger.dump(), isNot(contains('2026-03-14')));
      expect(logger.dump(), isNot(contains('cramps')));
    });

    test('suggests a filename that gives nothing away', () {
      final name = ExportV1.suggestedFileName(clock);
      expect(name, 'period-tracker-export-2026-06-30.json');
      expect(name, isNot(contains('period-days')));
      expect(name, isNot(contains('symptom')));
    });

    test('round trips through a real file', () async {
      final directory = Directory.systemTemp.createTempSync('export_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      await db.dayLogDao.save(sampleLog);
      final destination = File('${directory.path}/backup.json');
      await ExportV1.writeTo(destination, database: db, clock: clock);

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      final result = await ImportV1.restoreFile(destination, database: target);
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await target.dayLogDao.allLogs(), <DayLog>[sampleLog]);
      expect(result.valueOrNull!.writtenByAppVersion, appVersion);
      expect(result.valueOrNull!.dayLogsRestored, 1);
    });

    test('reports a file it cannot read rather than throwing', () async {
      final missing = File('${Directory.systemTemp.path}/does-not-exist.json');
      final result = await ImportV1.restoreFile(missing, database: db);
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.rejection, ImportRejection.notJson);
    });
  });

  group('import refuses', () {
    test('a file from a newer app version, and says to update', () async {
      final document = await validDocument()
        ..['schema_version'] = exportSchemaVersion + 1;
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.writtenByNewerVersion);
      expect(refusal.message, contains('newer version'));
      expect(refusal.message, contains('Update the app'));
      expect(refusal.message, contains('Nothing has been changed'));
    });

    test('a file whose shape does not match the version it claims', () async {
      final document = await validDocument()
        ..['schema_fingerprint'] = 'v1;envelope[something,else];day_log[x]';
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.unexpectedShape);
    });

    test('text that is not JSON', () async {
      final result = ImportV1.inspect('not json at all');
      expect(result.errorOrNull!.rejection, ImportRejection.notJson);
    });

    test('JSON that is not an envelope', () async {
      expect(
        ImportV1.inspect('[1, 2, 3]').errorOrNull!.rejection,
        ImportRejection.notAnEnvelope,
      );
      expect(
        ImportV1.inspect('{"hello": "world"}').errorOrNull!.rejection,
        ImportRejection.malformedField,
      );
    });

    test('a missing required field', () async {
      final document = await validDocument()
        ..remove('app_version');
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.malformedField);
      expect(refusal.message, contains('app_version'));
    });

    test('an unreadable export date', () async {
      final document = await validDocument()
        ..['exported_utc'] = 'the fourteenth of March';
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.malformedField,
      );
    });

    test('a symptom this build does not know', () async {
      // The realistic forward-compatibility case: a backup written after a
      // release that added a symptom.
      //
      // The placeholder is deliberately not a plausible symptom. This test used
      // 'nausea' until AND-23 added nausea to the catalogue, at which point it
      // started asserting that a perfectly valid export was refused — a test
      // that fails for the opposite of its reason. A name no release will ever
      // claim cannot be overtaken the same way.
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['symptoms'] = <String, Object?>{
        'symptomFromAFutureRelease': 'severe',
      };
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.unknownValue);
      // Naming the value is the difference between retrying and giving up.
      expect(refusal.message, contains('symptomFromAFutureRelease'));
      expect(refusal.message, contains('newer version'));
    });

    test('a flow level this build does not know', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['flow'] = 'torrential';
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.unknownValue);
      expect(refusal.message, contains('torrential'));
    });

    test('a date that is not a real calendar day', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['date'] = '2026-02-30';
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.invalidDate);
      expect(refusal.message, contains('2026-02-30'));
    });

    test('a date in the wrong format', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['date'] = '14/03/2026';
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.invalidDate,
      );
    });

    test('the same date twice', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      logs.add(Map<String, Object?>.from(logs.first! as Map<String, Object?>));
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.duplicateDate);
      expect(refusal.message, contains('2026-03-14'));
    });

    test('an envelope version this build no longer reads', () async {
      final document = await validDocument()
        ..['schema_version'] = 0;
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.unsupportedVersion);
    });

    test('a day-log entry that is not an object', () async {
      final document = await validDocument();
      (document['day_logs']! as List<Object?>).add('not an entry');
      final refusal = await refusalFor(document);
      expect(refusal.rejection, ImportRejection.malformedField);
      expect(refusal.message, contains('Entry 2'));
    });

    test('a day-log entry with no date', () async {
      final document = await validDocument();
      (document['day_logs']! as List<Object?>).first = <String, Object?>{
        'flow': 'light',
      };
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.malformedField,
      );
    });

    test('a symptoms field that is not a map', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['symptoms'] = 'cramps';
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.malformedField,
      );
    });

    test('a severity that is not text', () async {
      final document = await validDocument();
      final logs = document['day_logs']! as List<Object?>;
      (logs.first! as Map<String, Object?>)['symptoms'] = <String, Object?>{
        'cramps': 3,
      };
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.malformedField,
      );
    });

    test('a settings value that is not text', () async {
      final document = await validDocument()
        ..['settings'] = <String, Object?>{'reminder_enabled': 42};
      expect(
        (await refusalFor(document)).rejection,
        ImportRejection.malformedField,
      );
    });
  });

  group('a refused import', () {
    test('leaves the database exactly as it was', () async {
      // The whole point of validating before writing: a file that fails on its
      // last entry must not have applied the first.
      await db.dayLogDao.save(sampleLog);
      final before = await db.dayLogDao.allLogs();

      final document = await validDocument();
      // One good entry followed by a bad one, so that a naive importer would
      // have written the good one before noticing.
      (document['day_logs']! as List<Object?>)
        ..add(<String, Object?>{
          'date': '2026-04-01',
          'flow': 'light',
          'symptoms': <String, Object?>{},
        })
        ..add(<String, Object?>{
          'date': '2026-04-02',
          'flow': 'not a flow',
          'symptoms': <String, Object?>{},
        });

      final logger = RingLogger(clock: clock);
      final result = await ImportV1.restore(
        jsonEncode(document),
        database: db,
        logger: logger,
      );
      expect(result.isErr, isTrue);
      expect(await db.dayLogDao.allLogs(), before);
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.importRejected),
      );
    });
  });

  group('a successful import', () {
    test('replaces rather than merges', () async {
      // A backup is a snapshot of the whole diary. Merging would resurrect days
      // the user had deleted, and there is no way for a snapshot to say "this
      // day is gone".
      await db.dayLogDao.save(sampleLog);
      final text = ExportV1.encode(
        await ExportV1.build(database: db, clock: clock),
      );

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await target.dayLogDao.save(
        DayLog(
          date: CivilDate.parseIso8601('2025-01-01'),
          flow: FlowIntensity.heavy,
        ),
      );

      expect((await ImportV1.restore(text, database: target)).isOk, isTrue);
      expect(await target.dayLogDao.allLogs(), <DayLog>[sampleLog]);
    });

    test('drops the cached prediction, which described the old data', () async {
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await target.modelStateDao.store(
        const ModelStateRow(
          id: 0,
          inputSignature: 'stale',
          stateMean: 3.3,
          stateVariance: 0.01,
          stateObservations: 4,
          obsSd: 0.05,
          driftSd: 0.01,
          personalised: false,
          medianDays: 29,
          lo50: 27,
          hi50: 31,
          lo80: 25,
          hi80: 33,
          confidence: 'low',
        ),
      );
      await db.dayLogDao.save(sampleLog);
      final text = ExportV1.encode(
        await ExportV1.build(database: db, clock: clock),
      );

      expect((await ImportV1.restore(text, database: target)).isOk, isTrue);
      expect(await target.modelStateDao.current(), isNull);
    });

    test('reports what it restored, and logs counts only', () async {
      await db.dayLogDao.save(sampleLog);
      await db.settingsDao.writeRaw('reminder_enabled', 'true');
      final text = ExportV1.encode(
        await ExportV1.build(database: db, clock: clock),
      );

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      final logger = RingLogger(clock: clock);
      final summary = (await ImportV1.restore(
        text,
        database: target,
        logger: logger,
      )).valueOrNull!;
      expect(
        logger.records.map((r) => r.event),
        contains(LogEvent.importCompleted),
      );
      expect(logger.dump(), isNot(contains('2026-03-14')));
      expect(summary.dayLogsRestored, 1);
      // Counted against what was actually exported rather than a literal. The
      // source database carries the export-format acknowledgement seeded at
      // onCreate as well as the setting written above, and a hard-coded 1 was
      // a shorthand for "the one I wrote" that stopped being true the moment
      // anything else was seeded.
      expect(summary.settingsRestored, (await db.settingsDao.allRaw()).length);
      expect(await target.settingsDao.raw(SettingKey.reminderEnabled), 'true');
      expect(summary.exportedUtc.toIso8601String(), startsWith('2026-06-30'));
      expect(summary.toString(), contains('1 logs'));
    });

    test('keeps a setting this build has never heard of', () async {
      final document = await validDocument()
        ..['settings'] = <String, Object?>{'a_future_setting': '42'};
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      expect(
        (await ImportV1.restore(jsonEncode(document), database: target)).isOk,
        isTrue,
      );
      expect(await target.settingsDao.allRaw(), <String, String>{
        'a_future_setting': '42',
      });
    });
  });

  group('value types', () {
    test('refusals and envelopes compare by value', () async {
      const a = ImportRefused(ImportRejection.duplicateDate, 'msg');
      expect(a, const ImportRefused(ImportRejection.duplicateDate, 'msg'));
      expect(
        a.hashCode,
        const ImportRefused(
          ImportRejection.duplicateDate,
          'msg',
        ).hashCode,
      );
      expect(a.toString(), contains('duplicateDate'));

      final envelope = await ExportV1.build(database: db, clock: clock);
      final same = await ExportV1.build(database: db, clock: clock);
      expect(envelope, same);
      expect(envelope.hashCode, same.hashCode);
      expect(envelope.toString(), contains('0 logs'));

      await db.dayLogDao.save(sampleLog);
      final withALog = await ExportV1.build(database: db, clock: clock);
      expect(withALog, isNot(envelope));
      await db.settingsDao.writeRaw('reminder_enabled', 'true');
      final withASetting = await ExportV1.build(database: db, clock: clock);
      expect(withASetting, isNot(withALog));
      // Same counts, different contents: the comparison has to look at values,
      // not just lengths, or a round-trip test could pass while losing data.
      await db.settingsDao.replaceAll(const <String, String>{
        'reminder_enabled': 'false',
      });
      expect(
        await ExportV1.build(database: db, clock: clock),
        isNot(withASetting),
      );
      await db.dayLogDao.save(
        sampleLog.copyWith(flow: FlowIntensity.heavy),
      );
      expect(
        (await ExportV1.build(database: db, clock: clock)).dayLogs,
        isNot(withALog.dayLogs),
      );
    });
  });
}
