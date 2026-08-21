import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

CivilDate day(int epochDay) => CivilDate.fromEpochDay(epochDay);

DayLog logAt(
  int epochDay, {
  FlowIntensity flow = FlowIntensity.medium,
  Map<Symptom, SymptomSeverity> symptoms = const <Symptom, SymptomSeverity>{},
}) => DayLog(date: day(epochDay), flow: flow, symptoms: symptoms);

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory, so the whole suite runs on a desktop VM with no emulator and
    // no file system state leaking between tests.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('round trip', () {
    test('stores and reads back a day log with symptoms', () async {
      final log = logAt(
        20000,
        flow: FlowIntensity.heavy,
        symptoms: const <Symptom, SymptomSeverity>{
          Symptom.cramps: SymptomSeverity.severe,
          Symptom.mood: SymptomSeverity.mild,
        },
      );
      await db.dayLogDao.save(log);
      expect(await db.dayLogDao.logFor(day(20000)), log);
      expect(await db.dayLogDao.allLogs(), <DayLog>[log]);
    });

    test('returns logs oldest first regardless of insertion order', () async {
      await db.dayLogDao.save(logAt(20005));
      await db.dayLogDao.save(logAt(20001));
      await db.dayLogDao.save(logAt(20003));
      expect(
        (await db.dayLogDao.allLogs()).map((l) => l.date.epochDay).toList(),
        <int>[20001, 20003, 20005],
      );
    });

    test('a day with no symptoms round trips as an empty map', () async {
      await db.dayLogDao.save(logAt(20000, flow: FlowIntensity.spotting));
      final read = await db.dayLogDao.logFor(day(20000));
      expect(read!.symptoms, isEmpty);
      expect(read.flow, FlowIntensity.spotting);
    });

    test('a severity of none is not stored', () async {
      // Otherwise "recorded as absent" and "never asked" become
      // indistinguishable on the way back out.
      await db.dayLogDao.save(
        logAt(
          20000,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.none,
            Symptom.headache: SymptomSeverity.moderate,
          },
        ),
      );
      final read = await db.dayLogDao.logFor(day(20000));
      expect(read!.symptoms, <Symptom, SymptomSeverity>{
        Symptom.headache: SymptomSeverity.moderate,
      });
    });

    test('reports null for a day that was never logged', () async {
      expect(await db.dayLogDao.logFor(day(12345)), isNull);
    });
  });

  group('editing', () {
    test('replaces the previous entry for the same day', () async {
      await db.dayLogDao.save(
        logAt(
          20000,
          flow: FlowIntensity.heavy,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.severe,
          },
        ),
      );
      await db.dayLogDao.save(logAt(20000, flow: FlowIntensity.light));
      final logs = await db.dayLogDao.allLogs();
      expect(logs, hasLength(1));
      expect(logs.single.flow, FlowIntensity.light);
      // The old symptom must not survive the edit.
      expect(logs.single.symptoms, isEmpty);
    });

    test('the day is the primary key, so a duplicate cannot exist', () async {
      await db.dayLogDao.save(logAt(20000));
      await db.dayLogDao.save(logAt(20000));
      expect(await db.dayLogDao.allLogs(), hasLength(1));
    });
  });

  group('deletion', () {
    test('removes the day and its symptoms through the cascade', () async {
      await db.dayLogDao.save(
        logAt(
          20000,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.severe,
          },
        ),
      );
      expect(await db.dayLogDao.deleteDay(day(20000)), isTrue);
      expect(await db.dayLogDao.allLogs(), isEmpty);
      // Straight at the table: an orphaned symptom row would be health data
      // surviving a deletion the user believed was complete.
      final orphans = await db.select(db.symptoms).get();
      expect(orphans, isEmpty);
    });

    test('reports when there was nothing to delete', () async {
      expect(await db.dayLogDao.deleteDay(day(20000)), isFalse);
    });

    test('deleteEverything empties every table', () async {
      await db.dayLogDao.save(
        logAt(
          20000,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.mood: SymptomSeverity.mild,
          },
        ),
      );
      await db.settingsDao.writeBool(
        SettingKey.onboardingComplete,
        value: true,
      );
      await db.conditionDao.add(
        condition: Condition.pregnancy,
        start: day(20000),
      );

      await db.dayLogDao.deleteEverything();

      expect(await db.dayLogDao.allLogs(), isEmpty);
      expect(await db.select(db.symptoms).get(), isEmpty);
      expect(await db.select(db.modelStates).get(), isEmpty);
      // Conditions are the most sensitive rows in this database — a recorded
      // pregnancy, a PCOS diagnosis. Nothing references them, so no cascade
      // would ever have removed them, and leaving them would make "delete
      // everything" a lie about exactly the data a user is most likely to be
      // deleting for.
      expect(await db.select(db.conditions).get(), isEmpty);
      expect(
        await db.settingsDao.readBool(
          SettingKey.onboardingComplete,
          orElse: false,
        ),
        isFalse,
      );
    });

    test('deleteEverything leaves a database that looks freshly created', () {
      // Not literally empty: the export-format acknowledgement is re-seeded,
      // because a wiped database is in the same position as a new one. Without
      // it, deleting everything brings back a banner urging the user to back up
      // the data they have just deliberately destroyed.
      return expectLater(
        db.dayLogDao.deleteEverything().then(
          (_) => db.settingsDao.needsReExportPrompt(),
        ),
        completion(isFalse),
        reason:
            'wiping the database resurrected the re-export prompt, which now '
            'asks the user to back up nothing',
      );
    });
  });

  group('existingDates', () {
    test('reports only the dates already present', () async {
      await db.dayLogDao.save(logAt(20000));
      await db.dayLogDao.save(logAt(20002));
      expect(
        await db.dayLogDao.existingDates(<CivilDate>[
          day(20000),
          day(20001),
          day(20002),
        ]),
        <CivilDate>{day(20000), day(20002)},
      );
    });

    test('is empty for an empty query', () async {
      expect(await db.dayLogDao.existingDates(const <CivilDate>[]), isEmpty);
    });
  });

  group('watchAllLogs', () {
    test('re-emits when a symptom changes, not just a flow', () async {
      final emissions = <List<DayLog>>[];
      final sub = db.dayLogDao.watchAllLogs().listen(emissions.add);
      await db.dayLogDao.save(logAt(20000));
      await pumpEventQueue();
      await db.dayLogDao.save(
        logAt(
          20000,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.sleep: SymptomSeverity.moderate,
          },
        ),
      );
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions.last.single.symptoms, isNotEmpty);
    });
  });
}
