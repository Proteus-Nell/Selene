/// Day log storage access.
///
/// Reads and writes the user's day logs, in the domain type rather than in
/// generated row classes. A day and its symptoms are one fact, so every write
/// here replaces the whole day inside a transaction.
///
/// Includes:
///     - DayLogDao: Every operation on the day_logs and symptoms tables.
library;

import 'package:drift/drift.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/domain/models/day_log.dart';

part 'day_log_dao.g.dart';

/// Day log DAO: reads and writes the user's day logs.
///
/// Everything here deals in the domain [DayLog], never in generated row
/// classes. The row shape is an implementation detail of storage, and letting
/// it leak upward would put a drift import in every caller and make the schema
/// hard to change.
@DriftAccessor(tables: <Type>[DayLogs, Symptoms])
class DayLogDao extends DatabaseAccessor<AppDatabase> with _$DayLogDaoMixin {
  /// Creates the DAO over [attachedDatabase].
  DayLogDao(super.attachedDatabase);

  /// Read every logged day, oldest first.
  ///
  /// Returns:
  ///     `Future<List<DayLog>>`: Every day, with its symptoms attached.
  Future<List<DayLog>> allLogs() async {
    final rows =
        await (select(dayLogs)..orderBy(<OrderClauseGenerator<DayLogs>>[
              (t) => OrderingTerm.asc(t.epochDay),
            ]))
            .get();
    final symptomRows = await select(symptoms).get();
    return _assemble(rows, symptomRows);
  }

  /// Watch every logged day, oldest first.
  ///
  /// The stream covers both tables, so editing a symptom updates it as surely
  /// as editing a flow does.
  ///
  /// Returns:
  ///     `Stream<List<DayLog>>`: Re-emitted whenever either table changes.
  Stream<List<DayLog>> watchAllLogs() {
    final query = select(dayLogs)
      ..orderBy(<OrderClauseGenerator<DayLogs>>[
        (t) => OrderingTerm.asc(t.epochDay),
      ]);
    return query.watch().asyncMap((rows) async {
      final symptomRows = await select(symptoms).get();
      return _assemble(rows, symptomRows);
    });
  }

  /// Read one day's log.
  ///
  /// Args:
  ///     date (CivilDate): The day to read.
  ///
  /// Returns:
  ///     `Future<DayLog?>`: The entry, or null if that day was never logged.
  Future<DayLog?> logFor(CivilDate date) async {
    final row = await (select(
      dayLogs,
    )..where((t) => t.epochDay.equals(date.epochDay))).getSingleOrNull();
    if (row == null) return null;
    final symptomRows = await (select(
      symptoms,
    )..where((t) => t.epochDay.equals(date.epochDay))).get();
    return _assemble(<DayLogRow>[row], symptomRows).single;
  }

  /// Filter a set of dates down to the ones already logged.
  ///
  /// Used by the repository to reject a write that would collide with existing
  /// entries, rather than silently overwriting them.
  ///
  /// Args:
  ///     dates (`Iterable<CivilDate>`): The candidate days.
  ///
  /// Returns:
  ///     `Future<Set<CivilDate>>`: Those of [dates] that already have a row.
  Future<Set<CivilDate>> existingDates(Iterable<CivilDate> dates) async {
    final epochDays = dates.map((d) => d.epochDay).toList();
    if (epochDays.isEmpty) return <CivilDate>{};
    final rows = await (select(
      dayLogs,
    )..where((t) => t.epochDay.isIn(epochDays))).get();
    return rows.map((r) => CivilDate.fromEpochDay(r.epochDay)).toSet();
  }

  /// The row to write for [log], with every column stated.
  ///
  /// A companion with an explicit [Value] per column, never the `DayLogRow`
  /// data class. Drift builds both the inserted values and the `DO UPDATE SET`
  /// clause of an upsert by calling `toColumns(true)`, and a data class drops
  /// its null fields under that flag. `intercourse` is the one nullable column
  /// here, so writing a day whose answer had been cleared produced an update
  /// that never mentioned the column and left the old answer in place: the
  /// user tapped the selected chip, the editor did everything right, and the
  /// answer came straight back.
  ///
  /// A companion says `present` instead, so a null is written as a null.
  ///
  /// This is why the whole day goes through one place. A save replaces the
  /// day, so every column has to be named on every write, and a column added
  /// later that is missed here would fail the same silent way.
  DayLogsCompanion _rowFor(DayLog log) => DayLogsCompanion(
    epochDay: Value<int>(log.date.epochDay),
    flow: Value<FlowIntensity>(log.flow),
    intercourse: Value<Intercourse?>(log.intercourse),
  );

  /// Write one day, replacing any existing entry for it.
  ///
  /// The whole write is one transaction: a day's flow and its symptoms are one
  /// fact, and a crash between them would leave a day claiming symptoms it no
  /// longer has.
  ///
  /// Args:
  ///     log (DayLog): The day to write. Replaces the stored day entirely.
  Future<void> save(DayLog log) => transaction(() async {
    await into(dayLogs).insertOnConflictUpdate(_rowFor(log));
    await (delete(
      symptoms,
    )..where((t) => t.epochDay.equals(log.date.epochDay))).go();
    await _insertSymptoms(log);
  });

  /// Write many days in a single transaction.
  ///
  /// All or nothing: a partial import is worse than a refused one, because the
  /// user cannot tell which half landed.
  ///
  /// Args:
  ///     logs (`Iterable<DayLog>`): The days to write. Each replaces the
  ///         stored day entirely.
  Future<void> saveAll(Iterable<DayLog> logs) => transaction(() async {
    for (final log in logs) {
      await into(dayLogs).insertOnConflictUpdate(_rowFor(log));
      await (delete(
        symptoms,
      )..where((t) => t.epochDay.equals(log.date.epochDay))).go();
      await _insertSymptoms(log);
    }
  });

  /// Delete one day's log.
  ///
  /// The symptom rows go with it through the foreign key cascade, which is why
  /// `PRAGMA foreign_keys` is turned on for every connection.
  ///
  /// Args:
  ///     date (CivilDate): The day to delete.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether a row was actually removed.
  Future<bool> deleteDay(CivilDate date) async {
    final removed = await (delete(
      dayLogs,
    )..where((t) => t.epochDay.equals(date.epochDay))).go();
    return removed > 0;
  }

  /// Delete every row in every user-data table, then reclaim the pages.
  ///
  /// Steps:
  ///     1. Empty symptoms, day logs, model states, conditions and settings,
  ///        in one transaction.
  ///     2. Re-seed the export-format acknowledgement, so a wiped database is
  ///        in the same state as a fresh one.
  ///     3. `VACUUM` outside the transaction, which is the only place SQLite
  ///        allows it.
  ///
  /// A real `DELETE` followed by `VACUUM`, never a soft-delete flag
  /// (`docs/PLAN.md` 6.5). Without the vacuum the deleted rows stay legible in
  /// the file's free pages, so a user who deleted everything would still be
  /// carrying it around.
  Future<void> deleteEverything() async {
    await transaction(() async {
      await delete(symptoms).go();
      await delete(dayLogs).go();
      await attachedDatabase.customStatement('DELETE FROM model_states');
      // Conditions are user data of the most sensitive kind in this app, a
      // recorded pregnancy or PCOS diagnosis, and leaving them behind would
      // make "delete everything" a lie. They were added at AND-22 and are
      // named here explicitly rather than trusted to a cascade, because
      // nothing references them and a cascade would never have fired.
      await attachedDatabase.customStatement('DELETE FROM conditions');
      await attachedDatabase.customStatement('DELETE FROM settings');
      // Re-seeded rather than left absent. A wiped database is in the same
      // state as a fresh one, and a fresh one is not warned that its backups
      // will not restore: there are none. Without this, deleting everything
      // brings back a banner urging the user to back up the data they have
      // just deliberately destroyed. See SettingKey.exportFormatAcknowledged.
      await attachedDatabase.customStatement(
        'INSERT INTO settings (setting_key, setting_value) VALUES (?, ?)',
        <Object?>[
          SettingKey.exportFormatAcknowledged.wireName,
          '$exportSchemaVersion',
        ],
      );
    });
    await attachedDatabase.customStatement('VACUUM');
  }

  /// Insert one day's symptom rows.
  ///
  /// Assumes the caller has already cleared the day's existing rows, which
  /// [save] and [saveAll] both do inside their transaction.
  ///
  /// Args:
  ///     log (DayLog): The day whose symptoms to write.
  Future<void> _insertSymptoms(DayLog log) async {
    for (final entry in log.symptoms.entries) {
      // A recorded "none" carries no information and would make an empty day
      // indistinguishable from an unlogged one on the way back out.
      if (entry.value == SymptomSeverity.none) continue;
      await into(symptoms).insert(
        SymptomRow(
          epochDay: log.date.epochDay,
          symptom: entry.key,
          severity: entry.value,
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  /// Join day rows to their symptom rows, in Dart.
  ///
  /// Two queries and a group-by rather than a SQL join: the join would return
  /// one row per symptom per day and need the same regrouping anyway, and the
  /// whole table is a few thousand rows for even a decade of daily logging.
  ///
  /// Args:
  ///     rows (`List<DayLogRow>`): The day rows, in the order to return.
  ///     symptomRows (`List<SymptomRow>`): Symptom rows for those days, in
  ///         any order.
  ///
  /// Returns:
  ///     `List<DayLog>`: One entry per row in [rows], same order.
  static List<DayLog> _assemble(
    List<DayLogRow> rows,
    List<SymptomRow> symptomRows,
  ) {
    final byDay = <int, Map<Symptom, SymptomSeverity>>{};
    for (final row in symptomRows) {
      (byDay[row.epochDay] ??= <Symptom, SymptomSeverity>{})[row.symptom] =
          row.severity;
    }
    return <DayLog>[
      for (final row in rows)
        DayLog(
          date: CivilDate.fromEpochDay(row.epochDay),
          flow: row.flow,
          intercourse: row.intercourse,
          symptoms: byDay[row.epochDay] ?? const <Symptom, SymptomSeverity>{},
        ),
    ];
  }
}
