import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/cycles/segmentation.dart';
import 'package:period_tracker/domain/cycles/validation.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// Why a write was refused.
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

/// A refused write, with a message specific enough to show the user.
///
/// `docs/PLAN.md` 5.5 requires overlapping or duplicate entries to be rejected
/// "with a specific message". A generic failure would leave the UI saying
/// something went wrong while the user stares at a calendar that looks fine, so
/// the offending dates travel with the refusal.
@immutable
final class WriteRefused {
  /// Creates a refusal.
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

/// Reads and writes day logs, and exposes the cycles derived from them.
///
/// The repository is the boundary where "what the user typed" becomes "what the
/// database holds", and it is deliberately the only place that rejects a write.
/// Segmentation downstream assumes it will never see two logs for one day, and
/// it returns [DataInconsistency.duplicateDate] rather than guessing if it
/// does; keeping that promise is this class's job.
class CycleRepository {
  /// Creates a repository over [database].
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

  final AppDatabase _db;
  final Clock _clock;
  final RingLogger? _logger;

  /// Every logged day, oldest first.
  Future<List<DayLog>> logs() => _db.dayLogDao.allLogs();

  /// Every logged day, re-emitted on any change.
  Stream<List<DayLog>> watchLogs() => _db.dayLogDao.watchAllLogs();

  /// The log for [date], or null.
  Future<DayLog?> logFor(CivilDate date) => _db.dayLogDao.logFor(date);

  /// The user's cycles, oldest first, with validity already assigned.
  ///
  /// Returns [Err] only when the stored data contradicts itself, which should
  /// be impossible given the write path above. It is surfaced rather than
  /// swallowed because if it ever does happen, the honest response is to ask
  /// the user to fix it, not to predict from data the app knows is wrong.
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
  Future<bool> clockWentBackwards() async {
    final stored = await logs();
    if (stored.isEmpty) return false;
    final newest = stored.last.date;
    return newest > _clock.today();
  }

  /// Days since the most recent log, or null when nothing is logged.
  Future<int?> daysSinceLastLog() async {
    final stored = await logs();
    if (stored.isEmpty) return null;
    return stored.last.date.daysBetween(_clock.today());
  }

  /// Creates a log for a day that has none.
  ///
  /// Refuses rather than overwriting. Use [replace] to change an existing day,
  /// so that "add" and "edit" are different intentions in the code as well as
  /// in the UI.
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

  /// Replaces the log for a day that already has one.
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

  /// Creates or replaces the log for its own date, whichever applies.
  ///
  /// The one-tap path from the log screen, where the user has expressed an
  /// intention about a day and does not care whether a row already existed.
  Future<Result<void, WriteRefused>> upsert(DayLog log) async {
    final future = _rejectFutureDates(<CivilDate>[log.date]);
    if (future != null) return Err<void, WriteRefused>(future);
    await _db.dayLogDao.save(log);
    _logger?.info(LogEvent.logEntryEdited);
    return const Ok<void, WriteRefused>(null);
  }

  /// Records [date] as a bleeding day, keeping whatever else is on that day.
  ///
  /// The one-tap paths — the log screen's primary button and the notification
  /// action — know the flow and nothing else. Handing [upsert] a bare [DayLog]
  /// for that silently erases the day's symptoms, because a save replaces the
  /// whole day: flow and symptoms are stored as one fact, so writing one
  /// without the other deletes the other. Someone who logged cramps in the
  /// morning and taps "period started" in the afternoon must not lose the
  /// cramps, and would have no way of knowing they had.
  Future<Result<void, WriteRefused>> markPeriodStart(
    CivilDate date, {
    FlowIntensity flow = FlowIntensity.medium,
  }) async {
    final existing = await logFor(date);
    return upsert(
      DayLog(
        date: date,
        flow: flow,
        symptoms: existing?.symptoms ?? const <Symptom, SymptomSeverity>{},
      ),
    );
  }

  /// Writes a whole batch, refusing if any day in it is already logged.
  ///
  /// All or nothing. A batch that half-applied would leave the user with a
  /// calendar they did not ask for and no way to tell which half is theirs.
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

  /// Logs a run of bleeding days from [range], at [flow].
  ///
  /// The "my period lasted five days" gesture. Refuses if any day in the range
  /// is already logged, rather than merging over the user's existing entries.
  Future<Result<void, WriteRefused>> logPeriod(
    CivilDateRange range, {
    FlowIntensity flow = FlowIntensity.medium,
  }) => addAll(<DayLog>[
    for (var i = 0; i < range.lengthInDays; i++)
      DayLog(date: range.start.addDays(i), flow: flow),
  ]);

  /// Deletes the log for [date]. Returns whether anything was removed.
  Future<bool> deleteDay(CivilDate date) async {
    final removed = await _db.dayLogDao.deleteDay(date);
    if (removed) _logger?.info(LogEvent.logEntryDeleted);
    return removed;
  }

  /// Deletes every log, setting and cached prediction, and vacuums the file.
  Future<void> deleteEverything() async {
    await _db.dayLogDao.deleteEverything();
    _logger?.warn(LogEvent.allDataDeleted);
  }

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

  static List<CivilDate> _sorted(Iterable<CivilDate> dates) =>
      dates.toList()..sort();

  static String _listDates(Iterable<CivilDate> dates) =>
      _sorted(dates).map((d) => d.toIso8601()).join(', ');
}
