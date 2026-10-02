/// Settings storage access.
///
/// Reads and writes the key-value preferences table, as typed accessors over
/// a closed set of keys. Defaults live at the call site for most preferences
/// and on a named accessor for the few read from more than one place.
///
/// Includes:
///     - SettingKey: The closed set of keys, with their stored names.
///     - SettingsDao: Typed reads, watches and writes over them.
library;

import 'package:drift/drift.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/tables.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';

part 'settings_dao.g.dart';

/// Setting key: the preferences the app stores, as a closed set.
///
/// An enum rather than free strings: a typo in a setting key is otherwise a
/// silent read of a default value, which is the kind of bug that only shows
/// up as "my setting keeps resetting" months later.
///
/// Attributes:
///     wireName (String): The key as stored, spelled out rather than taken
///         from [name], so renaming a member cannot reset a user's choice.
enum SettingKey {
  /// Whether the user has completed onboarding and accepted the disclaimer.
  onboardingComplete('onboarding_complete'),

  /// Whether the window-opening reminder is enabled.
  reminderEnabled('reminder_enabled'),

  /// How many days before the predicted window opens to remind.
  reminderLeadDays('reminder_lead_days'),

  /// Epoch day of the most recent successful export, for the backup nudge.
  lastExportEpochDay('last_export_epoch_day'),

  /// Whether the low-priority logging nudge is enabled.
  ///
  /// Defaults to **off**, and stays that way unless the user turns it on. It
  /// is the one notification that is neither a prediction nor actionable, and
  /// docs/PLAN.md 2.4.1 rules out pressure mechanics on this data.
  nudgeEnabled('nudge_enabled'),

  /// Whether notifications may show cycle detail on the lock screen.
  ///
  /// Defaults to **off**. A banner reading "your period is expected tomorrow",
  /// visible to anyone glancing at the phone, is a real data leak, and it is
  /// the one place this project's otherwise offline privacy story leaks by
  /// default (risk R16).
  detailedNotifications('detailed_notifications'),

  /// Epoch day the logging nudge last fired, for its one-per-seven-days cap.
  lastNudgeEpochDay('last_nudge_epoch_day'),

  /// Whether the flow control is collapsed to bleeding yes/no (AND-24).
  ///
  /// Display only. Recorded intensities are never modified by it, so switching
  /// it back reveals them unchanged.
  flowSimplified('flow_simplified'),

  /// Whether the calendar names the cycle phase (AND-25).
  ///
  /// On by default. Phase names restate dates the user logged; they are not
  /// ovulation estimation, which is the thing PLAN 6.2 gates (ADR-0007).
  showCyclePhases('show_cycle_phases'),

  /// Whether an estimated ovulation range is shown (AND-25).
  ///
  /// **Off by default, and it stays that way.** This is the opt-in that
  /// PLAN 6.2 requires, and the line ADR-0007 was careful not to move.
  showOvulationWindow('show_ovulation_window'),

  /// Whether the Learn tab appears in the navigation bar (AND-39).
  ///
  /// Defaults to **off**, at the owner's direction: the reference pages are a
  /// thing to go looking for rather than a fifth of the bar. The tab is the
  /// only way to them and to conditions and medication, so turning it off
  /// hides those pages too.
  showLearnTab('show_learn_tab'),

  /// Whether Learn lists Supplements, Pain and movement, and Body composition.
  ///
  /// Defaults to **off**, at the owner's direction, and has no switch: it is
  /// turned on and off again by holding the Learn tab for ten seconds.
  revealHiddenReference('reveal_hidden_reference'),

  /// Fire dates of the notifications currently scheduled, comma separated.
  ///
  /// Kept so the next launch can tell whether one of them came due while the
  /// app was closed. Nothing else can answer that: the plan rebuilt on this
  /// launch only ever contains future dates, so comparing against it would
  /// always say no (risk R12).
  scheduledFireDays('scheduled_fire_days'),

  /// Whether the app requires an unlock before showing anything (AND-29).
  ///
  /// Defaults to **off**. A lock the user did not ask for is a lock they meet
  /// as a failure the first time their fingerprint does not read, and this app
  /// cannot know whether they share the device.
  appLockEnabled('app_lock_enabled'),

  /// The export format version the user has been told about (AND-28).
  ///
  /// Exists because of ADR-0011: this build refuses v1 backups, so every file a
  /// user took before updating is now unrestorable. Written on a brand-new
  /// database at onCreate, so a fresh install never sees the prompt; **absent**
  /// on a database that predates this release, which is exactly the population
  /// that needs telling. Comparing it against `exportSchemaVersion` is what
  /// makes the warning fire once, for the right people.
  exportFormatAcknowledged('export_format_acknowledged'),

  /// Epoch day the app was last opened, for missed-reminder detection.
  lastOpenedEpochDay('last_opened_epoch_day'),

  /// Which of the six colour schemes the user picked (AND-39).
  ///
  /// Stored as `AppScheme.wireName`. Absent means never chosen, which is the
  /// default scheme rather than an error; so is a name this build does not
  /// have, because a database written by a later build must still open.
  colourScheme('colour_scheme'),

  /// Whether the app follows the device theme, or is pinned light or dark.
  ///
  /// Stored as a `ThemeMode` name. Absent means follow the device, which is
  /// what the app did before there was a setting at all.
  themeMode('theme_mode'),

  /// Whether the notification permission has already been asked for.
  ///
  /// Recorded so the app asks once. On Android 13+ a denial is close to final,
  /// so re-prompting spends the user's patience on a request that cannot
  /// succeed.
  notificationPermissionAsked('notification_permission_asked');

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
///
/// Most preferences are read with [readBool] and an explicit `orElse`, which
/// puts the default at the call site. The three display preferences added in
/// schema v2 have named accessors instead, because each of them is read from
/// more than one place, the settings screen and the feature it controls, and
/// two call sites passing different `orElse` values is a bug with no symptom
/// until someone notices the app disagreeing with its own switch. For
/// [readShowOvulationWindow] that disagreement would ship the behaviour
/// `docs/PLAN.md` 6.2 exists to prevent, so its default is stated once.
@DriftAccessor(tables: <Type>[Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  /// Creates the DAO over [attachedDatabase].
  SettingsDao(super.attachedDatabase);

  /// Read every stored setting, as raw strings.
  ///
  /// Used by the exporter, which round-trips settings verbatim rather than
  /// interpreting them.
  ///
  /// Returns:
  ///     `Future<Map<String, String>>`: Stored key to stored value, for every
  ///     row in the table, including keys this build does not know.
  Future<Map<String, String>> allRaw() async {
    final rows = await select(settings).get();
    return <String, String>{
      for (final row in rows) row.settingKey: row.settingValue,
    };
  }

  /// Read the raw value stored for a key.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to read.
  ///
  /// Returns:
  ///     `Future<String?>`: The stored string, or null when unset.
  Future<String?> raw(SettingKey key) async {
    final row = await (select(
      settings,
    )..where((t) => t.settingKey.equals(key.wireName))).getSingleOrNull();
    return row?.settingValue;
  }

  /// Watch the raw value stored for a key.
  ///
  /// Raw rather than parsed because the two settings that use it, the colour
  /// scheme and the theme mode, are enums declared in `lib/core`, and a DAO
  /// that imported them would have the data layer depending on the theme. The
  /// mapping happens in the providers, where both sides are already in scope.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to watch.
  ///
  /// Returns:
  ///     `Stream<String?>`: The stored string, or null when unset.
  ///     Re-emitted on every write, with repeats collapsed.
  Stream<String?> watchRaw(SettingKey key) {
    final query = select(settings)
      ..where((t) => t.settingKey.equals(key.wireName));
    return query.watchSingleOrNull().map((row) => row?.settingValue).distinct();
  }

  /// Write a string setting.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to write.
  ///     value (String): The value to store.
  Future<void> writeString(SettingKey key, String value) =>
      writeRaw(key.wireName, value);

  /// Read a boolean setting.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to read.
  ///     orElse (bool): What to return when nothing is stored.
  ///
  /// Returns:
  ///     `Future<bool>`: The stored value, or [orElse].
  Future<bool> readBool(SettingKey key, {required bool orElse}) async =>
      _asBool(await raw(key), orElse: orElse);

  /// Watch a boolean setting, re-emitting whenever it is written.
  ///
  /// A stream rather than a read plus an invalidation, so that a preference
  /// changed in settings reaches the screen it controls without either of them
  /// knowing the other exists. The alternative, bumping a counter at each
  /// write site, works until someone adds a write site and forgets, and the
  /// symptom is a setting that appears not to take effect until restart.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to watch.
  ///     orElse (bool): What to emit when nothing is stored.
  ///
  /// Returns:
  ///     `Stream<bool>`: The value, re-emitted on every write.
  Stream<bool> watchBool(SettingKey key, {required bool orElse}) {
    final query = select(settings)
      ..where((t) => t.settingKey.equals(key.wireName));
    return query
        .watchSingleOrNull()
        .map((row) => _asBool(row?.settingValue, orElse: orElse))
        .distinct();
  }

  /// Interpret a stored string as a boolean.
  ///
  /// Args:
  ///     value (String?): The stored string, or null when unset.
  ///     orElse (bool): What to return for null or anything unrecognised.
  ///
  /// Returns:
  ///     bool: The parsed value, or [orElse].
  static bool _asBool(String? value, {required bool orElse}) => switch (value) {
    'true' => true,
    'false' => false,
    _ => orElse,
  };

  /// Read an integer setting.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to read.
  ///     orElse (int): What to return when unset or unparseable.
  ///
  /// Returns:
  ///     `Future<int>`: The stored value, or [orElse].
  Future<int> readInt(SettingKey key, {required int orElse}) async {
    final value = await raw(key);
    if (value == null) return orElse;
    return int.tryParse(value) ?? orElse;
  }

  /// Write a boolean setting.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to write.
  ///     value (bool): The value to store.
  Future<void> writeBool(SettingKey key, {required bool value}) =>
      writeRaw(key.wireName, '$value');

  /// Write an integer setting.
  ///
  /// Args:
  ///     key (SettingKey): Which preference to write.
  ///     value (int): The value to store.
  Future<void> writeInt(SettingKey key, int value) =>
      writeRaw(key.wireName, '$value');

  /// Whether the flow control is collapsed to bleeding yes/no (AND-24).
  ///
  /// Defaults to **off**: the fuller control is what the app already shipped,
  /// and a preference nobody has expressed is not a reason to change what an
  /// existing user sees.
  /// Returns:
  ///     `Future<bool>`: Whether the flow control is collapsed. False by
  ///     default.
  Future<bool> readFlowSimplified() =>
      readBool(SettingKey.flowSimplified, orElse: false);

  /// [readFlowSimplified], as a stream for the screens that follow it.
  /// Returns:
  ///     `Stream<bool>`: Whether the flow control is collapsed. False by
  ///     default.
  ///     Re-emitted on every write.
  Stream<bool> watchFlowSimplified() =>
      watchBool(SettingKey.flowSimplified, orElse: false);

  /// Whether the calendar names the cycle phase (AND-25).
  ///
  /// Defaults to **on**. Phase names restate dates the user logged rather than
  /// estimating anything, so there is nothing here to opt into.
  /// Returns:
  ///     `Future<bool>`: Whether phase names are shown. True by default.
  Future<bool> readShowCyclePhases() =>
      readBool(SettingKey.showCyclePhases, orElse: true);

  /// [readShowCyclePhases], as a stream for the calendar.
  /// Returns:
  ///     `Stream<bool>`: Whether phase names are shown. True by default.
  ///     Re-emitted on every write.
  Stream<bool> watchShowCyclePhases() =>
      watchBool(SettingKey.showCyclePhases, orElse: true);

  /// Whether an estimated ovulation range is shown (AND-25).
  ///
  /// Defaults to **off**, and this is the one default in the app that is a
  /// safety property rather than a taste: `docs/PLAN.md` 6.2 requires ovulation
  /// estimation to be opt-in, because a fertile window shown by default is a
  /// contraceptive claim the model cannot support.
  /// Returns:
  ///     `Future<bool>`: Whether the estimate is shown. False by default.
  Future<bool> readShowOvulationWindow() =>
      readBool(SettingKey.showOvulationWindow, orElse: false);

  /// [readShowOvulationWindow], as a stream for the calendar.
  /// Returns:
  ///     `Stream<bool>`: Whether the estimate is shown. False by default.
  ///     Re-emitted on every write.
  Stream<bool> watchShowOvulationWindow() =>
      watchBool(SettingKey.showOvulationWindow, orElse: false);

  /// Whether the Learn tab appears in the navigation bar (AND-39).
  ///
  /// Defaults to **off**. The tab is the only way to the pages it collects.
  /// Returns:
  ///     `Future<bool>`: Whether the Learn tab is shown. False by default.
  Future<bool> readShowLearnTab() =>
      readBool(SettingKey.showLearnTab, orElse: false);

  /// Watches [readShowLearnTab].
  /// Returns:
  ///     `Stream<bool>`: Whether the Learn tab is shown. False by default.
  ///     Re-emitted on every write.
  Stream<bool> watchShowLearnTab() =>
      watchBool(SettingKey.showLearnTab, orElse: false);

  /// Whether Learn lists the three reference pages it otherwise keeps back.
  ///
  /// Defaults to **off**. Turned on and off by holding the Learn tab.
  /// Returns:
  ///     `Stream<bool>`: Whether they are listed. False by default.
  ///     Re-emitted on every write.
  Stream<bool> watchRevealHiddenReference() =>
      watchBool(SettingKey.revealHiddenReference, orElse: false);

  /// Whether the app requires an unlock (AND-29). Defaults to **off**.
  ///
  /// Off because a lock nobody asked for is friction they meet as a failure,
  /// and because this app cannot know whether the device is shared. The users
  /// who need it know they need it.
  /// Returns:
  ///     `Future<bool>`: Whether the app lock is on. False by default.
  Future<bool> readAppLockEnabled() =>
      readBool(SettingKey.appLockEnabled, orElse: false);

  /// [readAppLockEnabled], as a stream for the settings screen.
  /// Returns:
  ///     `Stream<bool>`: Whether the app lock is on. False by default.
  ///     Re-emitted on every write.
  Stream<bool> watchAppLockEnabled() =>
      watchBool(SettingKey.appLockEnabled, orElse: false);

  /// Whether the user still needs telling that their old backups will not
  /// restore (AND-28, ADR-0011).
  ///
  /// True only when the acknowledged format is older than the one this build
  /// writes. A database created by this build acknowledges the current format
  /// at onCreate, so a fresh install is never warned about backups it has
  /// never taken.
  /// Returns:
  ///     `Future<bool>`: True while the acknowledged format is older than
  ///     the one this build writes.
  Future<bool> needsReExportPrompt() async =>
      await readInt(SettingKey.exportFormatAcknowledged, orElse: 0) <
      exportSchemaVersion;

  /// Watch [needsReExportPrompt], for the screen that shows it.
  ///
  /// Returns:
  ///     `Stream<bool>`: Re-emitted whenever the acknowledgement changes,
  ///     with repeats collapsed.
  Stream<bool> watchNeedsReExportPrompt() {
    final query = select(settings)
      ..where(
        (t) =>
            t.settingKey.equals(SettingKey.exportFormatAcknowledged.wireName),
      );
    return query
        .watchSingleOrNull()
        .map(
          (row) =>
              (int.tryParse(row?.settingValue ?? '') ?? 0) <
              exportSchemaVersion,
        )
        .distinct();
  }

  /// Records that the user has been told, so the prompt does not return.
  ///
  /// Called both when they export and when they dismiss. Dismissing counts:
  /// the release notes carry the same message, and a warning that reappears
  /// every launch is one people learn to tap past without reading.
  Future<void> acknowledgeExportFormat() =>
      writeInt(SettingKey.exportFormatAcknowledged, exportSchemaVersion);

  /// Write a raw key-value pair.
  ///
  /// Takes a [String] key rather than a [SettingKey] so that an import can
  /// restore settings written by a newer build without dropping them. Keys
  /// this build does not recognise are stored and left alone.
  ///
  /// Args:
  ///     key (String): The stored key, recognised or not.
  ///     value (String): The value to store.
  Future<void> writeRaw(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingRow(settingKey: key, settingValue: value),
      );

  /// Replace every stored setting.
  ///
  /// Args:
  ///     values (`Map<String, String>`): The complete new contents of the
  ///         table. Anything not in it is deleted.
  Future<void> replaceAll(Map<String, String> values) => transaction(() async {
    await delete(settings).go();
    for (final entry in values.entries) {
      await writeRaw(entry.key, entry.value);
    }
  });
}
