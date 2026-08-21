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

  group('the schema v2 display preferences', () {
    // Stated once each, in the DAO, rather than at every call site. AND-24 and
    // AND-25 each read their preference from two places — the settings screen
    // and the feature it controls — and two call sites passing different
    // orElse values is a bug whose only symptom is the app disagreeing with
    // its own switch.
    test('flow stays as it was until the user simplifies it', () async {
      expect(await db.settingsDao.readFlowSimplified(), isFalse);
    });

    test('cycle phases are named without being asked for', () async {
      // Not an opt-in, because a phase name restates a date the user logged.
      expect(await db.settingsDao.readShowCyclePhases(), isTrue);
    });

    test('the ovulation window is off, and this one is not a preference', () {
      // docs/PLAN.md 6.2. A fertile window shown by default is a contraceptive
      // claim the model cannot support, so the default is the safety property
      // and the switch is the exception to it. If this test is ever changed to
      // expect true, the change needs an ADR, not a commit message.
      expect(db.settingsDao.readShowOvulationWindow(), completion(isFalse));
    });

    test('each one still reads whatever the user actually set', () async {
      await db.settingsDao.writeBool(SettingKey.flowSimplified, value: true);
      await db.settingsDao.writeBool(SettingKey.showCyclePhases, value: false);
      await db.settingsDao.writeBool(
        SettingKey.showOvulationWindow,
        value: true,
      );
      expect(await db.settingsDao.readFlowSimplified(), isTrue);
      expect(await db.settingsDao.readShowCyclePhases(), isFalse);
      expect(await db.settingsDao.readShowOvulationWindow(), isTrue);
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
      // Counted per key rather than over the whole table. A total was a
      // shorthand for "there is one row" that stopped being true when AND-28
      // started seeding export_format_acknowledged at onCreate — and it would
      // have broken again for any future seeded row, while never actually
      // asserting the thing the test is named for.
      final stored = await db.settingsDao.allRaw();
      expect(
        stored.keys.where(
          (key) => key == SettingKey.reminderLeadDays.wireName,
        ),
        hasLength(1),
      );
      expect(
        await db.settingsDao.readInt(SettingKey.reminderLeadDays, orElse: 0),
        5,
      );
    });
  });

  group('the re-export prompt', () {
    test('a fresh database never asks', () async {
      // ADR-0011 refuses v1 backups. A brand-new install has no backups to
      // refuse, so warning it about them would be alarming and false. onCreate
      // seeds the acknowledgement for exactly this reason.
      expect(await db.settingsDao.needsReExportPrompt(), isFalse);
    });

    test('a database that predates the setting does ask', () async {
      // Simulates an upgrade: the row is what a fresh install gets and an old
      // one lacks, and lacking it is the signal.
      await db.customStatement(
        'DELETE FROM settings WHERE setting_key = ?',
        <Object?>[SettingKey.exportFormatAcknowledged.wireName],
      );
      expect(await db.settingsDao.needsReExportPrompt(), isTrue);
    });

    test('acknowledging stops it asking again', () async {
      await db.customStatement(
        'DELETE FROM settings WHERE setting_key = ?',
        <Object?>[SettingKey.exportFormatAcknowledged.wireName],
      );
      await db.settingsDao.acknowledgeExportFormat();
      expect(await db.settingsDao.needsReExportPrompt(), isFalse);
    });

    test('a future format version would ask again', () async {
      // The comparison is against the format this build writes, not a boolean.
      // When export v3 lands with the same problem, this mechanism works
      // unchanged rather than needing a second flag.
      await db.settingsDao.writeInt(SettingKey.exportFormatAcknowledged, 1);
      expect(await db.settingsDao.needsReExportPrompt(), isTrue);
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
