/// Model state cache access.
///
/// Reads and writes the one row holding the cached posterior and prediction.
/// Everything in it is recomputable, so nothing here needs to be careful: the
/// worst outcome of a wrong answer is a few milliseconds of arithmetic.
///
/// Includes:
///     - ModelStateDao: The four operations on the singleton row.
library;

import 'package:drift/drift.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';

part 'model_state_dao.g.dart';

/// Model state DAO: reads and writes the single cached posterior row.
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

  /// Read the cached row.
  ///
  /// Returns:
  ///     `Future<ModelStateRow?>`: The row, or null if nothing has been
  ///     cached yet.
  Future<ModelStateRow?> current() => (select(
    modelStates,
  )..where((t) => t.id.equals(singletonId))).getSingleOrNull();

  /// Read the cached row, but only if it matches an input signature.
  ///
  /// This comparison is the entire cache-invalidation mechanism, so it lives
  /// here rather than at the call site where it could be forgotten.
  ///
  /// Args:
  ///     signature (String): What the caller's inputs currently hash to.
  ///
  /// Returns:
  ///     `Future<ModelStateRow?>`: The row when the signatures agree,
  ///     otherwise null.
  Future<ModelStateRow?> matching(String signature) async {
    final row = await current();
    if (row == null || row.inputSignature != signature) return null;
    return row;
  }

  /// Replace the cached row.
  ///
  /// The id is forced to [singletonId], so a caller cannot accidentally
  /// create a second cache row.
  ///
  /// Args:
  ///     row (ModelStateRow): The row to store.
  Future<void> store(ModelStateRow row) =>
      into(modelStates).insertOnConflictUpdate(
        row.copyWith(id: singletonId),
      );

  /// Drop the cache.
  ///
  /// Safe on any suspicion of staleness: the row is recomputable.
  Future<void> clear() => delete(modelStates).go();
}
