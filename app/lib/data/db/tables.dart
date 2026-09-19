/// Database schema.
///
/// Declares every table the app stores, and the choices that make the schema
/// safe to change: enums stored by name rather than by ordinal, calendar days
/// as integer keys rather than timestamps, and preferences in a key-value
/// table so adding one is not a migration.
///
/// Includes:
///     - DayLogs: The only source of truth, one row per recorded day.
///     - Symptoms: Severities, normalised out of DayLogs.
///     - Conditions: Long-term conditions, over the spans they applied to.
///     - ModelStates: The cached posterior and prediction.
///     - Settings: User preferences, as a typed key-value store.
library;

import 'package:drift/drift.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Day logs: every calendar day the user has recorded something for.
///
/// This table is the **only** source of truth in the app. Cycles, statistics
/// and predictions are all derived from an ordered list of these rows, which
/// is why export and import deal in day logs alone (`docs/PLAN.md` 4.1).
/// Nothing derived is stored: a second copy of a fact is a second thing that
/// can be wrong.
///
/// Two schema choices here are load-bearing rather than stylistic.
///
/// **The primary key is the calendar day**, stored as [epochDay], the number
/// of days since 1970-01-01. Not a surrogate id, not a timestamp. A user has
/// at most one log per day by definition, so making that a database constraint
/// means a duplicate date cannot be created even by a bug elsewhere, and the
/// integer arithmetic is exact and timezone-free (risk R7).
///
/// **Enums are stored by name, not by index.** `intEnum` would write the
/// ordinal, so reordering the members of [FlowIntensity] in a later release
/// would silently reinterpret every stored row: heavy becomes light with no
/// error anywhere. Storing the name costs a few bytes and makes that class of
/// mistake impossible. It also leaves the database readable in a plain
/// `sqlite3` dump, which matters when the user's only recovery path is their
/// own export.
@DataClassName('DayLogRow')
class DayLogs extends Table {
  /// Days since 1970-01-01. The calendar day this row describes.
  IntColumn get epochDay => integer()();

  /// How heavy bleeding was, by [FlowIntensity] name.
  TextColumn get flow => textEnum<FlowIntensity>()();

  /// Whether intercourse was recorded, and whether it was protected (AND-30).
  ///
  /// Nullable, and null means *not recorded*, which is not the same as a
  /// recorded "no". [Intercourse] has no "none" member for exactly this
  /// reason: a user who logs nothing has said nothing.
  ///
  /// The most sensitive column in this database. Nothing in
  /// `lib/domain/predict/` may read it (assumption A5), and
  /// `intercourse_isolation_test.dart` fails the build if anything does.
  TextColumn get intercourse => textEnum<Intercourse>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{epochDay};
}

/// Symptoms: severities recorded against a day.
///
/// Normalised out of [DayLogs] rather than serialised into a column, so that a
/// symptom is a row the database can constrain: one severity per symptom per
/// day, enforced by the primary key, and deleted automatically with its day.
///
/// The cascade is not decorative. It is what makes "delete this day" a single
/// statement that cannot leave orphaned symptom rows behind, and orphaned rows
/// carrying health data would survive a deletion the user believed was
/// complete. Foreign keys are off by default in SQLite, so the connection
/// turns them on explicitly; see `connection.dart`.
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

/// Conditions: long-term conditions and medications, over their spans.
///
/// A surrogate id rather than a natural key, because the same condition can
/// legitimately appear more than once over a life: someone can start the pill,
/// stop, and start again years later, and both spans are true. Keying on the
/// condition alone would force the second one to overwrite the first and take
/// the interpretation of those older cycles with it.
///
/// [endEpochDay] is null while the condition is still running. Ending one
/// sets the date rather than deleting the row, so the history of what was true
/// when survives. That is the entire reason this table stores spans instead of
/// a set of flags.
///
/// Nothing here reaches the prediction model. See [Condition] and ADR-0010.
@DataClassName('ConditionRow')
class Conditions extends Table {
  /// Row identity, assigned by SQLite.
  IntColumn get id => integer().autoIncrement()();

  /// Which condition, by [Condition] name.
  TextColumn get condition => textEnum<Condition>()();

  /// Days since 1970-01-01. The first day this applied.
  IntColumn get startEpochDay => integer()();

  /// Days since 1970-01-01, or null while it is still running.
  IntColumn get endEpochDay => integer().nullable()();
}

/// Model states: the cached posterior and prediction.
///
/// A single row, always with [id] zero. This is a cache and nothing else: every
/// value in it is recomputable from [DayLogs] plus the shipped priors, so
/// losing it costs a few milliseconds and never costs data. It exists because
/// the filter runs on every calendar repaint otherwise.
///
/// [inputSignature] is what makes the cache correct. It covers the whole input
/// to the computation, so a backdated edit to any past day changes it and the
/// cached row stops matching. See `PredictionRepository`.
@DataClassName('ModelStateRow')
class ModelStates extends Table {
  /// Always zero. There is one posterior per user and one user per device.
  IntColumn get id => integer()();

  /// Canonical description of everything the prediction was computed from.
  ///
  /// Stored in full rather than digested. A digest would be shorter and would
  /// introduce a collision, however unlikely, whose symptom is a stale
  /// prediction after an edit: the exact bug this column exists to prevent.
  /// The full signature is a few hundred bytes even for a decade of cycles.
  TextColumn get inputSignature => text()();

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

/// Settings: user preferences, as a typed key-value store.
///
/// Key-value rather than one column per setting, so adding a preference is not
/// a schema migration. Migrations on this table would be pure risk: every one
/// is a chance to lose the tables that actually hold data, and a preference is
/// the one thing in the database that can be safely defaulted if it goes
/// missing.
/// The typed accessors live in `daos/settings_dao.dart`, so callers never see
/// the string encoding.
@DataClassName('SettingRow')
class Settings extends Table {
  /// The setting's stable identifier.
  ///
  /// Named `setting_key` rather than `key`, which is a SQLite keyword and
  /// would need quoting in every hand-written statement.
  TextColumn get settingKey => text()();

  /// The encoded value. Interpretation belongs to the DAO.
  TextColumn get settingValue => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{settingKey};
}
