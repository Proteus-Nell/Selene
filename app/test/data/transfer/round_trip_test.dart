// Round-trip fuzz test for export and import (AND-10).
//
// This is the only backup mechanism in the app. There is no cloud sync, so a
// bug here loses the user everything with no recovery (risk R8). A handful of
// hand-written examples would not find the cases that actually bite: a symptom
// map that happens to be empty, a day with flow but no symptoms, a settings
// value containing a quote. So the databases here are generated.
//
// The seed is fixed, so a failure is reproducible rather than a story about a
// test that went red once.

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/data/transfer/import_v1.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// A randomly generated but valid database state.
typedef GeneratedState = ({
  List<DayLog> logs,
  Map<String, String> settings,
  List<ConditionRecord> conditions,
});

GeneratedState generateState(Random random) {
  final dayCount = random.nextInt(40);
  final usedDays = <int>{};
  final logs = <DayLog>[];
  for (var i = 0; i < dayCount; i++) {
    // A two-year window around the epoch day of 2026-01-01, so dates cross
    // month ends, leap days and year boundaries.
    final epochDay = 20454 + random.nextInt(730);
    if (!usedDays.add(epochDay)) continue;

    final symptoms = <Symptom, SymptomSeverity>{};
    for (final symptom in Symptom.values) {
      if (random.nextBool()) continue;
      final severity =
          SymptomSeverity.values[random.nextInt(SymptomSeverity.values.length)];
      // A severity of "none" is never stored, so generating one would make the
      // expected value disagree with the database rather than with the export.
      if (severity == SymptomSeverity.none) continue;
      symptoms[symptom] = severity;
    }

    // Null roughly half the time, which is the case that matters: "not
    // recorded" has to survive a round trip as null rather than becoming an
    // answer. A generator that always set it would never test that.
    final intercourse = random.nextBool()
        ? null
        : Intercourse.values[random.nextInt(Intercourse.values.length)];

    logs.add(
      DayLog(
        date: CivilDate.fromEpochDay(epochDay),
        flow: FlowIntensity.values[random.nextInt(FlowIntensity.values.length)],
        symptoms: symptoms,
        intercourse: intercourse,
      ),
    );
  }
  logs.sort((a, b) => a.date.compareTo(b.date));

  final settings = <String, String>{};
  for (final key in SettingKey.values) {
    if (random.nextBool()) continue;
    settings[key.wireName] = switch (random.nextInt(3)) {
      0 => '${random.nextBool()}',
      1 => '${random.nextInt(30)}',
      // A value with characters that would break naive string handling.
      _ => 'quoted "value" with \\ and newline\n',
    };
  }
  // Conditions, including the awkward shapes: an ongoing span with no end, a
  // closed one, and the same condition recorded twice over a life. Generated
  // rather than hand-written for the same reason as the logs — the cases that
  // bite are the ones nobody thinks to write down.
  final conditions = <ConditionRecord>[];
  final conditionCount = random.nextInt(6);
  for (var i = 0; i < conditionCount; i++) {
    final start = 20454 + random.nextInt(730);
    final ongoing = random.nextBool();
    conditions.add(
      ConditionRecord(
        id: 0,
        condition: Condition.values[random.nextInt(Condition.values.length)],
        start: CivilDate.fromEpochDay(start),
        end: ongoing
            ? null
            : CivilDate.fromEpochDay(start + random.nextInt(400)),
      ),
    );
  }
  conditions.sort((a, b) {
    final byStart = b.start.compareTo(a.start);
    return byStart != 0 ? byStart : 0;
  });

  return (logs: logs, settings: settings, conditions: conditions);
}

void main() {
  final clock = FixedClock.iso('2026-06-30');

  Future<AppDatabase> databaseWith(GeneratedState state) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.dayLogDao.saveAll(state.logs);
    await db.settingsDao.replaceAll(state.settings);
    for (final record in state.conditions) {
      await db.conditionDao.add(
        condition: record.condition,
        start: record.start,
        end: record.end,
      );
    }
    return db;
  }

  /// Conditions without their ids, which are not exported and never restored.
  List<({Condition condition, CivilDate start, CivilDate? end})> comparable(
    List<ConditionRecord> records,
  ) => <({Condition condition, CivilDate start, CivilDate? end})>[
    for (final r in records)
      (condition: r.condition, start: r.start, end: r.end),
  ];

  test('a random database exports and re-imports identically', () async {
    final random = Random(20260630);
    for (var iteration = 0; iteration < 60; iteration++) {
      final state = generateState(random);
      final source = await databaseWith(state);
      final text = ExportV1.encode(
        await ExportV1.build(database: source, clock: clock),
      );
      await source.close();

      // Restore into a database that already holds something else, which is
      // the case that matters: a restore has to replace, not merge.
      final target = await databaseWith(generateState(random));
      final result = await ImportV1.restore(text, database: target);
      expect(
        result.isOk,
        isTrue,
        reason: 'iteration $iteration: ${result.errorOrNull}',
      );

      expect(
        await target.dayLogDao.allLogs(),
        state.logs,
        reason: 'iteration $iteration day logs',
      );
      expect(
        await target.settingsDao.allRaw(),
        state.settings,
        reason: 'iteration $iteration settings',
      );
      expect(
        comparable(await target.conditionDao.all()),
        comparable(state.conditions),
        reason: 'iteration $iteration conditions',
      );
      await target.close();
    }
  });

  test(
    'a second round trip through the file format is byte identical',
    () async {
      // Export, import, export again: the second file must equal the first, or
      // the format is losing or reordering something.
      final random = Random(1);
      for (var iteration = 0; iteration < 20; iteration++) {
        final state = generateState(random);
        final first = await databaseWith(state);
        final firstText = ExportV1.encode(
          await ExportV1.build(database: first, clock: clock),
        );
        await first.close();

        final second = AppDatabase(NativeDatabase.memory());
        expect(
          (await ImportV1.restore(firstText, database: second)).isOk,
          isTrue,
        );
        final secondText = ExportV1.encode(
          await ExportV1.build(database: second, clock: clock),
        );
        await second.close();

        expect(secondText, firstText, reason: 'iteration $iteration');
      }
    },
  );

  test('the exported file is readable JSON, not an opaque blob', () async {
    // The user's only recovery path is this file. It should be something a
    // person can open in a text editor and understand (docs/PLAN.md 6.5).
    final db = await databaseWith((
      logs: <DayLog>[
        DayLog(
          date: CivilDate.parseIso8601('2026-03-14'),
          flow: FlowIntensity.heavy,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.severe,
          },
        ),
      ],
      settings: const <String, String>{'reminder_enabled': 'true'},
      conditions: <ConditionRecord>[
        ConditionRecord(
          id: 0,
          condition: Condition.pcos,
          start: CivilDate.parseIso8601('2024-02-01'),
        ),
      ],
    ));
    addTearDown(db.close);

    final text = ExportV1.encode(
      await ExportV1.build(database: db, clock: clock),
    );
    expect(text, contains('"date": "2026-03-14"'));
    expect(text, contains('"flow": "heavy"'));
    expect(text, contains('"cramps": "severe"'));
    // Conditions are readable in the same way, and an ongoing one is an
    // explicit null rather than a missing key: "still going" and "we forgot to
    // write it" must not look the same in the file a person is reading.
    expect(text, contains('"condition": "pcos"'));
    expect(text, contains('"start": "2024-02-01"'));
    expect(text, contains('"end": null'));
    // Enum names, never ordinals: a file full of integers is unreadable and
    // silently reinterprets itself if the enums are ever reordered.
    expect(text, isNot(contains('"flow": 4')));

    final decoded = jsonDecode(text)! as Map<String, Object?>;
    expect(decoded['schema_version'], exportSchemaVersion);
    expect(decoded['app_version'], appVersion);
    expect(decoded['exported_utc'], startsWith('2026-06-30'));
  });
}
