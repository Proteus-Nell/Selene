/// Condition repository.
///
/// Reads and writes the user's recorded conditions, and clamps the dates that
/// cannot be true. Deliberately thin over the DAO: there is no derived state
/// here to get wrong, and nothing it returns reaches the prediction model.
///
/// Includes:
///     - ConditionRepository: The five operations, with their date clamping.
library;

import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/condition.dart';

/// Condition repository: reads and writes the user's recorded conditions.
///
/// A thin layer over the conditions DAO, and deliberately so: there is no
/// derived state here to get wrong. Its one job beyond passing calls through
/// is refusing dates that cannot be true, because an inverted or future-dated
/// span silently corrupts every overlap count that reads it afterwards.
///
/// **Nothing this class returns reaches the Bayesian filter.** ADR-0010, and
/// `condition_repository_test.dart` proves it rather than asserting it.
///
/// Attributes:
///     _db (AppDatabase): Where the conditions are stored.
///     _clock (Clock): Supplies today, which bounds every accepted date.
class ConditionRepository {
  /// Creates a repository over [database].
  ///
  /// Args:
  ///     database (AppDatabase): Where the conditions are stored.
  ///     clock (Clock): Supplies today, which bounds every accepted date.
  ConditionRepository({required AppDatabase database, required Clock clock})
    : _db = database,
      // An initializing formal would have to be `this._clock`, and Dart does
      // not allow a named parameter to start with an underscore. Same as
      // PredictionRepository.
      // ignore: prefer_initializing_formals
      _clock = clock;

  /// Where the conditions are stored.
  final AppDatabase _db;

  /// Supplies today, which bounds every accepted date.
  final Clock _clock;

  /// Read every recorded condition, most recently started first.
  ///
  /// Returns:
  ///     `Future<List<ConditionRecord>>`: Every span, newest start first.
  Future<List<ConditionRecord>> all() => _db.conditionDao.all();

  /// Watch every recorded condition.
  ///
  /// Returns:
  ///     `Stream<List<ConditionRecord>>`: Re-emitted whenever one changes.
  Stream<List<ConditionRecord>> watchAll() => _db.conditionDao.watchAll();

  /// Read the conditions active on one day.
  ///
  /// Args:
  ///     date (CivilDate): The day to test each span against.
  ///
  /// Returns:
  ///     `Future<List<ConditionRecord>>`: Those covering [date].
  Future<List<ConditionRecord>> activeOn(CivilDate date) async {
    final records = await all();
    return records.where((record) => record.isActiveOn(date)).toList();
  }

  /// Record a condition as starting on a given day.
  ///
  /// A future start is clamped to today rather than refused. Nowhere else in
  /// the app accepts a future date, because a future-dated row is almost
  /// always a wrong device clock, and here the difference between refusing and
  /// clamping is the difference between losing what the user was telling us
  /// and storing it a few days early.
  ///
  /// Args:
  ///     condition (Condition): What is being recorded.
  ///     start (CivilDate): The first day it applied. Clamped to today.
  ///     end (CivilDate?, optional): The last day. Clamped to today, and
  ///         never allowed before the start. Defaults to null.
  ///
  /// Returns:
  ///     `Future<ConditionRecord>`: The stored record, with its assigned id
  ///     and whatever dates survived clamping.
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

  /// Close an open span on a given day.
  ///
  /// An end before the start would make the span inverted, and every overlap
  /// count that read it afterwards would be wrong with nothing to indicate it.
  /// So the date is clamped to the start rather than stored as given.
  ///
  /// Does nothing when no span has that id.
  ///
  /// Args:
  ///     id (int): Row identity of the span to close.
  ///     end (CivilDate): The last day it applied. Clamped to today, and
  ///         never allowed before the span's start.
  Future<void> end({required int id, required CivilDate end}) async {
    final records = await all();
    final record = records.where((r) => r.id == id).firstOrNull;
    if (record == null) return;
    final today = _clock.today();
    var safe = end > today ? today : end;
    if (safe < record.start) safe = record.start;
    await _db.conditionDao.end(id: id, end: safe);
  }

  /// Reopen a closed span, clearing its end date.
  ///
  /// Args:
  ///     id (int): Row identity of the span to reopen.
  Future<void> reopen(int id) => _db.conditionDao.reopen(id);

  /// Delete a span outright.
  ///
  /// Args:
  ///     id (int): Row identity of the span to delete.
  Future<void> remove(int id) => _db.conditionDao.remove(id);
}
