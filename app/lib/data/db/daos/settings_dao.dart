import 'package:drift/drift.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';

part 'settings_dao.g.dart';

/// The preferences the app stores, as a closed set of keys.
///
/// An enum rather than free strings: a typo in a setting key is otherwise a
/// silent read of a default value, which is the kind of bug that only shows up
/// as "my setting keeps resetting" months later.
enum SettingKey {
  /// Whether the user has completed onboarding and accepted the disclaimer.
  onboardingComplete('onboarding_complete'),

  /// Whether the window-opening reminder is enabled.
  reminderEnabled('reminder_enabled'),

  /// How many days before the predicted window opens to remind.
  reminderLeadDays('reminder_lead_days'),

  /// Epoch day of the most recent successful export, for the backup nudge.
  lastExportEpochDay('last_export_epoch_day');

  const SettingKey(this.wireName);

  /// The key as stored, and as written into an export file.
  ///
  /// Spelled out rather than derived from [name] so renaming the Dart member
  /// cannot orphan every stored value.
  final String wireName;
}

/// Typed access to the settings table.
///
/// Values are stored as text and parsed here, so no caller ever sees the
/// encoding. A malformed or missing value falls back to the supplied default
/// rather than throwing: a preference that cannot be read is a preference worth
/// defaulting, not a reason to fail to start.
@DriftAccessor(tables: <Type>[Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  /// Creates the DAO over [attachedDatabase].
  SettingsDao(super.attachedDatabase);

  /// Every stored setting, as raw strings.
  ///
  /// Used by the exporter, which round-trips settings verbatim rather than
  /// interpreting them.
  Future<Map<String, String>> allRaw() async {
    final rows = await select(settings).get();
    return <String, String>{
      for (final row in rows) row.settingKey: row.settingValue,
    };
  }

  /// The raw value stored for [key], or null.
  Future<String?> raw(SettingKey key) async {
    final row = await (select(
      settings,
    )..where((t) => t.settingKey.equals(key.wireName))).getSingleOrNull();
    return row?.settingValue;
  }

  /// Reads a boolean setting, defaulting to [orElse].
  Future<bool> readBool(SettingKey key, {required bool orElse}) async {
    final value = await raw(key);
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => orElse,
    };
  }

  /// Reads an integer setting, defaulting to [orElse].
  Future<int> readInt(SettingKey key, {required int orElse}) async {
    final value = await raw(key);
    if (value == null) return orElse;
    return int.tryParse(value) ?? orElse;
  }

  /// Writes a boolean setting.
  Future<void> writeBool(SettingKey key, {required bool value}) =>
      writeRaw(key.wireName, '$value');

  /// Writes an integer setting.
  Future<void> writeInt(SettingKey key, int value) =>
      writeRaw(key.wireName, '$value');

  /// Writes a raw key-value pair.
  ///
  /// Takes a [String] key rather than a [SettingKey] so that an import can
  /// restore settings written by a newer build without dropping them. Keys this
  /// build does not recognise are stored and left alone.
  Future<void> writeRaw(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingRow(settingKey: key, settingValue: value),
      );

  /// Replaces every stored setting with [values].
  Future<void> replaceAll(Map<String, String> values) => transaction(() async {
    await delete(settings).go();
    for (final entry in values.entries) {
      await writeRaw(entry.key, entry.value);
    }
  });
}
