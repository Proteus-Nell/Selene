import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repo;
  final today = CivilDate.parseIso8601('2026-06-30');

  CivilDate at(String iso) => CivilDate.parseIso8601(iso);
  DayLog bleeding(String iso, [FlowIntensity flow = FlowIntensity.medium]) =>
      DayLog(date: at(iso), flow: flow);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CycleRepository(database: db, clock: FixedClock(today));
  });

  tearDown(() => db.close());

  group('add', () {
    test('stores a new day', () async {
      final result = await repo.add(bleeding('2026-06-01'));
      expect(result.isOk, isTrue);
      expect(await repo.logs(), hasLength(1));
    });

    test('refuses a day that is already logged, and says which', () async {
      await repo.add(bleeding('2026-06-01'));
      final result = await repo.add(
        bleeding('2026-06-01', FlowIntensity.light),
      );
      expect(result.isErr, isTrue);
      final refusal = result.errorOrNull!;
      expect(refusal.rejection, WriteRejection.dayAlreadyLogged);
      expect(refusal.dates, <CivilDate>[at('2026-06-01')]);
      // "with a specific message" (docs/PLAN.md 5.5): the message has to name
      // the day, or the UI can only say that something went wrong.
      expect(refusal.message, contains('2026-06-01'));
      // And nothing was silently merged.
      expect((await repo.logs()).single.flow, FlowIntensity.medium);
    });

    test('refuses a future date', () async {
      final result = await repo.add(bleeding('2026-07-01'));
      expect(result.errorOrNull!.rejection, WriteRejection.dateInFuture);
      expect(result.errorOrNull!.message, contains('2026-07-01'));
      expect(await repo.logs(), isEmpty);
    });

    test('accepts today', () async {
      expect((await repo.add(bleeding('2026-06-30'))).isOk, isTrue);
    });
  });

  group('replace', () {
    test('edits an existing day', () async {
      await repo.add(bleeding('2026-06-01'));
      final result = await repo.replace(
        bleeding('2026-06-01', FlowIntensity.heavy),
      );
      expect(result.isOk, isTrue);
      expect((await repo.logs()).single.flow, FlowIntensity.heavy);
    });

    test('refuses a day that has no entry', () async {
      final result = await repo.replace(bleeding('2026-06-01'));
      expect(result.errorOrNull!.rejection, WriteRejection.dayNotLogged);
    });

    test('refuses a future date before checking anything else', () async {
      final result = await repo.replace(bleeding('2026-07-15'));
      expect(result.errorOrNull!.rejection, WriteRejection.dateInFuture);
    });
  });

  group('logFor', () {
    test('reads back a single day', () async {
      await repo.add(bleeding('2026-06-01', FlowIntensity.light));
      expect((await repo.logFor(at('2026-06-01')))!.flow, FlowIntensity.light);
      expect(await repo.logFor(at('2026-06-02')), isNull);
    });
  });

  group('upsert', () {
    test('creates or edits without caring which', () async {
      expect((await repo.upsert(bleeding('2026-06-01'))).isOk, isTrue);
      expect(
        (await repo.upsert(bleeding('2026-06-01', FlowIntensity.light))).isOk,
        isTrue,
      );
      expect((await repo.logs()).single.flow, FlowIntensity.light);
    });

    test('still refuses a future date', () async {
      expect(
        (await repo.upsert(bleeding('2026-12-01'))).errorOrNull!.rejection,
        WriteRejection.dateInFuture,
      );
    });
  });

  group('markPeriodStart', () {
    test('keeps symptoms already recorded for that day', () async {
      // The one-tap paths know the flow and nothing else. Writing a bare DayLog
      // for them replaces the whole day, symptoms included — so someone who
      // logged cramps in the morning and taps "period started" in the afternoon
      // would lose the cramps, with nothing on screen to say so.
      await repo.upsert(
        DayLog(
          date: at('2026-06-01'),
          flow: FlowIntensity.spotting,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.severe,
            Symptom.headache: SymptomSeverity.mild,
          },
        ),
      );

      expect((await repo.markPeriodStart(at('2026-06-01'))).isOk, isTrue);

      final stored = (await repo.logs()).single;
      expect(stored.flow, FlowIntensity.medium);
      expect(stored.severityOf(Symptom.cramps), SymptomSeverity.severe);
      expect(stored.severityOf(Symptom.headache), SymptomSeverity.mild);
    });

    test('creates the day when there is nothing there yet', () async {
      expect((await repo.markPeriodStart(at('2026-06-02'))).isOk, isTrue);
      final stored = (await repo.logs()).single;
      expect(stored.date, at('2026-06-02'));
      expect(stored.isBleedingDay, isTrue);
      expect(stored.symptoms, isEmpty);
    });

    test('still refuses a future date', () async {
      expect(
        (await repo.markPeriodStart(at('2026-12-01'))).errorOrNull!.rejection,
        WriteRejection.dateInFuture,
      );
    });
  });

  group('addAll', () {
    test('writes a whole batch', () async {
      final result = await repo.addAll(<DayLog>[
        bleeding('2026-06-01'),
        bleeding('2026-06-02'),
        bleeding('2026-06-03'),
      ]);
      expect(result.isOk, isTrue);
      expect(await repo.logs(), hasLength(3));
    });

    test('refuses a batch containing the same day twice', () async {
      final result = await repo.addAll(<DayLog>[
        bleeding('2026-06-01'),
        bleeding('2026-06-01', FlowIntensity.heavy),
      ]);
      expect(result.errorOrNull!.rejection, WriteRejection.duplicateInBatch);
      expect(result.errorOrNull!.message, contains('2026-06-01'));
      expect(await repo.logs(), isEmpty);
    });

    test('refuses when any day collides, and writes none of it', () async {
      await repo.add(bleeding('2026-06-02'));
      final result = await repo.addAll(<DayLog>[
        bleeding('2026-06-01'),
        bleeding('2026-06-02'),
        bleeding('2026-06-03'),
      ]);
      expect(
        result.errorOrNull!.rejection,
        WriteRejection.overlapsExistingEntries,
      );
      expect(result.errorOrNull!.dates, <CivilDate>[at('2026-06-02')]);
      // All or nothing: a half-applied batch leaves a calendar the user did
      // not ask for and no way to tell which half is theirs.
      expect(await repo.logs(), hasLength(1));
    });

    test('an empty batch is accepted and does nothing', () async {
      expect((await repo.addAll(const <DayLog>[])).isOk, isTrue);
      expect(await repo.logs(), isEmpty);
    });

    test('refuses a batch reaching into the future', () async {
      final result = await repo.addAll(<DayLog>[
        bleeding('2026-06-29'),
        bleeding('2026-07-01'),
      ]);
      expect(result.errorOrNull!.rejection, WriteRejection.dateInFuture);
      expect(result.errorOrNull!.dates, <CivilDate>[at('2026-07-01')]);
      expect(await repo.logs(), isEmpty);
    });

    test('logs a count, never the dates themselves', () async {
      final logger = RingLogger(clock: FixedClock(today));
      final logged = CycleRepository(
        database: db,
        clock: FixedClock(today),
        logger: logger,
      );
      await logged.addAll(<DayLog>[
        bleeding('2026-06-01'),
        bleeding('2026-06-02'),
      ]);
      expect(logger.dump(), contains('"count":2'));
      // A log line carrying a period date is a privacy incident on disk
      // (docs/PLAN.md 5.5).
      expect(logger.dump(), isNot(contains('2026-06-01')));
    });
  });

  group('logPeriod', () {
    test('writes a run of bleeding days', () async {
      final result = await repo.logPeriod(
        CivilDateRange(at('2026-06-01'), at('2026-06-05')),
      );
      expect(result.isOk, isTrue);
      expect(await repo.logs(), hasLength(5));
    });

    test('refuses to write over days that already exist', () async {
      await repo.add(bleeding('2026-06-03'));
      final result = await repo.logPeriod(
        CivilDateRange(at('2026-06-01'), at('2026-06-05')),
      );
      expect(
        result.errorOrNull!.rejection,
        WriteRejection.overlapsExistingEntries,
      );
      expect(await repo.logs(), hasLength(1));
    });
  });

  group('cycles', () {
    test('segments logs into cycles with validity assigned', () async {
      // Two periods 28 days apart.
      await repo.logPeriod(CivilDateRange(at('2026-04-01'), at('2026-04-04')));
      await repo.logPeriod(CivilDateRange(at('2026-04-29'), at('2026-05-02')));
      final result = await repo.cycles();
      expect(result.isOk, isTrue);
      final cycles = result.valueOrNull!;
      expect(cycles, hasLength(2));
      expect(cycles.first.lengthInDays, 28);
      expect(cycles.first.validity, CycleValidity.ok);
      // The most recent cycle is still in progress.
      expect(cycles.last.isComplete, isFalse);
    });

    test('is empty for a user who has logged nothing', () async {
      expect((await repo.cycles()).valueOrNull, isEmpty);
    });

    test('ignores spotting when opening a cycle', () async {
      await repo.add(bleeding('2026-06-01', FlowIntensity.spotting));
      expect((await repo.cycles()).valueOrNull, isEmpty);
    });
  });

  group('clock checks', () {
    test('reports a backwards clock jump', () async {
      await repo.add(bleeding('2026-06-30'));
      expect(await repo.clockWentBackwards(), isFalse);

      // The device clock moves back a month, so the newest stored log is now
      // dated in the future. Every cycle length is a date difference, so this
      // has to be caught rather than silently producing absurd lengths.
      final rewound = CycleRepository(
        database: db,
        clock: FixedClock(at('2026-05-30')),
      );
      expect(await rewound.clockWentBackwards(), isTrue);
    });

    test('counts the days since the newest log', () async {
      expect(await repo.daysSinceLastLog(), isNull);
      await repo.add(bleeding('2026-06-20'));
      expect(await repo.daysSinceLastLog(), 10);
    });
  });

  group('deletion', () {
    test('removes a single day', () async {
      await repo.add(bleeding('2026-06-01'));
      expect(await repo.deleteDay(at('2026-06-01')), isTrue);
      expect(await repo.logs(), isEmpty);
      expect(await repo.deleteDay(at('2026-06-01')), isFalse);
    });

    test('deleteEverything leaves nothing behind', () async {
      await repo.logPeriod(CivilDateRange(at('2026-06-01'), at('2026-06-04')));
      await repo.deleteEverything();
      expect(await repo.logs(), isEmpty);
    });
  });

  group('WriteRefused', () {
    test('compares by value and prints its reason', () {
      final a = WriteRefused(
        WriteRejection.dayAlreadyLogged,
        <CivilDate>[at('2026-06-01')],
        'msg',
      );
      final b = WriteRefused(
        WriteRejection.dayAlreadyLogged,
        <CivilDate>[at('2026-06-01')],
        'msg',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('dayAlreadyLogged'));
      expect(
        a,
        isNot(
          WriteRefused(
            WriteRejection.dateInFuture,
            <CivilDate>[at('2026-06-01')],
            'msg',
          ),
        ),
      );
    });
  });
}
