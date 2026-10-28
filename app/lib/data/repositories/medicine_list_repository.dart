/// Medicine list repository.
///
/// The medicines recorded under Conditions and medication. They are kept as
/// one setting rather than a table (ADR-0015): each by the key the medicines
/// bundle knows it by, and by its name, so that one a later refresh of the
/// bundle no longer lists can still be shown. The times each is to be
/// reminded of are a second setting beside it (ADR-0025).
///
/// Includes:
///     - RecordedMedicine: One recorded medicine.
///     - ReminderTime: A time of day a reminder goes off.
///     - MedicineListRepository: Reads, adds and removes them, and their
///       reminder times.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/reference/medicine.dart';

/// One recorded medicine.
///
/// Attributes:
///     key (String): The key the medicines bundle knows it by.
///     name (String): Its name when it was recorded.
@immutable
final class RecordedMedicine {
  /// Creates a record.
  ///
  /// Args:
  ///     key (String): The key the medicines bundle knows it by.
  ///     name (String): Its name when it was recorded.
  const RecordedMedicine({required this.key, required this.name});

  /// The key the medicines bundle knows it by.
  final String key;

  /// Its name when it was recorded. Shown when the bundle no longer has it.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is RecordedMedicine && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(key, name);

  @override
  String toString() => 'RecordedMedicine($key)';
}

/// A time of day a medicine reminder goes off, to the minute, in the phone's
/// own time zone.
///
/// Attributes:
///     hour (int): From 0 to 23.
///     minute (int): From 0 to 59.
@immutable
final class ReminderTime implements Comparable<ReminderTime> {
  /// Creates a time.
  ///
  /// Args:
  ///     hour (int): From 0 to 23.
  ///     minute (int): From 0 to 59.
  const ReminderTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'an hour of the day'),
      assert(minute >= 0 && minute < 60, 'a minute of the hour');

  /// Read a time as it is stored, `HH:MM` on the 24-hour clock.
  ///
  /// Returns:
  ///     ReminderTime?: The time, or null for anything else.
  static ReminderTime? parse(String text) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return ReminderTime(hour, minute);
  }

  /// From 0 to 23.
  final int hour;

  /// From 0 to 59.
  final int minute;

  /// The time as it is stored: `HH:MM`, on the 24-hour clock.
  String get wire =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ReminderTime other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime($wire)';
}

/// Reads and writes the recorded medicines.
///
/// **Nothing here reaches the prediction**, as with conditions (ADR-0010):
/// the medicines are compared with each other, and with nothing else.
///
/// Attributes:
///     _settings (SettingsDao): Where the list is stored.
class MedicineListRepository {
  /// Creates a repository over [_settings].
  ///
  /// Args:
  ///     _settings (SettingsDao): Where the list is stored.
  MedicineListRepository(this._settings);

  /// Where the list is stored.
  final SettingsDao _settings;

  /// Watch the recorded medicines.
  ///
  /// Returns:
  ///     `Stream<List<RecordedMedicine>>`: The medicines in the order they
  ///     were added, re-emitted whenever the list changes.
  Stream<List<RecordedMedicine>> watch() =>
      _settings.watchRaw(SettingKey.recordedMedicines).map(decode);

  /// Read the recorded medicines.
  ///
  /// Returns:
  ///     `Future<List<RecordedMedicine>>`: The medicines in the order added.
  Future<List<RecordedMedicine>> read() async =>
      decode(await _settings.raw(SettingKey.recordedMedicines));

  /// Record [medicine], after the others, unless it is recorded already.
  ///
  /// Args:
  ///     medicine (MedicineEntry): The medicine, as the bundle describes it.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether it was added. False when it was on the list
  ///     already.
  Future<bool> add(MedicineEntry medicine) => _settings.transaction(() async {
    final recorded = await read();
    if (recorded.any((each) => each.key == medicine.key)) return false;
    await _write(<RecordedMedicine>[
      ...recorded,
      RecordedMedicine(key: medicine.key, name: medicine.name),
    ]);
    return true;
  });

  /// Take the medicine with [key] off the list, and its reminders with it:
  /// a medicine added back later starts with none.
  ///
  /// Args:
  ///     key (String): The key it was recorded by.
  Future<void> remove(String key) => _settings.transaction(() async {
    final recorded = await read();
    await _write(<RecordedMedicine>[
      for (final each in recorded)
        if (each.key != key) each,
    ]);
    final reminders = Map<String, List<ReminderTime>>.of(await this.reminders())
      ..remove(key);
    await _writeReminders(reminders);
  });

  /// The most reminder times one medicine may have.
  static const int maxReminders = 4;

  /// Watch the reminder times, by the key of the medicine each is for.
  ///
  /// Returns:
  ///     `Stream<Map<String, List<ReminderTime>>>`: Each medicine's times,
  ///     earliest first, re-emitted whenever one changes. A medicine with none
  ///     is not in it.
  Stream<Map<String, List<ReminderTime>>> watchReminders() =>
      _settings.watchRaw(SettingKey.medicineReminders).map(decodeReminders);

  /// Read the reminder times, by the key of the medicine each is for.
  ///
  /// Returns:
  ///     `Future<Map<String, List<ReminderTime>>>`: As [watchReminders].
  Future<Map<String, List<ReminderTime>>> reminders() async =>
      decodeReminders(await _settings.raw(SettingKey.medicineReminders));

  /// Set the times the medicine with [key] is to be reminded of.
  ///
  /// Args:
  ///     key (String): The key it was recorded by.
  ///     times (`List<ReminderTime>`): The times, in any order. Each is kept
  ///         once, earliest first, and no more than [maxReminders] of them.
  ///         None removes its reminders.
  Future<void> setReminders(String key, List<ReminderTime> times) =>
      _settings.transaction(() async {
        final reminders = Map<String, List<ReminderTime>>.of(
          await this.reminders(),
        );
        final kept = _tidy(times);
        if (kept.isEmpty) {
          reminders.remove(key);
        } else {
          reminders[key] = kept;
        }
        await _writeReminders(reminders);
      });

  /// Store [reminders], or nothing at all once there are none.
  Future<void> _writeReminders(Map<String, List<ReminderTime>> reminders) =>
      reminders.isEmpty
      ? _settings.remove(SettingKey.medicineReminders)
      : _settings.writeString(
          SettingKey.medicineReminders,
          encodeReminders(reminders),
        );

  /// [times] each once, earliest first, no more than [maxReminders].
  static List<ReminderTime> _tidy(Iterable<ReminderTime> times) =>
      List<ReminderTime>.unmodifiable(
        (times.toSet().toList()..sort()).take(maxReminders),
      );

  /// Read the stored reminder times.
  ///
  /// Forgiving, as [decode] is: a value that cannot be read is no reminder,
  /// and a time that cannot be read is skipped.
  ///
  /// Args:
  ///     raw (String?): The stored setting, or null when unset.
  ///
  /// Returns:
  ///     `Map<String, List<ReminderTime>>`: Each medicine's times, earliest
  ///     first.
  static Map<String, List<ReminderTime>> decodeReminders(String? raw) {
    if (raw == null) return const <String, List<ReminderTime>>{};
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return const <String, List<ReminderTime>>{};
    }
    if (parsed is! Map<String, Object?>) {
      return const <String, List<ReminderTime>>{};
    }
    final reminders = <String, List<ReminderTime>>{};
    for (final MapEntry(:key, :value) in parsed.entries) {
      if (key.isEmpty || value is! List<Object?>) continue;
      final times = _tidy(<ReminderTime>[
        for (final item in value)
          if (item is String) ?ReminderTime.parse(item),
      ]);
      if (times.isNotEmpty) reminders[key] = times;
    }
    return Map<String, List<ReminderTime>>.unmodifiable(reminders);
  }

  /// Write reminder times as they are stored.
  static String encodeReminders(Map<String, List<ReminderTime>> reminders) =>
      jsonEncode(<String, List<String>>{
        for (final MapEntry(:key, :value) in reminders.entries)
          key: <String>[for (final time in value) time.wire],
      });

  /// Store [recorded], or nothing at all once it is empty: a removed list
  /// leaves no trace that there ever was one.
  Future<void> _write(List<RecordedMedicine> recorded) => recorded.isEmpty
      ? _settings.remove(SettingKey.recordedMedicines)
      : _settings.writeString(SettingKey.recordedMedicines, encode(recorded));

  /// Read the stored list.
  ///
  /// Forgiving, as every setting is: an import can bring in any string, and a
  /// list that cannot be read is better shown as empty than as a screen that
  /// fails to open. An entry without a key and a name is skipped.
  ///
  /// Args:
  ///     raw (String?): The stored setting, or null when unset.
  ///
  /// Returns:
  ///     `List<RecordedMedicine>`: The medicines, in the order stored.
  static List<RecordedMedicine> decode(String? raw) {
    if (raw == null) return const <RecordedMedicine>[];
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return const <RecordedMedicine>[];
    }
    if (parsed is! List<Object?>) return const <RecordedMedicine>[];
    return List<RecordedMedicine>.unmodifiable(<RecordedMedicine>[
      for (final item in parsed)
        if (item
            case {
              'key': final String key,
              'name': final String name,
            }
            when key.isNotEmpty)
          RecordedMedicine(key: key, name: name),
    ]);
  }

  /// Write [recorded] in the form [decode] reads.
  ///
  /// Args:
  ///     recorded (`List<RecordedMedicine>`): The medicines, in order.
  ///
  /// Returns:
  ///     String: A JSON list of `{"key": ..., "name": ...}`.
  static String encode(List<RecordedMedicine> recorded) => jsonEncode(<Object>[
    for (final each in recorded)
      <String, String>{
        'key': each.key,
        'name': each.name,
      },
  ]);
}
