import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Version of the export envelope this build writes.
///
/// Bumped only for a change the previous importer could not read correctly.
/// The importer refuses anything it does not recognise rather than guessing, so
/// this number is the promise that a file's fields mean what they used to.
///
/// **v2 adds conditions, and v1 files are refused** (ADR-0011). That decision
/// was taken knowing its cost: this app has no cloud and no Play Store restore,
/// so the export *is* the recovery path (risk R8), and refusing v1 makes every
/// backup taken before this release unrestorable. A few lines of import
/// branching would have avoided it and were declined. The mitigation is the
/// one-time re-export prompt — see `SettingKey.exportFormatAcknowledged` — so
/// that nobody discovers the loss after losing a phone.
///
/// If you are reading this because you are about to "fix" the refusal: it is
/// not an oversight. Read ADR-0011 first.
const int exportSchemaVersion = 2;

/// Fingerprint of the envelope's *shape*, not its contents.
///
/// Deliberately covers field names only, never the members of [FlowIntensity]
/// or [Symptom]. If it covered those, adding one symptom in a later release
/// would invalidate every backup a user had ever taken. An unknown enum value
/// is instead reported per-field on import, which produces a message naming the
/// value rather than a blanket refusal.
///
/// `export_v1_test.dart` rebuilds this from the actual serialised keys, so
/// changing the shape without changing this constant fails the suite.
const String exportSchemaFingerprint =
    'v2;'
    'envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,'
    'schema_fingerprint,schema_version,settings];'
    'day_log[date,flow,symptoms];'
    'condition[condition,end,start]';

/// The app version stamped into exports.
///
/// A plain constant rather than `package_info_plus`: reading it at runtime
/// would add a platform plugin to the one part of the app that has to work when
/// everything else has gone wrong. `export_v1_test.dart` asserts it matches
/// `pubspec.yaml`, so it cannot drift silently.
const String appVersion = '1.0.0+1';

/// Everything an export file carries.
///
/// Day logs and settings only. Cycles, statistics and predictions are all
/// derived, so exporting them would create a second copy that can disagree with
/// the logs, and importing them would let a stale prediction outlive the data it
/// came from.
@immutable
final class ExportEnvelope {
  /// Creates an envelope.
  const ExportEnvelope({
    required this.schemaVersion,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required this.schemaFingerprint,
    required this.exportedUtc,
    required this.dayLogs,
    required this.settings,
    this.conditions = const <ConditionRecord>[],
  });

  /// Envelope format version.
  final int schemaVersion;

  /// Version of the app that wrote the file.
  final String appVersion;

  /// Database schema version at the time of export, for diagnostics.
  final int databaseSchemaVersion;

  /// Shape fingerprint. See [exportSchemaFingerprint].
  final String schemaFingerprint;

  /// When the file was written.
  final DateTime exportedUtc;

  /// Every logged day, oldest first.
  final List<DayLog> dayLogs;

  /// Stored preferences, verbatim.
  ///
  /// Raw strings rather than typed values, so a preference this build has never
  /// heard of survives a round trip through it instead of being dropped.
  final Map<String, String> settings;

  /// Recorded conditions, without their row ids.
  ///
  /// New in v2. The ids are left out deliberately: a row number means nothing
  /// in another database, and restoring one would either collide or be ignored.
  /// The identity of a condition record is its condition and its dates.
  final List<ConditionRecord> conditions;

  /// The JSON form written to disk.
  ///
  /// Key order is fixed and the encoder is pretty-printed, because this file is
  /// the user's own backup and the only recovery path the app has (risk R8). It
  /// should be readable, and diffable, by a person with a text editor.
  Map<String, Object?> toJson() => <String, Object?>{
    'app_version': appVersion,
    'conditions': <Map<String, Object?>>[
      for (final record in conditions) record.toJson(),
    ],
    'day_logs': <Map<String, Object?>>[
      for (final log in dayLogs) log.toJson(),
    ],
    'db_schema_version': databaseSchemaVersion,
    'exported_utc': exportedUtc.toUtc().toIso8601String(),
    'schema_fingerprint': schemaFingerprint,
    'schema_version': schemaVersion,
    'settings': settings,
  };

  @override
  bool operator ==(Object other) =>
      other is ExportEnvelope &&
      other.schemaVersion == schemaVersion &&
      other.appVersion == appVersion &&
      other.databaseSchemaVersion == databaseSchemaVersion &&
      other.schemaFingerprint == schemaFingerprint &&
      other.exportedUtc == exportedUtc &&
      _sameLogs(other.dayLogs, dayLogs) &&
      _sameSettings(other.settings, settings) &&
      _sameConditions(other.conditions, conditions);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    appVersion,
    databaseSchemaVersion,
    schemaFingerprint,
    exportedUtc,
    Object.hashAll(dayLogs),
    Object.hashAllUnordered(settings.entries.map((e) => '${e.key}=${e.value}')),
  );

  @override
  String toString() =>
      'ExportEnvelope(v$schemaVersion, app $appVersion, '
      '${dayLogs.length} logs, ${settings.length} settings)';

  static bool _sameLogs(List<DayLog> a, List<DayLog> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameConditions(
    List<ConditionRecord> a,
    List<ConditionRecord> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      // Compared without the id, because the id is not exported and a restored
      // record always has a fresh one. Comparing it would make a correct round
      // trip look like a failure.
      if (a[i].condition != b[i].condition ||
          a[i].start != b[i].start ||
          a[i].end != b[i].end) {
        return false;
      }
    }
    return true;
  }

  static bool _sameSettings(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// Writes the user's data out as a versioned JSON envelope.
///
/// This is the **only** backup mechanism in the app. There is no cloud sync, so
/// if this is wrong the user loses everything with no recovery (risk R8). It is
/// also the recovery path offered when the database is found to be corrupt on
/// open.
///
/// There is deliberately no "export to the default location" entry point. Every
/// method here takes an explicit destination, so a silent write to shared
/// storage is not something a caller can express by accident: the privacy
/// commitment in `docs/PLAN.md` 6.5 is that data leaves the app only by an
/// explicit user action. The system file picker that supplies that destination
/// belongs to the Settings screen (AND-16); putting it here would drag a
/// platform plugin into the data layer and make this untestable off-device.
abstract final class ExportV1 {
  /// Reads everything exportable out of [database].
  static Future<ExportEnvelope> build({
    required AppDatabase database,
    required Clock clock,
  }) async => ExportEnvelope(
    schemaVersion: exportSchemaVersion,
    appVersion: appVersion,
    databaseSchemaVersion: AppDatabase.latestSchemaVersion,
    schemaFingerprint: exportSchemaFingerprint,
    exportedUtc: clock.nowUtc(),
    dayLogs: await database.dayLogDao.allLogs(),
    settings: await database.settingsDao.allRaw(),
    conditions: await database.conditionDao.all(),
  );

  /// Encodes [envelope] as the text written to a file.
  static String encode(ExportEnvelope envelope) =>
      const JsonEncoder.withIndent('  ').convert(envelope.toJson());

  /// Exports [database] to [destination], which the user must have chosen.
  ///
  /// Returns the envelope that was written, so the caller can report how much
  /// was saved without re-reading the file.
  static Future<ExportEnvelope> writeTo(
    File destination, {
    required AppDatabase database,
    required Clock clock,
    RingLogger? logger,
  }) async {
    final envelope = await build(database: database, clock: clock);
    await destination.writeAsString(encode(envelope), flush: true);
    logger?.info(
      LogEvent.exportWritten,
      fields: <String, LogField>{
        'day_logs': LogField.count(envelope.dayLogs.length),
        'settings': LogField.count(envelope.settings.length),
      },
    );
    return envelope;
  }

  /// A filename carrying the export date, for the picker to offer as a default.
  ///
  /// Deliberately bland. A file called `period-tracker-...` sitting in a shared
  /// downloads folder tells anyone who sees it something the user may not have
  /// chosen to share, so the name says what the file is for the person who made
  /// it and nothing about what is in it.
  static String suggestedFileName(Clock clock) =>
      'period-tracker-export-${clock.today().toIso8601()}.json';
}
