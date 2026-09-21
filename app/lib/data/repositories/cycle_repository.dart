/// Cycle repository.
///
/// The boundary where "what the user typed" becomes "what the database
/// holds". The only place a write is rejected, and the place the derived
/// cycles are read from.
///
/// Includes:
///     - WriteRejection: Why a write was refused.
///     - WriteRefused: One refusal, with the offending dates.
///     - CycleRepository: Reads, writes and the rules over them.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/cycles/segmentation.dart';
import 'package:period_tracker/domain/cycles/validation.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// Write rejection: why a write was refused.
enum WriteRejection {
  /// A day already has a log and the caller asked to create, not replace.
  ///
  /// Never resolved by silently merging. Two entries for one day mean the
  /// caller has two different beliefs about that day, and picking one is the
  /// app deciding which of the user's statements to discard.
  dayAlreadyLogged,

  /// A range write would land on days that are already logged.
  overlapsExistingEntries,

  /// The same date appears twice in one batch.
  duplicateInBatch,

  /// The date is in the future.
  ///
  /// Nobody knows their period started tomorrow. A future-dated row is almost
  /// always a device clock that is wrong, and storing it poisons every later
  /// cycle length and makes the newest log look newer than "now".
  dateInFuture,

  /// The caller asked to edit a day that has no log.
  dayNotLogged,
}

/// Write refused: one refusal, specific enough to show the user.
///
/// `docs/PLAN.md` 5.5 requires overlapping or duplicate entries to be rejected
/// "with a specific message". A generic failure would leave the UI saying
/// something went wrong while the user stares at a calendar that looks fine,
/// so the offending dates travel with the refusal.
///
/// Attributes:
///     rejection (WriteRejection): Why the write was refused.
///     dates (`List<CivilDate>`): The dates that caused it, oldest first.
///     message (String): A message naming those dates.
@immutable
final class WriteRefused {
  /// Creates a refusal.
  ///
  /// Args:
  ///     rejection (WriteRejection): Why the write was refused.
  ///     dates (`List<CivilDate>`): The dates that caused it.
  ///     message (String): A message naming those dates.
  const WriteRefused(this.rejection, this.dates, this.message);

  /// Why the write was refused.
  final WriteRejection rejection;

  /// The dates that caused it, oldest first.
  final List<CivilDate> dates;

  /// A message naming those dates, suitable for showing to the user.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is WriteRefused &&
      other.rejection == rejection &&
      other.message == message &&
      other.dates.length == dates.length &&
      other.dates.every(dates.contains);

  @override
  int get hashCode => Object.hash(rejection, message, Object.hashAll(dates));

  @override
  String toString() => 'WriteRefused(${rejection.name}: $message)';
}

/// Cycle repository: reads and writes day logs, and derives the cycles.
///
/// The boundary where "what the user typed" becomes "what the database
/// holds", and deliberately the only place that rejects a write. Segmentation
/// downstream assumes it will never see two logs for one day, and returns
/// [DataInconsistency.duplicateDate] rather than guessing if it does; keeping
/// that promise is this class's job.
///
/// Attributes:
///     _db (AppDatabase): Where the logs are stored.
///     _clock (Clock): The app's one clock, which bounds every write.
///     _logger (RingLogger?): Records what happened, never what was logged.
class CycleRepository {
  /// Creates a repository over [database].
  ///
  /// Args:
  ///     database (AppDatabase): Where the logs are stored.
  ///     clock (Clock): The app's one clock.
  ///     logger (RingLogger?, optional): Records events. Defaults to null.
  CycleRepository({
    required AppDatabase database,
    required Clock clock,
    RingLogger? logger,
  }) : _db = database,
       // An initializing formal would have to be `this._clock` / `this._logger`
       // here, and Dart does not allow a named parameter to start with an
       // underscore.
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals, same reason as above
       _logger = logger;

  /// Where the logs are stored.
  final AppDatabase _db;

  /// The app's one clock, which bounds every write.
  final Clock _clock;

  /// Records what happened, never what was logged.
  final RingLogger? _logger;

  /// Read every logged day, oldest first.
  ///
  /// Returns:
  ///     `Future<List<DayLog>>`: Every day, oldest first.
  Future<List<DayLog>> logs() => _db.dayLogDao.allLogs();

  /// Watch every logged day.
  ///
  /// Returns:
  ///     `Stream<List<DayLog>>`: Re-emitted on any change.
  Stream<List<DayLog>> watchLogs() => _db.dayLogDao.watchAllLogs();

  /// Return today, according to the app's one clock.
  ///
  /// Exposed so that callers which need "now" do not acquire a second clock.
  /// `docs/PLAN.md` risk R7 is about dates disagreeing across layers, and two
  /// clocks in the data layer is the shape that produces it.
  ///
  /// Returns:
  ///     CivilDate: The local calendar day.
  CivilDate today() => _clock.today();

  /// Read the conditions recorded as active on one day.
  ///
  /// Reads only. Nothing here is passed to the prediction model; see
  /// ADR-0010, and the test that enforces it. The one thing this is used for
  /// is deciding whether to *withhold* a prediction, which changes what is
  /// shown and never what is computed.
  ///
  /// Args:
  ///     date (CivilDate): The day to test each span against.
  ///
  /// Returns:
  ///     `Future<List<ConditionRecord>>`: Those covering [date].
  Future<List<ConditionRecord>> activeConditionsOn(CivilDate date) async {
    final records = await _db.conditionDao.all();
    return records.where((record) => record.isActiveOn(date)).toList();
  }

  /// Read one day's log.
  ///
  /// Args:
  ///     date (CivilDate): The day to read.
  ///
  /// Returns:
  ///     `Future<DayLog?>`: The entry, or null if never logged.
  Future<DayLog?> logFor(CivilDate date) => _db.dayLogDao.logFor(date);

  /// Derive the user's cycles, oldest first, with validity assigned.
  ///
  /// Returns:
  ///     `Future<Result<List<CycleRecord>, DataInconsistency>>`: The cycles,
  ///     or an [Err] when the stored data contradicts itself. That should be
  ///     impossible given the write path above; it is surfaced rather than
  ///     swallowed because if it ever does happen, the honest response is to
  ///     ask the user to fix it, not to predict from data the app knows is
  ///     wrong.
  Future<Result<List<CycleRecord>, DataInconsistency>> cycles() async {
    final stored = await logs();
    return Segmentation.segment(stored).map(Validation.assign);
  }

  /// Whether the newest stored log is dated after today.
  ///
  /// The device clock moving backwards, or a timezone change across the date
  /// line, both show up this way. Detecting it matters because every cycle
  /// length is a difference between dates, so a clock that jumped would
  /// otherwise silently produce negative or absurd lengths (`docs/PLAN.md`
  /// 5.5).
  /// Returns:
  ///     `Future<bool>`: True when the newest stored log is dated after
  ///     today. False for an empty history.
  Future<bool> clockWentBackwards() async {
    final stored = await logs();
    if (stored.isEmpty) return false;
    final newest = stored.last.date;
    return newest > _clock.today();
  }

  /// Count the days since the most recent log.
  ///
  /// Returns:
  ///     `Future<int?>`: Days since the newest entry, or null when nothing
  ///     is logged.
  Future<int?> daysSinceLastLog() async {
    final stored = await logs();
    if (stored.isEmpty) return null;
    return stored.last.date.daysBetween(_clock.today());
  }

  /// Create a log for a day that has none.
  ///
  /// Refuses rather than overwriting. Use [replace] to change an existing day,
  /// so that "add" and "edit" are different intentions in the code as well as
  /// in the UI.
  ///
  /// Args:
  ///     log (DayLog): The day to create.
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Ok, or a refusal naming the
  ///     date when it is in the future or already logged.
  Future<Result<void, WriteRefused>> add(DayLog log) async {
    final future = _rejectFutureDates(<CivilDate>[log.date]);
    if (future != null) return Err<void, WriteRefused>(future);

    final existing = await _db.dayLogDao.existingDates(<CivilDate>[log.date]);
    if (existing.isNotEmpty) {
      return Err<void, WriteRefused>(
        WriteRefused(
          WriteRejection.dayAlreadyLogged,
          <CivilDate>[log.date],
          '${log.date.toIso8601()} is already logged. Edit that day instead of '
          'adding a second entry for it.',
        ),
      );
    }
    await _db.dayLogDao.save(log);
    _logger?.info(LogEvent.logEntryCreated);
    return const Ok<void, WriteRefused>(null);
  }

  /// Replace the log for a day that already has one.
  ///
  /// Args:
  ///     log (DayLog): The day to write, replacing what is stored.
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Ok, or a refusal naming the
  ///     date when it is in the future or has no entry to edit.
  Future<Result<void, WriteRefused>> replace(DayLog log) async {
    final future = _rejectFutureDates(<CivilDate>[log.date]);
    if (future != null) return Err<void, WriteRefused>(future);

    final existing = await _db.dayLogDao.existingDates(<CivilDate>[log.date]);
    if (existing.isEmpty) {
      return Err<void, WriteRefused>(
        WriteRefused(
          WriteRejection.dayNotLogged,
          <CivilDate>[log.date],
          '${log.date.toIso8601()} has no entry to edit.',
        ),
      );
    }
    await _db.dayLogDao.save(log);
    _logger?.info(LogEvent.logEntryEdited);
    return const Ok<void, WriteRefused>(null);
  }

  /// Create or replace the log for its own date, whichever applies.
  ///
  /// The one-tap path from the log screen, where the user has expressed an
  /// intention about a day and does not care whether a row already existed.
  ///
  /// Args:
  ///     log (DayLog): The day to write, replacing the stored day entirely.
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Ok, or a refusal when the date
  ///     is in the future.
  Future<Result<void, WriteRefused>> upsert(DayLog log) async {
    final future = _rejectFutureDates(<CivilDate>[log.date]);
    if (future != null) return Err<void, WriteRefused>(future);
    await _db.dayLogDao.save(log);
    _logger?.info(LogEvent.logEntryEdited);
    return const Ok<void, WriteRefused>(null);
  }

  /// Records [date] as a bleeding day, keeping whatever else is on that day.
  ///
  /// The one-tap paths, the log screen's primary button and the notification
  /// action, know the flow and nothing else. Handing [upsert] a bare [DayLog]
  /// for that silently erases the rest of the day, because a save replaces the
  /// whole day: everything recorded against a date is stored as one fact, so
  /// writing one field without the others deletes the others. Someone who
  /// logged cramps in the morning and taps "period started" in the afternoon
  /// must not lose the cramps, and would have no way of knowing they had.
  ///
  /// So the day is read first and rebuilt from what was there, changing the
  /// flow and nothing else. Every field [DayLog] gains has to be carried here.
  ///
  /// Args:
  ///     date (CivilDate): The day to mark.
  ///     flow (FlowIntensity, optional): What to record. Defaults to
  ///         [FlowIntensity.medium], which is what the one-tap paths mean.
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Ok, or a refusal when the date
  ///     is in the future.
  Future<Result<void, WriteRefused>> markPeriodStart(
    CivilDate date, {
    FlowIntensity flow = FlowIntensity.medium,
  }) async {
    final existing = await logFor(date);
    return upsert(
      (existing ?? DayLog(date: date)).copyWith(flow: flow),
    );
  }

  /// Write a whole batch, refusing if any day in it is already logged.
  ///
  /// All or nothing. A batch that half-applied would leave the user with a
  /// calendar they did not ask for and no way to tell which half is theirs.
  ///
  /// Args:
  ///     batch (`Iterable<DayLog>`): The days to create. An empty batch is
  ///         accepted and writes nothing.
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Ok, or the first refusal:
  ///     a duplicate within the batch, a future date, or a collision with a
  ///     day already logged.
  Future<Result<void, WriteRefused>> addAll(Iterable<DayLog> batch) async {
    final entries = batch.toList();
    if (entries.isEmpty) return const Ok<void, WriteRefused>(null);

    final seen = <CivilDate>{};
    final duplicates = <CivilDate>[];
    for (final entry in entries) {
      if (!seen.add(entry.date)) duplicates.add(entry.date);
    }
    if (duplicates.isNotEmpty) {
      return Err<void, WriteRefused>(
        WriteRefused(
          WriteRejection.duplicateInBatch,
          _sorted(duplicates),
          'The same day appears more than once in this batch: '
          '${_listDates(duplicates)}.',
        ),
      );
    }

    final future = _rejectFutureDates(entries.map((e) => e.date));
    if (future != null) return Err<void, WriteRefused>(future);

    final collisions = await _db.dayLogDao.existingDates(seen);
    if (collisions.isNotEmpty) {
      return Err<void, WriteRefused>(
        WriteRefused(
          WriteRejection.overlapsExistingEntries,
          _sorted(collisions),
          'These days are already logged: ${_listDates(collisions)}. Nothing '
          'was changed.',
        ),
      );
    }

    await _db.dayLogDao.saveAll(entries);
    _logger?.info(
      LogEvent.logEntryCreated,
      fields: <String, LogField>{'count': LogField.count(entries.length)},
    );
    return const Ok<void, WriteRefused>(null);
  }

  /// Log a run of bleeding days.
  ///
  /// The "my period lasted five days" gesture. Refuses if any day in the range
  /// is already logged, rather than merging over the user's existing entries.
  ///
  /// Args:
  ///     range (CivilDateRange): The days to log, inclusive at both ends.
  ///     flow (FlowIntensity, optional): What to record on each day.
  ///         Defaults to [FlowIntensity.medium].
  ///
  /// Returns:
  ///     `Future<Result<void, WriteRefused>>`: Whatever [addAll] returns.
  Future<Result<void, WriteRefused>> logPeriod(
    CivilDateRange range, {
    FlowIntensity flow = FlowIntensity.medium,
  }) => addAll(<DayLog>[
    for (var i = 0; i < range.lengthInDays; i++)
      DayLog(date: range.start.addDays(i), flow: flow),
  ]);

  /// Delete one day's log.
  ///
  /// Args:
  ///     date (CivilDate): The day to delete.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether anything was actually removed.
  Future<bool> deleteDay(CivilDate date) async {
    final removed = await _db.dayLogDao.deleteDay(date);
    if (removed) _logger?.info(LogEvent.logEntryDeleted);
    return removed;
  }

  /// Deletes every log, setting and cached prediction, and vacuums the file.
  Future<void> deleteEverything() async {
    await _db.dayLogDao.deleteEverything();
    // The ring is cleared before the deletion is recorded, so exactly one line
    // survives: that everything was deleted.
    //
    // Without this, "delete everything" left the whole trail behind: when
    // days were logged, when they were edited, when an export was taken, all
    // on a screen reachable from settings. The records carry counts rather
    // content, but the timestamps alone say when someone was using a period
    // tracker, which is the kind of thing this app spends the rest of its
    // design being careful about. A user who has just wiped their diary has
    // said as clearly as they can that they want it gone.
    //
    // The ring is memory-only and does not survive a restart, so this closes a
    // within-session gap rather than an on-disk one. That is still the gap
    // that matters: the session someone deletes in is the session someone
    // might be looking over their shoulder.
    _logger?.clear();
    _logger?.warn(LogEvent.allDataDeleted);
  }

  /// Refuse any date that has not happened yet.
  ///
  /// Args:
  ///     dates (`Iterable<CivilDate>`): The dates a write is about to touch.
  ///
  /// Returns:
  ///     WriteRefused?: A refusal naming every future date, or null when they
  ///     are all today or earlier.
  WriteRefused? _rejectFutureDates(Iterable<CivilDate> dates) {
    final today = _clock.today();
    final future = dates.where((d) => d > today).toList();
    if (future.isEmpty) return null;
    return WriteRefused(
      WriteRejection.dateInFuture,
      _sorted(future),
      'These days are in the future: ${_listDates(future)}. If that looks '
      "wrong, check the device's date.",
    );
  }

  /// Sort dates oldest first, so a refusal reads in calendar order.
  ///
  /// Args:
  ///     dates (`Iterable<CivilDate>`): The dates to sort.
  ///
  /// Returns:
  ///     `List<CivilDate>`: A new sorted list.
  static List<CivilDate> _sorted(Iterable<CivilDate> dates) =>
      dates.toList()..sort();

  /// Render dates as a comma-separated list for a refusal message.
  ///
  /// Args:
  ///     dates (`Iterable<CivilDate>`): The dates to name.
  ///
  /// Returns:
  ///     String: The dates in `YYYY-MM-DD` form, oldest first.
  static String _listDates(Iterable<CivilDate> dates) =>
      _sorted(dates).map((d) => d.toIso8601()).join(', ');
}
