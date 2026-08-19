import 'package:drift/drift.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Every calendar day the user has recorded something for.
///
/// This table is the **only** source of truth in the app. Cycles, statistics
/// and predictions are all derived from an ordered list of these rows, which is
/// why export and import deal in day logs alone (`docs/PLAN.md` 4.1). Nothing
/// derived is stored: a second copy of a fact is a second thing that can be
/// wrong.
///
/// Two schema choices here are load-bearing rather than stylistic.
///
/// **The primary key is the calendar day**, stored as [epochDay], the number of
/// days since 1970-01-01. Not a surrogate id, not a timestamp. A user has at
/// most one log per day by definition, so making that a database constraint
/// means a duplicate date cannot be created even by a bug elsewhere, and the
/// integer arithmetic is exact and timezone-free (risk R7).
///
/// **Enums are stored by name, not by index.** `intEnum` would write the
/// ordinal, so reordering the members of [FlowIntensity] in a later release
/// would silently reinterpret every stored row: heavy becomes light with no
/// error anywhere. Storing the name costs a few bytes and makes that class of
/// mistake impossible. It also leaves the database readable in a plain `sqlite3`
/// dump, which matters when the user's only recovery path is their own export.
@DataClassName('DayLogRow')
class DayLogs extends Table {
  /// Days since 1970-01-01. The calendar day this row describes.
  IntColumn get epochDay => integer()();

  /// How heavy bleeding was, by [FlowIntensity] name.
  TextColumn get flow => textEnum<FlowIntensity>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{epochDay};
}

/// Symptom severities recorded against a day.
///
/// Normalised out of [DayLogs] rather than serialised into a column, so that a
/// symptom is a row the database can constrain: one severity per symptom per
/// day, enforced by the primary key, and deleted automatically with its day.
///
/// The cascade is not decorative. It is what makes "delete this day" a single
/// statement that cannot leave orphaned symptom rows behind, and orphaned rows
/// carrying health data would survive a deletion the user believed was complete.
/// Foreign keys are off by default in SQLite, so the connection turns them on
/// explicitly; see `connection.dart`.
@DataClassName('SymptomRow')
class Symptoms extends Table {
  /// The day this symptom was recorded for.
  IntColumn get epochDay =>
      integer().references(DayLogs, #epochDay, onDelete: KeyAction.cascade)();

  /// Which symptom, by [Symptom] name.
  TextColumn get symptom => textEnum<Symptom>()();

  /// How strongly it was felt, by [SymptomSeverity] name.
  TextColumn get severity => textEnum<SymptomSeverity>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{epochDay, symptom};
}

/// The cached posterior and prediction.
///
/// A single row, always with [id] zero. This is a cache and nothing else: every
/// value in it is recomputable from [DayLogs] plus the shipped priors, so
/// losing it costs a few milliseconds and never costs data. It exists because
/// the filter runs on every calendar repaint otherwise.
///
/// [inputHash] is what makes the cache correct. It covers the whole input to the
/// computation, so a backdated edit to any past day changes it and the cached
/// row stops matching. See `PredictionRepository`.
@DataClassName('ModelStateRow')
class ModelStates extends Table {
  /// Always zero. There is one posterior per user and one user per device.
  IntColumn get id => integer()();

  /// Hash of everything the prediction was computed from.
  TextColumn get inputHash => text()();

  /// Posterior mean of the log-length level.
  RealColumn get stateMean => real()();

  /// Posterior variance of the log-length level.
  RealColumn get stateVariance => real()();

  /// How many observed cycles were folded in.
  IntColumn get stateObservations => integer()();

  /// Observation standard deviation the filter ran with.
  RealColumn get obsSd => real()();

  /// Drift standard deviation the filter ran with.
  RealColumn get driftSd => real()();

  /// Whether the per-user refit actually ran.
  BoolColumn get personalised => boolean()();

  /// Predicted cycle length at the median, in days.
  IntColumn get medianDays => integer()();

  /// Lower bound of the 50% window, in days.
  IntColumn get lo50 => integer()();

  /// Upper bound of the 50% window, in days.
  IntColumn get hi50 => integer()();

  /// Lower bound of the 80% window, in days.
  IntColumn get lo80 => integer()();

  /// Upper bound of the 80% window, in days.
  IntColumn get hi80 => integer()();

  /// Confidence class name, as produced by the intervals layer.
  TextColumn get confidence => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// User preferences, as a typed key-value store.
///
/// Key-value rather than one column per setting, so adding a preference is not
/// a schema migration. Migrations on this table would be pure risk: every one is
/// a chance to lose the tables that actually hold data, and a preference is the
/// one thing in the database that can be safely defaulted if it goes missing.
/// The typed accessors live in `daos/settings_dao.dart`, so callers never see
/// the string encoding.
@DataClassName('SettingRow')
class Settings extends Table {
  /// The setting's stable identifier.
  ///
  /// Named `setting_key` rather than `key`, which is a SQLite keyword and would
  /// need quoting in every hand-written statement.
  TextColumn get settingKey => text()();

  /// The encoded value. Interpretation belongs to the DAO.
  TextColumn get settingValue => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{settingKey};
}
