import 'package:drift/drift.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';
import 'package:period_tracker/domain/models/condition.dart';

part 'condition_dao.g.dart';

/// Reads and writes the user's recorded conditions.
///
/// Deals in the domain [ConditionRecord] rather than in generated row classes,
/// like every other DAO here: the row shape is a storage detail, and letting it
/// upward would put a drift import in every caller.
///
/// **Nothing this DAO returns reaches the prediction model.** That is a
/// decision (ADR-0010), not an oversight, and `no_condition_reaches_the_filter`
/// in `condition_repository_test.dart` enforces it. The one exception is not an
/// exception to this rule: the pregnancy suppression reads whether a condition
/// is active and never feeds a value into the filter's arithmetic.
@DriftAccessor(tables: <Type>[Conditions])
class ConditionDao extends DatabaseAccessor<AppDatabase>
    with _$ConditionDaoMixin {
  /// Creates the DAO over [attachedDatabase].
  ConditionDao(super.attachedDatabase);

  /// Every recorded condition, most recently started first.
  ///
  /// Newest first because the list is read far more often to answer "what is
  /// true now" than "what was true in 2019", and the ongoing ones are the ones
  /// with the most recent start dates.
  Future<List<ConditionRecord>> all() async {
    final rows =
        await (select(conditions)..orderBy(<OrderClauseGenerator<Conditions>>[
              (t) => OrderingTerm.desc(t.startEpochDay),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    return rows.map(_toRecord).toList();
  }

  /// Every recorded condition, re-emitted whenever one changes.
  Stream<List<ConditionRecord>> watchAll() {
    final query = select(conditions)
      ..orderBy(<OrderClauseGenerator<Conditions>>[
        (t) => OrderingTerm.desc(t.startEpochDay),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return query.watch().map((rows) => rows.map(_toRecord).toList());
  }

  /// Adds [condition] as starting on [start], and returns the stored record.
  ///
  /// No uniqueness constraint, deliberately. The same condition can genuinely
  /// recur — someone can start the pill, stop, and start again years later —
  /// and refusing the second span would force it to overwrite the first, taking
  /// the interpretation of those older cycles with it.
  Future<ConditionRecord> add({
    required Condition condition,
    required CivilDate start,
    CivilDate? end,
  }) async {
    final id = await into(conditions).insert(
      ConditionsCompanion.insert(
        condition: condition,
        startEpochDay: start.epochDay,
        endEpochDay: Value<int?>(end?.epochDay),
      ),
    );
    return ConditionRecord(
      id: id,
      condition: condition,
      start: start,
      end: end,
    );
  }

  /// Ends the condition with [id] on [end].
  ///
  /// Sets a date rather than deleting the row. The whole reason this table
  /// stores spans instead of flags is that "I was on the pill for those six
  /// cycles" stays true after stopping; deleting on end would discard exactly
  /// the fact the span was recorded for.
  Future<void> end({required int id, required CivilDate end}) =>
      (update(conditions)..where((t) => t.id.equals(id))).write(
        ConditionsCompanion(endEpochDay: Value<int?>(end.epochDay)),
      );

  /// Reopens the condition with [id], clearing its end date.
  ///
  /// For the user who ended one by mistake, or on the wrong day. Without this
  /// the only correction available is delete-and-retype, which loses the start
  /// date they were trying to keep.
  Future<void> reopen(int id) =>
      (update(conditions)..where((t) => t.id.equals(id))).write(
        const ConditionsCompanion(endEpochDay: Value<int?>(null)),
      );

  /// Deletes the condition with [id] outright.
  ///
  /// For a mistyped entry, not for ending one — [end] is that. A real delete
  /// rather than a flag, matching the promise ADR-0004 makes about the rest of
  /// the database: what the user deletes is gone.
  Future<void> remove(int id) =>
      (delete(conditions)..where((t) => t.id.equals(id))).go();

  static ConditionRecord _toRecord(ConditionRow row) => ConditionRecord(
    id: row.id,
    condition: row.condition,
    start: CivilDate.fromEpochDay(row.startEpochDay),
    end: row.endEpochDay == null
        ? null
        : CivilDate.fromEpochDay(row.endEpochDay!),
  );
}
