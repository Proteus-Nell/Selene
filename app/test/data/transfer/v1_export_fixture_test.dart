// A real v1 export file, frozen, imported by the current build (AND-23).
//
// AND-23 widened `Symptom` from five values to sixteen. Adding is safe and
// renaming is not, because the name is what is written to the database and to
// the export file — and an export is this app's only backup. There is no cloud
// copy, so a symptom whose Dart member was renamed is a symptom the user's own
// backup can no longer restore, with no migration that recovers it.
//
// The round-trip tests elsewhere build their input by exporting from the
// current build, which means they would pass unchanged after a rename: both
// sides would move together and agree with each other about the wrong name.
// The bytes below were written by the build before the widening and are never
// regenerated. That is the whole point of the file — it is the only test here
// that can tell you the names changed.
//
// If this fails, do not update the fixture. Put the enum member back and change
// the label in the ARB file instead, which is what the user actually sees.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/import_v1.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// An export written before the symptom catalogue grew.
///
/// Every one of the five original symptoms appears, each at a different
/// severity, so a rename of any single member fails this rather than only the
/// first. `db_schema_version` is 1, which is what a file of this vintage
/// carries: the envelope version and the database version are independent, and
/// this fixture is the case that proves the importer does not conflate them.
const String _v1Export = '''
{
  "schema_version": 1,
  "app_version": "1.0.0+1",
  "db_schema_version": 1,
  "schema_fingerprint": "v1;envelope[app_version,day_logs,db_schema_version,exported_utc,schema_fingerprint,schema_version,settings];day_log[date,flow,symptoms]",
  "exported_utc": "2026-02-01T09:30:00.000Z",
  "day_logs": [
    {
      "date": "2026-01-05",
      "flow": "heavy",
      "symptoms": {"cramps": "severe", "headache": "moderate"}
    },
    {
      "date": "2026-01-06",
      "flow": "medium",
      "symptoms": {"mood": "mild", "energy": "moderate", "sleep": "severe"}
    },
    {
      "date": "2026-01-07",
      "flow": "spotting",
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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a v1 export still imports', () async {
    final result = await ImportV1.restore(_v1Export, database: db);
    expect(
      result.isOk,
      isTrue,
      reason:
          'a backup written by the shipped v1 build was refused: '
          '${result.errorOrNull?.message}',
    );
    expect(result.valueOrNull!.dayLogsRestored, 3);
  });

  test('every original symptom name still resolves to its member', () async {
    // The assertion AND-23 needs. These five strings are what is sitting in
    // users' backup files; the members they map to are what the app reads.
    await ImportV1.restore(_v1Export, database: db);
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
    await ImportV1.restore(_v1Export, database: db);
    final logs = await db.dayLogDao.allLogs();
    for (final log in logs) {
      for (final symptom in Symptom.values) {
        if (const <Symptom>{
          Symptom.cramps,
          Symptom.headache,
          Symptom.mood,
          Symptom.energy,
          Symptom.sleep,
        }.contains(symptom)) {
          continue;
        }
        expect(
          log.severityOf(symptom),
          SymptomSeverity.none,
          reason:
              '${symptom.name} appeared in a file written before it existed',
        );
      }
    }
  });

  test('the rest of the file survives too', () async {
    // The symptom names are the fragile part, but a fixture that only checked
    // them would let the flow values or the settings rot unnoticed.
    await ImportV1.restore(_v1Export, database: db);
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
}
