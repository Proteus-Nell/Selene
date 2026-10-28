/// Structured in-memory logging.
///
/// Records what the app did, in a vocabulary that cannot express what the user
/// recorded. Event names are an enum and field values are a closed set of
/// wrapper types, so a date, a flow level or a symptom has no representation
/// here at all. Nothing written through this file leaves the device: the app
/// holds no network permission (`DECISIONS.md` ADR-0004), and the buffer
/// exists so Settings can show the user the whole trail and let them clear it.
///
/// Includes:
///     - LogLevel: Severity of one record.
///     - LogEvent: The closed vocabulary of things worth recording.
///     - LogField: Sealed field value, with CountField, MillisField,
///       FlagField and StateField as its only cases.
///     - LogRecord: One entry, encodable as a single JSON line.
///     - RingLogger: Fixed-capacity buffer that drops the oldest first.
library;

import 'dart:collection';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';

/// Severity of a [LogRecord].
enum LogLevel {
  /// Verbose detail, off in release.
  debug,

  /// Normal lifecycle events.
  info,

  /// Something recoverable that a user might notice.
  warn,

  /// A failure worth investigating.
  error,
}

/// Log event: the closed vocabulary of loggable things.
///
/// Event names are an enum, not a [String], and this is the load-bearing
/// design decision in this file. A `String` event name allows
/// `log.info('period_started_$date')`, which would write cycle data to disk.
/// An enum makes that impossible to express. See `docs/PLAN.md` 5.5 and 6.5.
///
/// Add new members here as features land. Never add one whose name encodes a
/// value rather than an event.
enum LogEvent {
  /// App process started.
  appStarted,

  /// Database opened successfully.
  dbOpened,

  /// A schema migration ran.
  dbMigrated,

  /// The database failed to open and was quarantined.
  dbCorruptionDetected,

  /// A database written before encryption was encrypted in place.
  dbEncrypted,

  /// The key store could not be read, so the database was not opened.
  dbKeyUnavailable,

  /// Day logs were re-segmented into cycles.
  cyclesSegmented,

  /// An implausible cycle was flagged by validation.
  cycleFlaggedImplausible,

  /// A prediction was computed from scratch.
  predictionComputed,

  /// A cached prediction was reused.
  predictionCacheHit,

  /// The cached prediction was invalidated by an edit.
  predictionInvalidated,

  /// The per-user hyperparameter refit ran.
  personalizationRefit,

  /// A day log was created.
  logEntryCreated,

  /// A day log was edited.
  logEntryEdited,

  /// A day log was deleted.
  logEntryDeleted,

  /// All user data was deleted.
  allDataDeleted,

  /// An export file was written.
  exportWritten,

  /// An import completed.
  importCompleted,

  /// An import was rejected before touching the database.
  importRejected,

  /// A local notification was scheduled.
  notificationScheduled,

  /// A local notification was cancelled.
  notificationCancelled,

  /// A scheduled notification appears to have been missed.
  notificationMissed,

  /// The notification permission request resolved.
  notificationPermissionResolved,

  /// The device clock appears to have moved backwards.
  clockWentBackwards,
}

/// Log field: one structured value attached to a [LogRecord].
///
/// The constructors accept counts, durations, flags and enum states only.
/// There is deliberately no way to put a [String], a [DateTime] or a
/// `CivilDate` into a log record. Together with [LogEvent] this makes it
/// structurally impossible to log a date, a flow level or a symptom, rather
/// than merely discouraged by review.
@immutable
sealed class LogField {
  /// Const constructor for subclasses.
  const LogField();

  /// A plain count, such as a number of cycles.
  const factory LogField.count(int value) = CountField;

  /// A duration in whole milliseconds.
  const factory LogField.millis(int value) = MillisField;

  /// A boolean flag.
  //
  // Positional is right here: the constructor name already carries the
  // meaning, so `LogField.flag(false)` reads better than
  // `LogField.flag(value: false)`.
  // ignore: avoid_positional_boolean_parameters
  const factory LogField.flag(bool value) = FlagField;

  /// An enum member, such as a confidence class or a prediction state.
  const factory LogField.state(Enum value) = StateField;

  /// The JSON-encodable form of this field.
  Object get encoded;
}

/// Count field: a [LogField] holding a whole number.
///
/// Attributes:
///     value (int): The count.
@immutable
final class CountField extends LogField {
  /// Wraps [value].
  const CountField(this.value);

  /// The count.
  final int value;

  @override
  Object get encoded => value;
}

/// Millis field: a [LogField] holding a duration.
///
/// Attributes:
///     value (int): The duration, in whole milliseconds.
@immutable
final class MillisField extends LogField {
  /// Wraps [value].
  const MillisField(this.value);

  /// The duration in whole milliseconds.
  final int value;

  @override
  Object get encoded => value;
}

/// Flag field: a [LogField] holding a boolean.
///
/// Attributes:
///     value (bool): The flag.
@immutable
final class FlagField extends LogField {
  /// Wraps [value].
  // ignore: avoid_positional_boolean_parameters
  const FlagField(this.value);

  /// The flag.
  final bool value;

  @override
  Object get encoded => value;
}

/// State field: a [LogField] holding one enum member.
///
/// Encoded by name, so the record stays readable without the Dart type.
///
/// Attributes:
///     value (Enum): The enum member.
@immutable
final class StateField extends LogField {
  /// Wraps [value].
  const StateField(this.value);

  /// The enum member.
  final Enum value;

  @override
  Object get encoded => value.name;
}

/// Log record: one structured entry.
///
/// Attributes:
///     level (LogLevel): Severity.
///     event (LogEvent): What happened.
///     timestampUtc (DateTime): When it happened, in UTC.
///     fields (`Map<String, LogField>`): Structured detail, empty by
///         default. Never contains user content, by construction.
@immutable
final class LogRecord {
  /// Creates a record.
  ///
  /// Args:
  ///     level (LogLevel): Severity.
  ///     event (LogEvent): What happened.
  ///     timestampUtc (DateTime): When it happened, in UTC.
  ///     fields (`Map<String, LogField>`, optional): Structured detail.
  ///         Defaults to empty.
  const LogRecord({
    required this.level,
    required this.event,
    required this.timestampUtc,
    this.fields = const <String, LogField>{},
  });

  /// Severity.
  final LogLevel level;

  /// What happened.
  final LogEvent event;

  /// When it happened, in UTC.
  final DateTime timestampUtc;

  /// Structured detail. Never contains user content, by construction.
  final Map<String, LogField> fields;

  /// Encode this record as one line of JSON.
  ///
  /// Suitable for a file sink or the in-app log viewer.
  ///
  /// Returns:
  ///     String: A JSON object with `ts`, `level`, `event`, and one key per
  ///     field.
  String toJsonLine() => jsonEncode(<String, Object>{
    'ts': timestampUtc.toIso8601String(),
    'level': level.name,
    'event': event.name,
    for (final entry in fields.entries) entry.key: entry.value.encoded,
  });

  @override
  String toString() => toJsonLine();
}

/// Ring logger: an in-memory, fixed-capacity logger.
///
/// Records are held in a ring buffer and the oldest are dropped once
/// [capacity] is reached, so logging can never grow without bound. Nothing is
/// transmitted anywhere: there is no network permission in this app at all
/// (`DECISIONS.md` ADR-0004). The buffer exists so that the Settings screen
/// can show the user exactly what is recorded, and so they can clear it.
///
/// Attributes:
///     clock (Clock): Source of record timestamps.
///     capacity (int): Maximum records retained before the oldest is dropped.
///     retainDebug (bool): Whether debug records are kept. Off in release.
///     _records (`Queue<LogRecord>`): The buffer itself, oldest first.
final class RingLogger {
  /// Creates a logger that timestamps records using [clock].
  ///
  /// Args:
  ///     clock (Clock): Source of record timestamps.
  ///     capacity (int, optional): Maximum records retained. Defaults to 500.
  ///         Must be positive.
  RingLogger({required this.clock, this.capacity = 500})
    : assert(capacity > 0, 'capacity must be positive');

  /// Source of record timestamps. Public so it can satisfy an initializing
  /// formal, and harmless to expose: it is an injected dependency, not state.
  final Clock clock;

  /// The buffer. Oldest first; trimmed from the front once full.
  final Queue<LogRecord> _records = Queue<LogRecord>();

  /// Maximum number of records retained.
  final int capacity;

  /// Whether debug-level records are retained. Off in release builds.
  bool retainDebug = false;

  /// The retained records, oldest first.
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// Number of retained records.
  int get length => _records.length;

  /// Record a debug event, unless [retainDebug] is off.
  ///
  /// Args:
  ///     event (LogEvent): What happened.
  ///     fields (`Map<String, LogField>`, optional): Structured detail.
  ///         Defaults to empty.
  void debug(LogEvent event, {Map<String, LogField> fields = const {}}) {
    if (!retainDebug) return;
    _add(LogLevel.debug, event, fields);
  }

  /// Record an informational event.
  ///
  /// Args:
  ///     event (LogEvent): What happened.
  ///     fields (`Map<String, LogField>`, optional): Structured detail.
  ///         Defaults to empty.
  void info(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.info, event, fields);

  /// Record a warning.
  ///
  /// Args:
  ///     event (LogEvent): What happened.
  ///     fields (`Map<String, LogField>`, optional): Structured detail.
  ///         Defaults to empty.
  void warn(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.warn, event, fields);

  /// Record an error.
  ///
  /// Args:
  ///     event (LogEvent): What happened.
  ///     fields (`Map<String, LogField>`, optional): Structured detail.
  ///         Defaults to empty.
  void error(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.error, event, fields);

  /// Discard every retained record.
  void clear() => _records.clear();

  /// Render every retained record as newline-delimited JSON.
  ///
  /// Returns:
  ///     String: One [LogRecord.toJsonLine] per record, oldest first.
  String dump() => _records.map((r) => r.toJsonLine()).join('\n');

  /// Append one record and trim the buffer back to [capacity].
  ///
  /// Args:
  ///     level (LogLevel): Severity.
  ///     event (LogEvent): What happened.
  ///     fields (`Map<String, LogField>`): Structured detail. Copied
  ///         unmodifiable, so a caller cannot mutate a stored record.
  void _add(LogLevel level, LogEvent event, Map<String, LogField> fields) {
    _records.add(
      LogRecord(
        level: level,
        event: event,
        timestampUtc: clock.nowUtc(),
        fields: Map<String, LogField>.unmodifiable(fields),
      ),
    );
    // Drop the oldest first, so the newest events always survive.
    while (_records.length > capacity) {
      _records.removeFirst();
    }
  }
}
