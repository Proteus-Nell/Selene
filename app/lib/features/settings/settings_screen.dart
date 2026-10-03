/// Settings screen.
///
/// The data controls, the privacy statement, and the activity log. The screen
/// where the promises in `docs/PRIVACY.md` are either kept or not: deleting is
/// a real delete, exporting goes only where the user points it, and the
/// activity log is readable so the claim about what it holds can be checked.
///
/// Includes:
///     - SettingsScreen: The screen itself.
///     - _SettingsScreenState: The export, import and delete flows.
///     - _AppLockSetting: The lock toggle, and why it may be unavailable.
///     - _AppLockSettingState: What the device said when it was asked.
///     - _DisplaySettings: Preferences that change what is shown.
///     - _SectionHeading: A heading over a group of rows.
///     - _ReminderSettings: The notification preferences.
///     - _ReminderSettingsState: Those preferences, and the resync after one
///       changes.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/data/transfer/import_v1.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';
import 'package:period_tracker/features/appearance/appearance_screen.dart';
import 'package:period_tracker/features/common/chip_motion.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/settings/delete_everything_dialog.dart';
import 'package:period_tracker/features/settings/log_viewer.dart';
import 'package:period_tracker/features/settings/privacy_section.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/notifications/scheduler.dart';
import 'package:period_tracker/security/app_lock.dart';

/// Settings screen: data controls, the privacy statement, and the log.
///
/// The screen where the promises in `docs/PRIVACY.md` are either kept or not.
/// Three of them are enforced here rather than described: deleting is a real
/// delete, exporting goes only where the user points it, and the activity log
/// is readable so the claim that it holds no cycle content can be checked
/// rather than believed.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for [SettingsScreen]: the three flows that touch the whole database.
///
/// Attributes:
///     _busy (bool): Whether a long operation is running.
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Whether an export or an import is running, which disables both buttons.
  bool _busy = false;

  /// Tell the user how an operation went, if the screen is still there.
  ///
  /// Args:
  ///     message (String): What to say, already translated.
  void _report(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  /// Write the whole database to a file the user chooses.
  ///
  /// Steps:
  ///     1. Ask the user where it goes. There is no default and no fallback.
  ///     2. Write the envelope there.
  ///     3. Acknowledge the export format, which clears the re-export banner.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the file is written and reported, or
  ///     as soon as the user dismisses the directory picker. A failed write
  ///     reports and does not acknowledge, so the banner stays up.
  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final clock = ref.read(clockProvider);
    // The user chooses where it goes. There is no default location and no
    // fallback to shared storage, so an export cannot happen by accident or
    // land somewhere the user did not pick (docs/PLAN.md 6.5).
    final directory = await getDirectoryPath();
    if (directory == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final envelope = await ExportV1.writeTo(
        File(p.join(directory, ExportV1.suggestedFileName(clock))),
        database: ref.read(appDatabaseProvider),
        clock: clock,
        logger: ref.read(loggerProvider),
      );
      // A completed export is what clears the re-export banner. Navigating to
      // this screen does not, and neither does a failed write.
      await ref.read(appDatabaseProvider).settingsDao.acknowledgeExportFormat();
      _report(l10n.settingsExportDone(envelope.dayLogs.length));
    } on FileSystemException {
      _report(l10n.settingsExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Replace the whole database from a file the user chooses.
  ///
  /// Steps:
  ///     1. Read and inspect the file, without writing anything.
  ///     2. Say what is in it, and what it would replace, and ask.
  ///     3. Restore it only on an explicit confirmation.
  ///
  /// The inspection comes first so the confirmation can quote the file's own
  /// contents rather than asking the user to take it on trust, and so a file
  /// that cannot be read is refused before anything is at stake.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the restore has been reported, or as
  ///     soon as the user backs out of the picker or the confirmation.
  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(label: 'JSON', extensions: <String>['json']),
      ],
    );
    if (file == null || !mounted) return;

    // Inspected before anything is replaced, so the confirmation can say what
    // is actually in the file rather than asking the user to trust it.
    final text = await file.readAsString();
    final inspected = ImportV1.inspect(text);
    if (!mounted) return;
    if (inspected.isErr) {
      _report(inspected.errorOrNull!.message);
      return;
    }
    final envelope = inspected.valueOrNull!;
    final current = await ref.read(cycleRepositoryProvider).logs();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsImportConfirmTitle),
        content: Text(
          l10n.settingsImportConfirmBody(
            current.length,
            envelope.dayLogs.length,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsImport),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ImportV1.restore(
      text,
      database: ref.read(appDatabaseProvider),
      logger: ref.read(loggerProvider),
    );
    if (mounted) setState(() => _busy = false);
    result.fold(
      (summary) => _report(
        l10n.settingsImportDone(
          summary.dayLogsRestored,
          summary.exportedUtc.toLocal().toString().split(' ').first,
        ),
      ),
      (refusal) => _report(refusal.message),
    );
  }

  /// Delete everything, after a typed confirmation.
  ///
  /// The count of logged days is read first so the dialog can say how much is
  /// about to go. This is the one action in the app with no undo and no copy
  /// anywhere else.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the delete is done and reported, or
  ///     at once if the user did not confirm.
  Future<void> _deleteEverything() async {
    final l10n = AppLocalizations.of(context);
    final logs = await ref.read(cycleRepositoryProvider).logs();
    if (!mounted) return;
    final confirmed = await showDeleteEverythingDialog(
      context,
      loggedDays: logs.length,
    );
    if (confirmed != true || !mounted) return;
    await ref.read(cycleRepositoryProvider).deleteEverything();
    _report(l10n.settingsDeleteDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(),
            _SectionHeading(l10n.settingsDataSection),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.settingsExport),
              subtitle: Text(l10n.settingsExportSubtitle),
              onTap: _busy ? null : _export,
            ),
            ListTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: Text(l10n.settingsImport),
              subtitle: Text(l10n.settingsImportSubtitle),
              onTap: _busy ? null : _import,
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.settingsDeleteAll),
              subtitle: Text(l10n.settingsDeleteAllSubtitle),
              onTap: _busy ? null : _deleteEverything,
            ),
            const Divider(),
            _SectionHeading(l10n.settingsRemindersSection),
            const _ReminderSettings(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.settingsBatteryNoteTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  // Risk R12: several manufacturers silently kill scheduled
                  // alarms to save battery. Saying so here is cheaper than the
                  // user concluding the app is broken.
                  Text(
                    l10n.settingsBatteryNoteBody,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            _SectionHeading(l10n.settingsSecuritySection),
            const _AppLockSetting(),
            const Divider(),
            _SectionHeading(l10n.settingsDisplaySection),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.settingsAppearance),
              subtitle: Text(l10n.settingsAppearanceSubtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const AppearanceScreen(),
                ),
              ),
            ),
            const _DisplaySettings(),
            const Divider(),
            _SectionHeading(l10n.settingsPrivacySection),
            const PrivacySection(),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.settingsLogViewer),
              subtitle: Text(l10n.settingsLogViewerSubtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const LogViewerScreen(),
                ),
              ),
            ),
            const Divider(),
            _SectionHeading(l10n.settingsAboutSection),
            ListTile(
              title: Text(l10n.settingsVersion(appVersion)),
              subtitle: Text(
                l10n.settingsModelVersion(
                  priorsArtifactSha256.substring(0, 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The app lock toggle (AND-29).
///
/// Off by default. Two things about it are stated on the screen rather than
/// left to be inferred:
///
/// **It hides the interface and encrypts nothing.** That line sits under the
/// switch whether it is on or off, not behind a link, because a user who
/// believes this encrypts their diary has been given a false sense of safety
/// for the price of a few taps, which is worse than no lock. ADR-0004 keeps
/// the database unencrypted in app-private storage, and ADR-0008 records that
/// this feature does not change that.
///
/// **A device with no credential is told why, not shown a dead switch.** The
/// lock delegates entirely to the device's own PIN, pattern or biometric, so
/// with none enrolled there is nothing to ask for. The fix is in the system
/// settings, and a greyed-out toggle would leave the user concluding the app
/// is broken instead of going there.
class _AppLockSetting extends ConsumerStatefulWidget {
  /// Creates the app lock row.
  const _AppLockSetting();

  @override
  ConsumerState<_AppLockSetting> createState() => _AppLockSettingState();
}

/// State for [_AppLockSetting]: what the device said when it was asked.
///
/// The device is asked once, in `initState`, and nothing at all is rendered
/// until it has answered. A switch that appeared enabled and then disabled
/// itself a frame later would invite a tap that fails.
///
/// Attributes:
///     _reason (LockUnavailableReason?): Why the lock cannot be used.
///     _checked (bool): Whether the device has been asked yet.
class _AppLockSettingState extends ConsumerState<_AppLockSetting> {
  /// Why the lock cannot be used, or null when it can.
  LockUnavailableReason? _reason;

  /// Whether the device has been asked yet. Distinct from `_reason == null`,
  /// which is also true before the question has been put.
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  /// Ask the device whether the lock can be used at all.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the answer is in state, or at once if
  ///     the row has been disposed in the meantime.
  Future<void> _check() async {
    final reason = await ref.read(appLockServiceProvider).unavailableReason();
    if (!mounted) return;
    setState(() {
      _reason = reason;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = ref.watch(appLockEnabledProvider).valueOrNull ?? false;

    // Nothing at all until the device has been asked. Rendering an enabled
    // switch and then disabling it a frame later invites a tap that fails.
    if (!_checked) return const SizedBox(height: 48);

    final reason = _reason;
    if (reason != null) {
      return ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(l10n.settingsAppLock),
        subtitle: Text(
          switch (reason) {
            LockUnavailableReason.noCredentialEnrolled =>
              l10n.settingsAppLockUnavailable,
            LockUnavailableReason.notSupported =>
              l10n.settingsAppLockNotSupported,
          },
        ),
        enabled: false,
      );
    }

    return Column(
      children: <Widget>[
        SwitchListTile(
          value: enabled,
          onChanged: (value) async {
            final settings = ref.read(appDatabaseProvider).settingsDao;
            await settings.writeBool(SettingKey.appLockEnabled, value: value);
            // Turning it on locks immediately rather than at the next launch,
            // so the user sees what they just switched on and can check it
            // works while they are still holding the phone.
            if (value) ref.read(lockControllerProvider).lock();
          },
          title: Text(l10n.settingsAppLock),
          subtitle: Text(l10n.settingsAppLockSubtitle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            l10n.settingsAppLockNotEncrypted,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Preferences that change what is shown, never what is stored.
///
/// Kept apart from the reminder settings for a reason worth stating: everything
/// here is reversible by definition. Turning one on and off again leaves the
/// database exactly as it was, which is what lets the subtitles promise that
/// nothing is lost: a promise `flow_simplified_test.dart` checks rather than
/// takes on trust.
class _DisplaySettings extends ConsumerWidget {
  /// Creates the display preferences.
  const _DisplaySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appDatabaseProvider).settingsDao;
    // Watched rather than loaded into state: the switch and the day editor read
    // the same stream, so they cannot disagree about what is set.
    final simplified = ref.watch(flowSimplifiedProvider).valueOrNull ?? false;
    final phases = ref.watch(showCyclePhasesProvider).valueOrNull ?? true;
    final ovulation =
        ref.watch(showOvulationWindowProvider).valueOrNull ?? false;
    final learnTab = ref.watch(showLearnTabProvider).valueOrNull ?? false;
    return Column(
      children: <Widget>[
        SwitchListTile(
          value: simplified,
          onChanged: (value) =>
              settings.writeBool(SettingKey.flowSimplified, value: value),
          title: Text(l10n.settingsFlowSimplified),
          subtitle: Text(l10n.settingsFlowSimplifiedSubtitle),
        ),
        SwitchListTile(
          value: phases,
          onChanged: (value) =>
              settings.writeBool(SettingKey.showCyclePhases, value: value),
          title: Text(l10n.settingsCyclePhases),
          subtitle: Text(l10n.settingsCyclePhasesSubtitle),
        ),
        // Off until switched on, and the subtitle says what the estimate is
        // worth before the switch is touched rather than after. See ADR-0007
        // and docs/PLAN.md 6.2: this is the one preference on the screen whose
        // default is a safety property.
        SwitchListTile(
          value: ovulation,
          onChanged: (value) =>
              settings.writeBool(SettingKey.showOvulationWindow, value: value),
          title: Text(l10n.settingsOvulationWindow),
          subtitle: Text(l10n.settingsOvulationWindowSubtitle),
        ),
        // Off until switched on, and not a safety gate the way the ovulation
        // window is: the pages behind it make no claim about the reader. The
        // tab is the only way to them, so the subtitle says what it opens.
        SwitchListTile(
          value: learnTab,
          onChanged: (value) =>
              settings.writeBool(SettingKey.showLearnTab, value: value),
          title: Text(l10n.settingsLearnTab),
          subtitle: Text(l10n.settingsLearnTabSubtitle),
        ),
      ],
    );
  }
}

/// A heading over a group of rows.
///
/// Attributes:
///     text (String): The heading, already translated.
class _SectionHeading extends StatelessWidget {
  /// Creates a heading.
  ///
  /// Args:
  ///     text (String): The heading, already translated. Printed as written,
  ///         unlike the appearance screen's, which upper-cases its own.
  const _SectionHeading(this.text);

  /// The heading, already translated.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// The notification preferences.
///
/// Four of them, and two default to off for reasons worth keeping: the nudge
/// is the only notification that is neither a prediction nor actionable, and
/// lock-screen detail is the one place this project's privacy story would
/// otherwise leak by default (risk R16).
class _ReminderSettings extends ConsumerStatefulWidget {
  /// Creates the reminder preferences.
  const _ReminderSettings();

  @override
  ConsumerState<_ReminderSettings> createState() => _ReminderSettingsState();
}

/// State for [_ReminderSettings]: the preferences, read once and held.
///
/// Held in state rather than watched, unlike the display preferences, because
/// changing one has to be followed by a resync: writing the setting is only
/// half of switching a reminder off.
///
/// Attributes:
///     _enabled (bool?): Whether reminders are on. Null until read.
///     _leadDays (int?): How many days ahead to remind. Null until read.
///     _nudge (bool): Whether the logging nudge is on.
///     _detailed (bool): Whether notifications may carry detail.
class _ReminderSettingsState extends ConsumerState<_ReminderSettings> {
  /// Whether reminders are on, or null until the preference has been read.
  bool? _enabled;

  /// How many days ahead to remind, or null until the preference is read.
  int? _leadDays;

  /// Whether the logging nudge is on.
  bool _nudge = false;

  /// Whether notifications may carry detail on the lock screen.
  bool _detailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Ask for the platform schedule to be rebuilt from the new preferences.
  ///
  /// Writing the setting is only half of switching a reminder off: whatever was
  /// already handed to the platform stays queued until something reschedules,
  /// so a user who turns reminders off would still get the next one.
  void _resync() {
    if (!mounted) return;
    ref.read(notificationPreferencesRevisionProvider.notifier).state++;
  }

  /// Read the stored preferences once, defaulting rather than failing.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once all four are in state. A preference
  ///     that was never written falls back to its default rather than
  ///     leaving the row blank.
  Future<void> _load() async {
    final settings = ref.read(appDatabaseProvider).settingsDao;
    final enabled = await settings.readBool(
      SettingKey.reminderEnabled,
      orElse: true,
    );
    final lead = await settings.readInt(
      SettingKey.reminderLeadDays,
      orElse: 2,
    );
    // Both default to off, and are re-read as off. The nudge is the only
    // notification that is neither a prediction nor actionable, and lock-screen
    // detail is the one place this project's privacy story would otherwise leak
    // by default (risk R16).
    final nudge = await settings.readBool(
      SettingKey.nudgeEnabled,
      orElse: false,
    );
    final detailed = await settings.readBool(
      SettingKey.detailedNotifications,
      orElse: false,
    );
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _leadDays = lead;
      _nudge = nudge;
      _detailed = detailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(appDatabaseProvider).settingsDao;
    final enabled = _enabled;
    final leadDays = _leadDays;
    if (enabled == null || leadDays == null) {
      return const SizedBox(height: 48);
    }
    return Column(
      children: <Widget>[
        SwitchListTile(
          value: enabled,
          title: Text(l10n.settingsReminderEnabled),
          // States what actually arrives and when. The lock-screen half of the
          // answer belongs to the detail switch below, which is where a user
          // looking for it will be (risk R16).
          subtitle: Text(l10n.settingsReminderSubtitle),
          onChanged: (value) async {
            setState(() => _enabled = value);
            await settings.writeBool(
              SettingKey.reminderEnabled,
              value: value,
            );
            _resync();
          },
        ),
        SwitchListTile(
          value: _nudge,
          title: Text(l10n.settingsNudgeEnabled),
          subtitle: Text(l10n.settingsNudgeSubtitle),
          onChanged: (value) async {
            setState(() => _nudge = value);
            await settings.writeBool(SettingKey.nudgeEnabled, value: value);
            _resync();
          },
        ),
        SwitchListTile(
          value: _detailed,
          title: Text(l10n.settingsDetailedNotifications),
          subtitle: Text(l10n.settingsDetailedNotificationsSubtitle),
          onChanged: (value) async {
            setState(() => _detailed = value);
            await settings.writeBool(
              SettingKey.detailedNotifications,
              value: value,
            );
            _resync();
          },
        ),
        ListTile(
          title: Text(l10n.settingsReminderLeadDays),
          subtitle: Text(l10n.settingsReminderDaysValue(leadDays)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final days in const <int>[1, 2, 3])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChipMotion(
                    selected: leadDays == days,
                    builder: (context, checkSlot) => ChoiceChip(
                      avatar: checkSlot,
                      selected: leadDays == days,
                      label: Text('$days'),
                      onSelected: (_) async {
                        setState(() => _leadDays = days);
                        await settings.writeInt(
                          SettingKey.reminderLeadDays,
                          days,
                        );
                        _resync();
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
