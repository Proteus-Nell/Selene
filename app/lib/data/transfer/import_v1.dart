import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Why an import was refused.
///
/// Every one of these is refused **before** the database is touched. There is
/// no partial import: a half-restored backup leaves the user unable to tell
/// which half is theirs, and unable to try again from a known state.
enum ImportRejection {
  /// The file is not valid JSON.
  notJson,

  /// The file is JSON but not an export envelope.
  notAnEnvelope,

  /// A required field is missing or the wrong type.
  malformedField,

  /// The envelope version is newer than this build understands.
  writtenByNewerVersion,

  /// The envelope version is one this build no longer reads.
  unsupportedVersion,

  /// The envelope's shape is not the one this version writes.
  unexpectedShape,

  /// A day log carries a value this build does not know, such as a symptom
  /// added in a later release.
  unknownValue,

  /// A date is not a strict `YYYY-MM-DD` calendar date.
  invalidDate,

  /// Two day logs claim the same date.
  duplicateDate,
}

/// A refused import, with a message meant to be shown to the user.
@immutable
final class ImportRefused {
  /// Creates a refusal.
  const ImportRefused(this.rejection, this.message);

  /// Why it was refused.
  final ImportRejection rejection;

  /// A specific, non-technical explanation.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ImportRefused &&
      other.rejection == rejection &&
      other.message == message;

  @override
  int get hashCode => Object.hash(rejection, message);

  @override
  String toString() => 'ImportRefused(${rejection.name}: $message)';
}

/// What a completed import restored.
@immutable
final class ImportSummary {
  /// Creates a summary.
  const ImportSummary({
    required this.dayLogsRestored,
    required this.settingsRestored,
    required this.exportedUtc,
    required this.writtenByAppVersion,
  });

  /// How many days were restored.
  final int dayLogsRestored;

  /// How many preferences were restored.
  final int settingsRestored;

  /// When the file was originally exported.
  final DateTime exportedUtc;

  /// Which app version wrote it.
  final String writtenByAppVersion;

  @override
  String toString() =>
      'ImportSummary($dayLogsRestored logs, $settingsRestored settings, '
      'from $writtenByAppVersion at ${exportedUtc.toIso8601String()})';
}

/// Restores a database from an export file.
///
/// Two rules govern everything here, both from `docs/PLAN.md` 5.5 and risk R8.
///
/// **Validate completely before writing anything.** [inspect] does the entire
/// parse and check with no database access at all, and [restore] refuses on its
/// result before opening a transaction. A file that fails on its last day log
/// therefore leaves the database exactly as it was.
///
/// **Refuse rather than guess.** A file from a newer build may use fields or
/// values this one would misread, and a half-understood restore of a health
/// diary is worse than no restore: the user would not know which entries were
/// dropped.
abstract final class ImportV1 {
  /// Envelope versions this build can read.
  ///
  /// **Only the current version is here** (ADR-0011). Each bump strands every
  /// backup taken before it, and this is now the second bump in one release
  /// cycle. Reading an older file would cost a few lines of branching; that was
  /// offered and declined, and the cost was stated before the choice was made. The refusal message
  /// below therefore has to be specific enough that a user meeting it
  /// understands what happened rather than concluding the app is broken.
  ///
  /// This is the line a future session is most likely to "fix" without reading
  /// why it is here. Read the ADR first.
  static const Set<int> supportedVersions = <int>{3};

  /// Parses and validates [text] without touching the database.
  ///
  /// Exposed separately so the UI can show what a file contains, and when it
  /// was taken, before the user commits to replacing what they have.
  static Result<ExportEnvelope, ImportRefused> inspect(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      return Err<ExportEnvelope, ImportRefused>(
        ImportRefused(
          ImportRejection.notJson,
          'This file is not a Period-Tracker export: it is not valid JSON '
          '(${e.message}).',
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return const Err<ExportEnvelope, ImportRefused>(
        ImportRefused(
          ImportRejection.notAnEnvelope,
          'This file is not a Period-Tracker export.',
        ),
      );
    }

    try {
      final schemaVersion = _requireInt(decoded, 'schema_version');
      if (schemaVersion > exportSchemaVersion) {
        throw _Refusal(
          ImportRejection.writtenByNewerVersion,
          'This backup was written by a newer version of the app (export '
          'format v$schemaVersion; this build reads v$exportSchemaVersion). '
          'Update the app, then import it again. Nothing has been changed.',
        );
      }
      if (!supportedVersions.contains(schemaVersion)) {
        // Named specifically rather than generically, because whoever meets
        // this message has just been told their only backup is unusable and
        // deserves to know exactly why, and what still works. "Something went
        // wrong" here would be the app losing their history without explaining
        // itself. See ADR-0011 for why this refusal exists at all.
        throw _Refusal(
          ImportRejection.unsupportedVersion,
          'This backup is in the older export format (v$schemaVersion). This '
          'version of the app reads format v$exportSchemaVersion only and '
          'cannot restore the older one. Nothing has been changed. If you '
          'still have the device or app version that wrote this file, export '
          'again from there. The file is plain text either way: your logged '
          'days are readable in it with any text editor.',
        );
      }

      final fingerprint = _requireString(decoded, 'schema_fingerprint');
      if (fingerprint != exportSchemaFingerprint) {
        throw const _Refusal(
          ImportRejection.unexpectedShape,
          'This backup does not have the shape this version expects, even '
          'though it claims the same format version. It may have been edited '
          'by hand. Nothing has been changed.',
        );
      }

      final exportedUtc = DateTime.tryParse(
        _requireString(decoded, 'exported_utc'),
      );
      if (exportedUtc == null) {
        throw const _Refusal(
          ImportRejection.malformedField,
          'The export date in this backup is not readable.',
        );
      }

      final logs = _parseDayLogs(decoded);
      final settings = _parseSettings(decoded);
      final conditions = _parseConditions(decoded);

      return Ok<ExportEnvelope, ImportRefused>(
        ExportEnvelope(
          schemaVersion: schemaVersion,
          appVersion: _requireString(decoded, 'app_version'),
          databaseSchemaVersion: _requireInt(decoded, 'db_schema_version'),
          schemaFingerprint: fingerprint,
          exportedUtc: exportedUtc,
          dayLogs: logs,
          settings: settings,
          conditions: conditions,
        ),
      );
    } on _Refusal catch (e) {
      return Err<ExportEnvelope, ImportRefused>(
        ImportRefused(e.rejection, e.message),
      );
    }
  }

  /// Reads, validates and restores [file] into [database].
  ///
  /// **Replaces** everything: a backup is a snapshot of the whole diary, and
  /// merging two snapshots would invent a history that never existed, with no
  /// way to express a day the user had deleted. The caller is expected to have
  /// confirmed that with the user first.
  ///
  /// All of it happens in one transaction, so a failure part way through leaves
  /// the previous data intact.
  static Future<Result<ImportSummary, ImportRefused>> restoreFile(
    File file, {
    required AppDatabase database,
    RingLogger? logger,
  }) async {
    final String text;
    try {
      text = await file.readAsString();
    } on FileSystemException catch (e) {
      return Err<ImportSummary, ImportRefused>(
        ImportRefused(
          ImportRejection.notJson,
          'This file could not be read (${e.osError?.message ?? e.message}).',
        ),
      );
    }
    return restore(text, database: database, logger: logger);
  }

  /// Restores from already-read [text]. See [restoreFile].
  static Future<Result<ImportSummary, ImportRefused>> restore(
    String text, {
    required AppDatabase database,
    RingLogger? logger,
  }) async {
    final inspected = inspect(text);
    if (inspected.isErr) {
      logger?.warn(LogEvent.importRejected);
      return Err<ImportSummary, ImportRefused>(inspected.errorOrNull!);
    }
    final envelope = inspected.valueOrNull!;

    await database.transaction(() async {
      // The cached prediction describes data that is about to stop existing.
      await database.customStatement('DELETE FROM model_states');
      await database.delete(database.symptoms).go();
      await database.delete(database.dayLogs).go();
      await database.delete(database.conditions).go();
      await database.dayLogDao.saveAll(envelope.dayLogs);
      await database.settingsDao.replaceAll(envelope.settings);
      for (final record in envelope.conditions) {
        // Written through the DAO so the row gets a fresh id. The exported file
        // carries no id, and inventing one here would be the only place in the
        // app where a surrogate key crossed a database boundary.
        await database.conditionDao.add(
          condition: record.condition,
          start: record.start,
          end: record.end,
        );
      }
    });
    // Outside the transaction, because VACUUM cannot run inside one. The
    // replaced rows are health data, so their pages are reclaimed rather than
    // left legible in the file's free space (`docs/PLAN.md` 6.5).
    await database.customStatement('VACUUM');

    logger?.info(
      LogEvent.importCompleted,
      fields: <String, LogField>{
        'day_logs': LogField.count(envelope.dayLogs.length),
        'settings': LogField.count(envelope.settings.length),
      },
    );
    return Ok<ImportSummary, ImportRefused>(
      ImportSummary(
        dayLogsRestored: envelope.dayLogs.length,
        settingsRestored: envelope.settings.length,
        exportedUtc: envelope.exportedUtc,
        writtenByAppVersion: envelope.appVersion,
      ),
    );
  }

  static List<ConditionRecord> _parseConditions(Map<String, Object?> json) {
    final raw = json['conditions'];
    if (raw is! List<Object?>) {
      throw const _Refusal(
        ImportRejection.malformedField,
        'This backup has no readable list of conditions.',
      );
    }
    final records = <ConditionRecord>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map<String, Object?>) {
        throw _Refusal(
          ImportRejection.malformedField,
          'Condition ${i + 1} in this backup is not readable.',
        );
      }
      try {
        records.add(ConditionRecord.fromJson(entry));
      } on FormatException catch (e) {
        // An unknown condition name is the forward-compatibility case: a backup
        // written after a release that added one. Reported as such rather than
        // as a malformed file, because the fix is to update the app and the
        // user should be told that rather than left thinking the file is
        // damaged.
        throw _Refusal(
          e.message.startsWith('unknown condition')
              ? ImportRejection.unknownValue
              : ImportRejection.malformedField,
          e.message.startsWith('unknown condition')
              ? 'Condition ${i + 1} in this backup (${e.message.substring(20)}) '
                    'was recorded by a newer version of the app. Update the '
                    'app, then import it again. Nothing has been changed.'
              : 'Condition ${i + 1} in this backup is not readable '
                    '(${e.message}).',
        );
      }
    }
    return records;
  }

  static List<DayLog> _parseDayLogs(Map<String, Object?> json) {
    final raw = json['day_logs'];
    if (raw is! List<Object?>) {
      throw const _Refusal(
        ImportRejection.malformedField,
        'This backup has no readable list of logged days.',
      );
    }
    final logs = <DayLog>[];
    final seen = <int>{};
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map<String, Object?>) {
        throw _Refusal(
          ImportRejection.malformedField,
          'Entry ${i + 1} in this backup is not a logged day.',
        );
      }
      final log = _parseDayLog(entry, i);
      if (!seen.add(log.date.epochDay)) {
        throw _Refusal(
          ImportRejection.duplicateDate,
          '${log.date.toIso8601()} appears more than once in this backup, so '
          'it is not clear which entry is right. Nothing has been changed.',
        );
      }
      logs.add(log);
    }
    // Oldest first, whatever order the file happened to be in.
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  static DayLog _parseDayLog(Map<String, Object?> json, int index) {
    final rawDate = json['date'];
    if (rawDate is! String) {
      throw _Refusal(
        ImportRejection.malformedField,
        'Entry ${index + 1} in this backup has no date.',
      );
    }
    final CivilDate date;
    try {
      date = CivilDate.parseIso8601(rawDate);
    } on FormatException {
      throw _Refusal(
        ImportRejection.invalidDate,
        '"$rawDate" is not a calendar date this app can read. Dates must look '
        'like 2026-03-14.',
      );
      // CivilDate throws ArgumentError, not FormatException, for a
      // well-formed string naming a day that does not exist, such as
      // 2026-02-30. Catching an Error is normally wrong, but the input here is
      // an untrusted file: what is a programming error for in-app callers is
      // ordinary bad data on this path, and letting it escape would crash the
      // import instead of refusing the file.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw _Refusal(
        ImportRejection.invalidDate,
        '"$rawDate" is not a real calendar date.',
      );
    }

    final flow = _decodeEnum(
      json['flow'],
      FlowIntensity.values,
      field: 'flow',
      date: date,
    );

    final rawSymptoms = json['symptoms'];
    final symptoms = <Symptom, SymptomSeverity>{};
    if (rawSymptoms != null) {
      if (rawSymptoms is! Map<String, Object?>) {
        throw _Refusal(
          ImportRejection.malformedField,
          'The symptoms recorded for ${date.toIso8601()} are not readable.',
        );
      }
      for (final entry in rawSymptoms.entries) {
        final symptom = _decodeEnumName(
          entry.key,
          Symptom.values,
          field: 'symptom',
          date: date,
        );
        symptoms[symptom] = _decodeEnum(
          entry.value,
          SymptomSeverity.values,
          field: 'severity',
          date: date,
        );
      }
    }

    // Nullable, and an absent or explicitly-null key means not recorded. Both
    // spellings are accepted because both are what a real file contains: the
    // exporter writes an explicit null, and a hand-edited file may simply omit
    // the key. Neither is an error, and neither may become a recorded answer —
    // "not recorded" is a different statement from either one, and inventing
    // one would put words in the user's mouth about their private life.
    final rawIntercourse = json['intercourse'];
    final intercourse = rawIntercourse == null
        ? null
        : _decodeEnum(
            rawIntercourse,
            Intercourse.values,
            field: 'intercourse',
            date: date,
          );

    return DayLog(
      date: date,
      flow: flow,
      symptoms: symptoms,
      intercourse: intercourse,
    );
  }

  static T _decodeEnum<T extends Enum>(
    Object? raw,
    List<T> values, {
    required String field,
    required CivilDate date,
  }) {
    if (raw is! String) {
      throw _Refusal(
        ImportRejection.malformedField,
        'The $field recorded for ${date.toIso8601()} is not readable.',
      );
    }
    return _decodeEnumName(raw, values, field: field, date: date);
  }

  static T _decodeEnumName<T extends Enum>(
    String raw,
    List<T> values, {
    required String field,
    required CivilDate date,
  }) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    // Almost always a backup from a build that added a value this one does not
    // have. Saying which value, and that updating fixes it, is the difference
    // between a user retrying and a user giving up on their own data.
    throw _Refusal(
      ImportRejection.unknownValue,
      'This backup records a $field this version does not know ("$raw", on '
      '${date.toIso8601()}). It was probably written by a newer version of the '
      'app. Nothing has been changed.',
    );
  }

  static Map<String, String> _parseSettings(Map<String, Object?> json) {
    final raw = json['settings'];
    if (raw == null) return const <String, String>{};
    if (raw is! Map<String, Object?>) {
      throw const _Refusal(
        ImportRejection.malformedField,
        'The settings in this backup are not readable.',
      );
    }
    final settings = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String) {
        throw _Refusal(
          ImportRejection.malformedField,
          'The setting "${entry.key}" in this backup is not readable.',
        );
      }
      settings[entry.key] = value;
    }
    return settings;
  }

  static int _requireInt(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! int) {
      throw _Refusal(
        ImportRejection.malformedField,
        'This backup is missing "$field", so it cannot be read safely.',
      );
    }
    return value;
  }

  static String _requireString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! String) {
      throw _Refusal(
        ImportRejection.malformedField,
        'This backup is missing "$field", so it cannot be read safely.',
      );
    }
    return value;
  }
}

/// Internal control flow for validation, converted to an [ImportRefused] at the
/// boundary so that no exception escapes this file.
@immutable
final class _Refusal implements Exception {
  const _Refusal(this.rejection, this.message);

  final ImportRejection rejection;
  final String message;
}
