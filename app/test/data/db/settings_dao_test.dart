import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('defaults', () {
    test('an unset preference falls back rather than throwing', () async {
      expect(
        await db.settingsDao.readBool(
          SettingKey.reminderEnabled,
          orElse: true,
        ),
        isTrue,
      );
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 2),
        2,
      );
    });

    test('a malformed value falls back too', () async {
      // A preference that cannot be parsed is worth defaulting. Throwing here
      // would mean one bad row stops the app from starting.
      await db.settingsDao.writeRaw(
        SettingKey.reminderLeadDays.wireName,
        'two',
      );
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 2),
        2,
      );
      await db.settingsDao.writeRaw(
        SettingKey.reminderEnabled.wireName,
        'yes please',
      );
      expect(
        await db.settingsDao.readBool(
          SettingKey.reminderEnabled,
          orElse: false,
        ),
        isFalse,
      );
    });
  });

  group('round trip', () {
    test('booleans and integers survive a write and read', () async {
      await db.settingsDao.writeBool(
        SettingKey.onboardingComplete,
        value: true,
      );
      await db.settingsDao.writeInt(SettingKey.reminderLeadDays, 3);
      expect(
        await db.settingsDao.readBool(
          SettingKey.onboardingComplete,
          orElse: false,
        ),
        isTrue,
      );
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 0),
        3,
      );
    });

    test('writing the same key twice replaces it', () async {
      await db.settingsDao.writeInt(SettingKey.reminderLeadDays, 3);
      await db.settingsDao.writeInt(SettingKey.reminderLeadDays, 5);
      expect(await db.settingsDao.allRaw(), hasLength(1));
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 0),
        5,
      );
    });
  });

  group('keys', () {
    test('are spelled out rather than derived from the Dart name', () {
      // Renaming the enum member must not orphan every stored value.
      expect(SettingKey.onboardingComplete.wireName, 'onboarding_complete');
      expect(SettingKey.reminderLeadDays.wireName, 'reminder_lead_days');
      expect(
        SettingKey.values.map((k) => k.wireName).toSet(),
        hasLength(SettingKey.values.length),
        reason: 'wire names must be unique',
      );
    });
  });

  group('replaceAll', () {
    test('keeps keys this build does not recognise', () async {
      // An export written by a newer build may carry settings this one has
      // never heard of. Dropping them on import would quietly downgrade the
      // user's preferences.
      await db.settingsDao.replaceAll(<String, String>{
        SettingKey.reminderEnabled.wireName: 'true',
        'a_setting_from_the_future': '42',
      });
      final all = await db.settingsDao.allRaw();
      expect(all['a_setting_from_the_future'], '42');
      expect(all, hasLength(2));
    });

    test('replaces rather than merges', () async {
      await db.settingsDao.writeInt(SettingKey.reminderLeadDays, 3);
      await db.settingsDao.replaceAll(<String, String>{
        SettingKey.reminderEnabled.wireName: 'false',
      });
      expect(await db.settingsDao.allRaw(), <String, String>{
        SettingKey.reminderEnabled.wireName: 'false',
      });
    });
  });
}
