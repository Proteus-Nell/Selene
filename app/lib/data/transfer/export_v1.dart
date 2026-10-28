/// Export format v4.
///
/// Writes the user's data out as a versioned JSON envelope. This is the only
/// backup mechanism in the app: there is no cloud sync, so if this is wrong
/// the user loses everything with no recovery (risk R8).
///
/// Includes:
///     - exportSchemaVersion, exportSchemaFingerprint: What this build
///       writes, and the shape it promises.
///     - oldestRestorableExportVersion, exportSchemaFingerprintV3: What it
///       still restores.
///     - ExportEnvelope: The envelope itself.
///     - ExportV1: Building, encoding and writing one.
library;

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
/// The importer refuses anything newer than it recognises rather than
/// guessing, so this number is the promise that a file's fields mean what they
/// used to.
///
/// **v4 adds the five record-only measurements (ADR-0020), and v3 still
/// restores.** v4 only adds fields, each nullable, so a v3 file has nothing
/// missing: an absent measurement means not recorded, which is exactly what it
/// meant when the file was written. ADR-0011's refusal of older formats stands
/// for v2 and earlier, whose backups were already stranded by v3, and no
/// longer applies to a format that only adds fields. A user holding a v3
/// backup is therefore not warned on update.
///
/// The history, because it is the reason the policy changed: v2 refused v1 and
/// v3 refused v2, each stranding every backup taken before it, the second time
/// for a change that only added a nullable field. See ADR-0011 and ADR-0020.
const int exportSchemaVersion = 4;

/// The oldest export format this build restores.
///
/// The re-export prompt is driven by this, not by [exportSchemaVersion]: a
/// user needs telling that their backups have stopped restoring only when the
/// format they last exported in is older than this.
const int oldestRestorableExportVersion = 3;

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
    'v4;'
    'envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,'
    'schema_fingerprint,schema_version,settings];'
    'day_log[basal_temperature_celsius,cervical_mucus,date,flow,intercourse,'
    'pdg_strip,progesterone_unit,progesterone_value,symptoms];'
    'condition[condition,end,start]';

/// The fingerprint a v3 export carries, which this build still restores.
///
/// Fixed: it describes files already on people's phones and drives.
const String exportSchemaFingerprintV3 =
    'v3;'
    'envelope[app_version,conditions,day_logs,db_schema_version,exported_utc,'
    'schema_fingerprint,schema_version,settings];'
    'day_log[date,flow,intercourse,symptoms];'
    'condition[condition,end,start]';

/// The app version stamped into exports.
///
/// A plain constant rather than `package_info_plus`: reading it at runtime
/// would add a platform plugin to the one part of the app that has to work when
/// everything else has gone wrong. `transfer_test.dart` asserts it matches
/// `pubspec.yaml`, so it cannot drift silently. Set both with
/// `tools/scripts/release_version.py set <version>`.
const String appVersion = '1.1.0+10100';

/// The version as people are shown it: the name, without the build number.
///
/// The build number is derived from the name by
/// `tools/scripts/release_version.py`, so in Settings it would only be a
/// second figure that tells nobody anything.
String get appVersionName => appVersion.split('+').first;

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

  /// Render this envelope as the JSON written to disk.
  ///
  /// Key order is fixed and the encoder is pretty-printed, because this file
  /// is the user's own backup and the only recovery path the app has (risk
  /// R8). It should be readable, and diffable, by a person with a text editor.
  ///
  /// Returns:
  ///     `Map<String, Object?>`: The envelope, with its keys in a fixed
  ///     order.
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

  /// Compare two log lists element by element, in order.
  ///
  /// Args:
  ///     a (`List<DayLog>`): First list.
  ///     b (`List<DayLog>`): Second list.
  ///
  /// Returns:
  ///     bool: True when both hold the same days in the same order.
  static bool _sameLogs(List<DayLog> a, List<DayLog> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Compare two condition lists, ignoring row identity.
  ///
  /// Args:
  ///     a (`List<ConditionRecord>`): First list.
  ///     b (`List<ConditionRecord>`): Second list.
  ///
  /// Returns:
  ///     bool: True when both hold the same conditions over the same spans,
  ///     in the same order.
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

  /// Compare two settings maps by key and value.
  ///
  /// Args:
  ///     a (`Map<String, String>`): First map.
  ///     b (`Map<String, String>`): Second map.
  ///
  /// Returns:
  ///     bool: True when both hold the same keys with the same values.
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
  /// Read everything exportable out of the database.
  ///
  /// Args:
  ///     database (AppDatabase): Where the data lives.
  ///     clock (Clock): Stamps the envelope with the export time.
  ///
  /// Returns:
  ///     `Future<ExportEnvelope>`: The envelope, not yet written anywhere.
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

  /// Encode an envelope as the text written to a file.
  ///
  /// Args:
  ///     envelope (ExportEnvelope): What to encode.
  ///
  /// Returns:
  ///     String: Pretty-printed JSON, two-space indented.
  static String encode(ExportEnvelope envelope) =>
      const JsonEncoder.withIndent('  ').convert(envelope.toJson());

  /// Export the database to a destination the user chose.
  ///
  /// Args:
  ///     destination (File): Where to write. Supplied by the system file
  ///         picker, never chosen here.
  ///     database (AppDatabase): Where the data lives.
  ///     clock (Clock): Stamps the envelope with the export time.
  ///     logger (RingLogger?, optional): Records counts, never content.
  ///         Defaults to null.
  ///     seal (`Future<String> Function(String)?`, optional): Turns the
  ///         encoded export into what is written, when the user chose a
  ///         passphrase (ADR-0019). Defaults to null, which writes the export
  ///         as it is.
  ///
  /// Returns:
  ///     `Future<ExportEnvelope>`: The envelope that was written, so the
  ///     caller can report how much was saved without re-reading the file.
  static Future<ExportEnvelope> writeTo(
    File destination, {
    required AppDatabase database,
    required Clock clock,
    RingLogger? logger,
    Future<String> Function(String export)? seal,
  }) async {
    final envelope = await build(database: database, clock: clock);
    final encoded = encode(envelope);
    await destination.writeAsString(
      seal == null ? encoded : await seal(encoded),
      flush: true,
    );
    logger?.info(
      LogEvent.exportWritten,
      fields: <String, LogField>{
        'day_logs': LogField.count(envelope.dayLogs.length),
        'settings': LogField.count(envelope.settings.length),
        'protected': LogField.flag(seal != null),
      },
    );
    return envelope;
  }

  /// Suggest a filename for the picker to offer as a default.
  ///
  /// Deliberately bland. A file called `period-tracker-...` sitting in a
  /// shared downloads folder tells anyone who sees it something the user may
  /// not have chosen to share, so the name says what the file is for the
  /// person who made it and nothing about what is in it.
  ///
  /// Args:
  ///     clock (Clock): Supplies the date the name carries.
  ///
  /// Returns:
  ///     String: A name of the form `period-tracker-export-YYYY-MM-DD.json`.
  static String suggestedFileName(Clock clock) =>
      'period-tracker-export-${clock.today().toIso8601()}.json';
}
