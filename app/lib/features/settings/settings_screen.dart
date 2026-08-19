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
import 'package:period_tracker/features/settings/delete_everything_dialog.dart';
import 'package:period_tracker/features/settings/log_viewer.dart';
import 'package:period_tracker/features/settings/privacy_section.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Data controls, the privacy statement, and the activity log.
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

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
      _report(l10n.settingsExportDone(envelope.dayLogs.length));
    } on FileSystemException {
      _report(l10n.settingsExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                l10n.settingsAboutBody,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

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

class _ReminderSettings extends ConsumerStatefulWidget {
  const _ReminderSettings();

  @override
  ConsumerState<_ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends ConsumerState<_ReminderSettings> {
  bool? _enabled;
  int? _leadDays;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Reads the stored preferences once, defaulting rather than failing.
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
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _leadDays = lead;
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
          // Honest about the state of the build: the preference is stored, and
          // AND-17 is what turns it into a scheduled notification.
          subtitle: Text(l10n.settingsReminderNotYetScheduled),
          onChanged: (value) async {
            setState(() => _enabled = value);
            await settings.writeBool(
              SettingKey.reminderEnabled,
              value: value,
            );
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
                  child: ChoiceChip(
                    selected: leadDays == days,
                    label: Text('$days'),
                    onSelected: (_) async {
                      setState(() => _leadDays = days);
                      await settings.writeInt(
                        SettingKey.reminderLeadDays,
                        days,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
