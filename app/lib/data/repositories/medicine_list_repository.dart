/// Medicine list repository.
///
/// The medicines recorded under Conditions and medication. They are kept as
/// one setting rather than a table (ADR-0015): each by the key the medicines
/// bundle knows it by, and by its name, so that one a later refresh of the
/// bundle no longer lists can still be shown.
///
/// Includes:
///     - RecordedMedicine: One recorded medicine.
///     - MedicineListRepository: Reads, adds and removes them.
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

  /// Take the medicine with [key] off the list.
  ///
  /// Args:
  ///     key (String): The key it was recorded by.
  Future<void> remove(String key) => _settings.transaction(() async {
    final recorded = await read();
    await _write(<RecordedMedicine>[
      for (final each in recorded)
        if (each.key != key) each,
    ]);
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
