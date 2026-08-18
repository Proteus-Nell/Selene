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

/// The closed vocabulary of loggable events.
///
/// Event names are an enum, not a [String], and this is the load-bearing design
/// decision in this file. A `String` event name allows
/// `log.info('period_started_$date')`, which would write cycle data to disk. An
/// enum makes that impossible to express. See `docs/PLAN.md` 5.5 and 6.5.
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

/// A single structured field value attached to a [LogRecord].
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
  // Positional is right here: the constructor name already carries the meaning,
  // so `LogField.flag(false)` reads better than `LogField.flag(value: false)`.
  // ignore: avoid_positional_boolean_parameters
  const factory LogField.flag(bool value) = FlagField;

  /// An enum member, such as a confidence class or a prediction state.
  const factory LogField.state(Enum value) = StateField;

  /// The JSON-encodable form of this field.
  Object get encoded;
}

/// A [LogField] holding a count.
@immutable
final class CountField extends LogField {
  /// Wraps [value].
  const CountField(this.value);

  /// The count.
  final int value;

  @override
  Object get encoded => value;
}

/// A [LogField] holding a duration in milliseconds.
@immutable
final class MillisField extends LogField {
  /// Wraps [value].
  const MillisField(this.value);

  /// The duration in whole milliseconds.
  final int value;

  @override
  Object get encoded => value;
}

/// A [LogField] holding a boolean.
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

/// A [LogField] holding an enum member.
@immutable
final class StateField extends LogField {
  /// Wraps [value].
  const StateField(this.value);

  /// The enum member.
  final Enum value;

  @override
  Object get encoded => value.name;
}

/// One structured log entry.
@immutable
final class LogRecord {
  /// Creates a record.
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

  /// A single-line JSON encoding, suitable for a file sink or the log viewer.
  String toJsonLine() => jsonEncode(<String, Object>{
    'ts': timestampUtc.toIso8601String(),
    'level': level.name,
    'event': event.name,
    for (final entry in fields.entries) entry.key: entry.value.encoded,
  });

  @override
  String toString() => toJsonLine();
}

/// An in-memory, fixed-capacity logger.
///
/// Records are held in a ring buffer and the oldest are dropped once
/// [capacity] is reached, so logging can never grow without bound. Nothing is
/// transmitted anywhere: there is no network permission in this app at all
/// (`DECISIONS.md` ADR-0004). The buffer exists so that the Settings screen can
/// show the user exactly what is recorded, and so they can clear it.
final class RingLogger {
  /// Creates a logger that timestamps records using [clock].
  RingLogger({required this.clock, this.capacity = 500})
    : assert(capacity > 0, 'capacity must be positive');

  /// Source of record timestamps. Public so it can satisfy an initializing
  /// formal, and harmless to expose: it is an injected dependency, not state.
  final Clock clock;

  final Queue<LogRecord> _records = Queue<LogRecord>();

  /// Maximum number of records retained.
  final int capacity;

  /// Whether debug-level records are retained. Off in release builds.
  bool retainDebug = false;

  /// The retained records, oldest first.
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// Number of retained records.
  int get length => _records.length;

  /// Records a debug event.
  void debug(LogEvent event, {Map<String, LogField> fields = const {}}) {
    if (!retainDebug) return;
    _add(LogLevel.debug, event, fields);
  }

  /// Records an informational event.
  void info(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.info, event, fields);

  /// Records a warning.
  void warn(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.warn, event, fields);

  /// Records an error.
  void error(LogEvent event, {Map<String, LogField> fields = const {}}) =>
      _add(LogLevel.error, event, fields);

  /// Discards every retained record.
  void clear() => _records.clear();

  /// All retained records as newline-delimited JSON.
  String dump() => _records.map((r) => r.toJsonLine()).join('\n');

  void _add(LogLevel level, LogEvent event, Map<String, LogField> fields) {
    _records.add(
      LogRecord(
        level: level,
        event: event,
        timestampUtc: clock.nowUtc(),
        fields: Map<String, LogField>.unmodifiable(fields),
      ),
    );
    while (_records.length > capacity) {
      _records.removeFirst();
    }
  }
}
