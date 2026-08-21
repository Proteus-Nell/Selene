import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/condition.dart';

/// Reads and writes the user's recorded conditions.
///
/// A thin layer over the conditions DAO, and deliberately so — there is no derived
/// state here to get wrong. Its one job beyond passing calls through is
/// refusing dates that cannot be true, because an inverted or future-dated span
/// silently corrupts every overlap count that reads it afterwards.
///
/// **Nothing this class returns reaches the Bayesian filter.** ADR-0010, and
/// `condition_repository_test.dart` proves it rather than asserting it.
class ConditionRepository {
  /// Creates a repository over [database].
  ConditionRepository({required AppDatabase database, required Clock clock})
    : _db = database,
      // An initializing formal would have to be `this._clock`, and Dart does
      // not allow a named parameter to start with an underscore. Same as
      // PredictionRepository.
      // ignore: prefer_initializing_formals
      _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  /// Every recorded condition, most recently started first.
  Future<List<ConditionRecord>> all() => _db.conditionDao.all();

  /// Every recorded condition, re-emitted whenever one changes.
  Stream<List<ConditionRecord>> watchAll() => _db.conditionDao.watchAll();

  /// The conditions active on [date].
  Future<List<ConditionRecord>> activeOn(CivilDate date) async {
    final records = await all();
    return records.where((record) => record.isActiveOn(date)).toList();
  }

  /// Records [condition] as starting on [start].
  ///
  /// A future start is clamped to today rather than refused. Nowhere else in
  /// the app accepts a future date — a future-dated row is almost always a
  /// wrong device clock — and here the difference between refusing and clamping
  /// is the difference between losing what the user was telling us and storing
  /// it a few days early.
  Future<ConditionRecord> add({
    required Condition condition,
    required CivilDate start,
    CivilDate? end,
  }) {
    final today = _clock.today();
    final safeStart = start > today ? today : start;
    final safeEnd = end == null
        ? null
        : (end < safeStart ? safeStart : (end > today ? today : end));
    return _db.conditionDao.add(
      condition: condition,
      start: safeStart,
      end: safeEnd,
    );
  }

  /// Ends the condition with [id] on [end].
  ///
  /// An end before the start would make the span inverted, and every overlap
  /// count that read it afterwards would be wrong with nothing to indicate it.
  /// So the date is clamped to the start rather than stored as given.
  Future<void> end({required int id, required CivilDate end}) async {
    final records = await all();
    final record = records.where((r) => r.id == id).firstOrNull;
    if (record == null) return;
    final today = _clock.today();
    var safe = end > today ? today : end;
    if (safe < record.start) safe = record.start;
    await _db.conditionDao.end(id: id, end: safe);
  }

  /// Clears the end date on the condition with [id].
  Future<void> reopen(int id) => _db.conditionDao.reopen(id);

  /// Deletes the condition with [id].
  Future<void> remove(int id) => _db.conditionDao.remove(id);
}
