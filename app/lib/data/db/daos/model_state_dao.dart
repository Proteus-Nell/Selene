import 'package:drift/drift.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';

part 'model_state_dao.g.dart';

/// Reads and writes the single cached posterior row.
///
/// Everything this table holds is recomputable from the day logs and the
/// shipped priors, so the DAO never has to be careful with it: dropping the
/// cache costs a few milliseconds of arithmetic and can never cost data. That
/// is also why [clear] is safe to call on any suspicion of staleness.
@DriftAccessor(tables: <Type>[ModelStates])
class ModelStateDao extends DatabaseAccessor<AppDatabase>
    with _$ModelStateDaoMixin {
  /// Creates the DAO over [attachedDatabase].
  ModelStateDao(super.attachedDatabase);

  /// The id of the one row this table ever holds.
  static const int singletonId = 0;

  /// The cached row, or null if nothing has been cached yet.
  Future<ModelStateRow?> current() => (select(
    modelStates,
  )..where((t) => t.id.equals(singletonId))).getSingleOrNull();

  /// The cached row if it was computed from [signature], otherwise null.
  ///
  /// This comparison is the entire cache-invalidation mechanism, so it lives
  /// here rather than at the call site where it could be forgotten.
  Future<ModelStateRow?> matching(String signature) async {
    final row = await current();
    if (row == null || row.inputSignature != signature) return null;
    return row;
  }

  /// Replaces the cached row.
  Future<void> store(ModelStateRow row) =>
      into(modelStates).insertOnConflictUpdate(
        row.copyWith(id: singletonId),
      );

  /// Drops the cache.
  Future<void> clear() => delete(modelStates).go();
}
