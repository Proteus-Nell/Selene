// Frozen export files, imported by the current build (AND-23, AND-28,
// ADR-0020).
//
// Every fixture is written by hand and never regenerated, because a fixture
// that is regenerated tests nothing:
//
//   * a v4 file, the format this build writes, with every measurement;
//   * a v3 file, which must still import (ADR-0020), and which pins the wire
//     names of the five symptoms that existed before AND-23 widened the
//     catalogue;
//   * v2 and v1 files, which must be refused with a message that says why.
//
// The round-trip tests cannot do the first job. They build their input by
// exporting from the current build, so after a rename both sides would move
// together and agree with each other about the wrong name. Adding an enum value
// is safe; renaming one is not, because the name is what is written to the
// database and to the backup file, and a backup is this app's only recovery
// path. There is no cloud copy.
//
// If the v2 fixture fails, do not update it. Put the enum member back and
// change the label in the ARB file, which is what the user actually sees.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/data/transfer/import_v1.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// A v3 export carrying every symptom name that predates AND-23.
///
/// Each of the five is at a different severity, so a rename of any single one
/// fails this rather than only the first. The fingerprint and version are
/// spelled out rather than interpolated: interpolating them would make this
/// file agree with whatever the build currently thinks, which is the exact
/// failure the fixture exists to prevent.
const String _v3Export = '''
{
  "schema_version": 3,
  "app_version": "1.0.0+1",
  "db_schema_version": 4,
  "schema_fingerprint": "v3;envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,schema_fingerprint,schema_version,settings];day_log[date,flow,intercourse,symptoms];condition[condition,end,start]",
  "exported_utc": "2026-08-01T09:30:00.000Z",
  "conditions": [
    {"condition": "pcos", "end": null, "start": "2024-02-01"},
    {"condition": "hormonalContraceptionCombined", "end": "2023-06-30", "start": "2021-01-15"}
  ],
  "day_logs": [
    {
      "date": "2026-01-05",
      "flow": "heavy",
      "intercourse": null,
      "symptoms": {"cramps": "severe", "headache": "moderate"}
    },
    {
      "date": "2026-01-06",
      "flow": "medium",
      "intercourse": "protected",
      "symptoms": {"mood": "mild", "energy": "moderate", "sleep": "severe"}
    },
    {
      "date": "2026-01-07",
      "flow": "spotting",
      "intercourse": "unprotected",
      "symptoms": {}
    }
  ],
  "settings": {
    "onboarding_complete": "true",
    "reminder_enabled": "true",
    "reminder_lead_days": "2"
  }
}
''';

/// A v4 export, the format this build writes, with every measurement
/// (ADR-0020) recorded on one day and none on another.
const String _v4Export = '''
{
  "schema_version": 4,
  "app_version": "1.0.0+10000",
  "db_schema_version": 5,
  "schema_fingerprint": "v4;envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,schema_fingerprint,schema_version,settings];day_log[basal_temperature_celsius,cervical_mucus,date,flow,intercourse,pdg_strip,progesterone_unit,progesterone_value,symptoms];condition[condition,end,start]",
  "exported_utc": "2026-10-28T09:30:00.000Z",
  "conditions": [],
  "day_logs": [
    {
      "basal_temperature_celsius": 36.62,
      "cervical_mucus": "eggWhite",
      "date": "2026-10-10",
      "flow": "none",
      "intercourse": null,
      "pdg_strip": "positive",
      "progesterone_unit": "nmolPerL",
      "progesterone_value": 31.5,
      "symptoms": {}
    },
    {
      "basal_temperature_celsius": null,
      "cervical_mucus": null,
      "date": "2026-10-11",
      "flow": "light",
      "intercourse": null,
      "pdg_strip": null,
      "progesterone_unit": null,
      "progesterone_value": null,
      "symptoms": {"cramps": "mild"}
    }
  ],
  "settings": {"onboarding_complete": "true"}
}
''';

/// Exports in formats this build no longer reads, newest first.
///
/// One entry per refused version. Until ADR-0020 the list grew by one line
/// each time `exportSchemaVersion` was bumped, because ADR-0011 refused every
/// format but the current one, and **each bump stranded every backup taken
/// before it**. v4 only added fields and still reads v3, so v3 is not here;
/// what is here is the running tally of formats that were stranded.
///
/// They are kept as real files rather than mangled version numbers because
/// what is being tested is the refusal a real user meets. ADR-0011 accepted
/// that these are unrestorable; what it did not license is the app being vague
/// about it.
const Map<int, String> _supersededExports = <int, String>{
  2: '''
{
  "schema_version": 2,
  "app_version": "1.0.0+1",
  "db_schema_version": 3,
  "schema_fingerprint": "v2;envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,schema_fingerprint,schema_version,settings];day_log[date,flow,symptoms];condition[condition,end,start]",
  "exported_utc": "2026-08-01T09:30:00.000Z",
  "conditions": [{"condition": "pcos", "end": null, "start": "2024-02-01"}],
  "day_logs": [
    {"date": "2026-01-05", "flow": "heavy", "symptoms": {"cramps": "severe"}}
  ],
  "settings": {"onboarding_complete": "true"}
}
''',
  1: '''
{
  "schema_version": 1,
  "app_version": "1.0.0+1",
  "db_schema_version": 1,
  "schema_fingerprint": "v1;envelope[app_version,day_logs,db_schema_version,exported_utc,schema_fingerprint,schema_version,settings];day_log[date,flow,symptoms]",
  "exported_utc": "2026-02-01T09:30:00.000Z",
  "day_logs": [
    {"date": "2026-01-05", "flow": "heavy", "symptoms": {"cramps": "severe"}}
  ],
  "settings": {"onboarding_complete": "true"}
}
''',
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('the frozen v3 export', () {
    test('still imports', () async {
      final result = await ImportV1.restore(_v3Export, database: db);
      expect(
        result.isOk,
        isTrue,
        reason:
            'a backup written by the shipped v3 build was refused: '
            '${result.errorOrNull?.message}',
      );
      expect(result.valueOrNull!.dayLogsRestored, 3);
    });

    test('every original symptom name still resolves to its member', () async {
      // The assertion AND-23 needs, carried forward into v2. These five strings
      // are what is sitting in users' backup files; the members they map to are
      // what the app reads.
      await ImportV1.restore(_v3Export, database: db);
      final logs = await db.dayLogDao.allLogs();

      final first = logs.firstWhere(
        (log) => log.date == CivilDate.parseIso8601('2026-01-05'),
      );
      expect(first.flow, FlowIntensity.heavy);
      expect(first.severityOf(Symptom.cramps), SymptomSeverity.severe);
      expect(first.severityOf(Symptom.headache), SymptomSeverity.moderate);

      final second = logs.firstWhere(
        (log) => log.date == CivilDate.parseIso8601('2026-01-06'),
      );
      expect(second.severityOf(Symptom.mood), SymptomSeverity.mild);
      expect(second.severityOf(Symptom.energy), SymptomSeverity.moderate);
      expect(second.severityOf(Symptom.sleep), SymptomSeverity.severe);
    });

    test('the symptoms added since are absent rather than defaulted', () async {
      // A widened enum must not invent history. A file that predates `bloating`
      // says nothing about bloating, and "nothing recorded" has to stay
      // distinguishable from "recorded as none".
      await ImportV1.restore(_v3Export, database: db);
      const original = <Symptom>{
        Symptom.cramps,
        Symptom.headache,
        Symptom.mood,
        Symptom.energy,
        Symptom.sleep,
      };
      for (final log in await db.dayLogDao.allLogs()) {
        for (final symptom in Symptom.values) {
          if (original.contains(symptom)) continue;
          expect(
            log.severityOf(symptom),
            SymptomSeverity.none,
            reason:
                '${symptom.name} appeared in a file written before it existed',
          );
        }
      }
    });

    test('intercourse round-trips, including the absence of it', () async {
      // The most sensitive field the app stores, so a backup that loses it or
      // — worse — invents one is the failure that matters. Null must come back
      // null: "not recorded" is a different statement from either answer, and
      // an export that flattened it would put words in the user's mouth.
      await ImportV1.restore(_v3Export, database: db);
      final logs = await db.dayLogDao.allLogs();

      CivilDate on(String iso) => CivilDate.parseIso8601(iso);
      expect(
        logs.firstWhere((l) => l.date == on('2026-01-05')).intercourse,
        isNull,
      );
      expect(
        logs.firstWhere((l) => l.date == on('2026-01-06')).intercourse,
        Intercourse.protected,
      );
      expect(
        logs.firstWhere((l) => l.date == on('2026-01-07')).intercourse,
        Intercourse.unprotected,
      );
    });

    test('condition names and spans survive', () async {
      // The same argument as the symptoms: a condition's name is a wire value.
      await ImportV1.restore(_v3Export, database: db);
      final records = await db.conditionDao.all();
      expect(records, hasLength(2));

      final pcos = records.firstWhere((r) => r.condition == Condition.pcos);
      expect(pcos.start, CivilDate.parseIso8601('2024-02-01'));
      expect(pcos.end, isNull, reason: 'an ongoing condition was closed');

      final pill = records.firstWhere(
        (r) => r.condition == Condition.hormonalContraceptionCombined,
      );
      expect(pill.end, CivilDate.parseIso8601('2023-06-30'));
    });

    test('the fixture fingerprint is the one this build restores v3 by', () {
      // Spelled out in the fixture rather than interpolated, so this comparison
      // is meaningful: it describes files already on people's phones.
      expect(_v3Export, contains(exportSchemaFingerprintV3));
    });

    test('the measurements added since are absent, not defaulted', () async {
      // A v3 file was written before any of these could be recorded, so
      // "not recorded" is the only true reading (ADR-0020).
      await ImportV1.restore(_v3Export, database: db);
      for (final log in await db.dayLogDao.allLogs()) {
        expect(log.hasMeasurements, isFalse, reason: log.date.toIso8601());
        expect(log.progesteroneUnit, isNull);
      }
    });

    test('the rest of the file survives too', () async {
      await ImportV1.restore(_v3Export, database: db);
      final logs = await db.dayLogDao.allLogs();
      expect(
        logs.map((log) => log.flow),
        containsAll(<FlowIntensity>[
          FlowIntensity.heavy,
          FlowIntensity.medium,
          FlowIntensity.spotting,
        ]),
      );
      expect(
        await db.settingsDao.readBool(
          SettingKey.onboardingComplete,
          orElse: false,
        ),
        isTrue,
      );
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 0),
        2,
      );
    });
  });

  group('the frozen v4 export', () {
    test('imports, every measurement intact', () async {
      final result = await ImportV1.restore(_v4Export, database: db);
      expect(result.isOk, isTrue, reason: '${result.errorOrNull?.message}');
      final logs = await db.dayLogDao.allLogs();
      final measured = logs.first;
      expect(measured.basalTemperatureCelsius, 36.62);
      expect(measured.cervicalMucus, CervicalMucus.eggWhite);
      expect(measured.pdgStrip, PdgStripResult.positive);
      expect(measured.progesteroneValue, 31.5);
      expect(measured.progesteroneUnit, ProgesteroneUnit.nmolPerL);
      expect(logs.last.hasMeasurements, isFalse);
    });

    test('the fixture fingerprint matches what this build writes', () {
      // If this fails, the envelope shape changed, which is a decision about
      // every backup in existence and not a detail. See ADR-0011 and ADR-0020.
      expect(
        _v4Export,
        contains(exportSchemaFingerprint),
        reason:
            'the envelope shape changed. Bump exportSchemaVersion, decide '
            'deliberately whether the previous format still restores, and '
            'write it down before updating this fixture.',
      );
    });
  });

  test('every format this build restores has a frozen fixture', () {
    // From the oldest restorable format to the current one. A version that
    // restores but has no fixture is one nothing checks against a real file.
    expect(
      <int>[
        for (final text in <String>[_v3Export, _v4Export]) _versionOf(text),
      ],
      List<int>.generate(
        exportSchemaVersion - oldestRestorableExportVersion + 1,
        (i) => oldestRestorableExportVersion + i,
      ),
    );
    expect(ImportV1.supportedVersions.keys.toList()..sort(), <int>[3, 4]);
  });

  group('every superseded export format', () {
    for (final entry in _supersededExports.entries) {
      final version = entry.key;
      final text = entry.value;

      group('v$version', () {
        test('is refused', () async {
          // ADR-0011, taken knowingly: this app has no cloud and no Play Store
          // restore, so refusing an older file makes every backup taken before
          // that release unrestorable.
          final result = await ImportV1.restore(text, database: db);
          expect(result.isErr, isTrue);
          expect(
            result.errorOrNull!.rejection,
            ImportRejection.unsupportedVersion,
          );
        });

        test('with a message that says what happened, not that it failed', () {
          // The part of ADR-0011 that is this build's responsibility. Refusing
          // is the decision; being vague about it is not covered by it.
          final message = ImportV1.inspect(text).errorOrNull!.message;
          expect(
            message,
            contains('older export format'),
            reason: 'the message does not say the format is the problem',
          );
          expect(
            message,
            contains('v$version'),
            reason: 'it does not name the format the file is actually in',
          );
          expect(
            message,
            contains('Nothing has been changed'),
            reason:
                'a user reading a refusal needs to know their existing data is '
                'still there, or they will assume the import half-ran',
          );
          expect(
            message.toLowerCase(),
            contains('text editor'),
            reason:
                'the file is plain JSON and their days are readable in it. Not '
                'saying so leaves the user believing the data is gone when it '
                'is sitting in front of them',
          );
        });

        test('and changes nothing in the database', () async {
          // Refusals happen before any write. A half-restored health diary is
          // worse than no restore.
          await db.dayLogDao.save(
            DayLog(
              date: CivilDate.parseIso8601('2026-05-05'),
              flow: FlowIntensity.light,
            ),
          );
          await ImportV1.restore(text, database: db);
          final logs = await db.dayLogDao.allLogs();
          expect(logs, hasLength(1));
          expect(logs.single.date, CivilDate.parseIso8601('2026-05-05'));
        });
      });
    }

    test('the list covers every version below the oldest restorable', () {
      // Otherwise raising the oldest restorable format quietly leaves the one
      // just dropped untested, which is the format the most users are holding.
      expect(
        _supersededExports.keys.toList()..sort(),
        List<int>.generate(oldestRestorableExportVersion - 1, (i) => i + 1),
        reason:
            'the oldest restorable format is v$oldestRestorableExportVersion '
            'but the refused fixtures are ${_supersededExports.keys.toList()}. '
            'Add the format that was just dropped, as a real file.',
      );
    });
  });
}

/// The `schema_version` a fixture declares.
int _versionOf(String text) =>
    int.parse(RegExp(r'"schema_version": (\d+)').firstMatch(text)!.group(1)!);
