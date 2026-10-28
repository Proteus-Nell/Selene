/// Backup dialogs.
///
/// The two questions a protected backup asks (ADR-0019): whether to protect an
/// export, and the passphrase to open one with.
///
/// Includes:
///     - ExportChoice: What the protect dialog decided.
///     - showProtectBackupDialog: Ask whether to protect an export.
///     - showOpenBackupDialog: Ask for a protected backup's passphrase.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/data/transfer/protected_backup.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Export choice: a passphrase to protect the export with, or none.
///
/// Attributes:
///     passphrase (String?): What the person chose, or null for an export
///         without one.
@immutable
final class ExportChoice {
  /// Creates the choice.
  ///
  /// Args:
  ///     passphrase (String?, optional): Defaults to null, no passphrase.
  const ExportChoice({this.passphrase});

  /// What the person chose, or null for an export without one.
  final String? passphrase;
}

/// Ask whether to protect an export with a passphrase.
///
/// Asked before the folder is chosen, every time, because a backup is the one
/// copy of this data that leaves the app, and where it ends up decides who can
/// read it. Without a passphrase is a choice offered beside the other, not a
/// default hidden behind it.
///
/// Args:
///     context (BuildContext): What to show the dialog over.
///
/// Returns:
///     `Future<ExportChoice?>`: The choice, or null when the export was
///     cancelled.
Future<ExportChoice?> showProtectBackupDialog(BuildContext context) =>
    showDialog<ExportChoice>(
      context: context,
      builder: (context) => const _ProtectBackupDialog(),
    );

/// Ask for the passphrase a protected backup was sealed with.
///
/// Args:
///     context (BuildContext): What to show the dialog over.
///     error (String?, optional): Why the last passphrase did not open it.
///         Defaults to null.
///
/// Returns:
///     `Future<String?>`: The passphrase typed, or null when the import was
///     cancelled.
Future<String?> showOpenBackupDialog(BuildContext context, {String? error}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _OpenBackupDialog(error: error),
    );

/// The protect dialog: a passphrase twice, or an export without one.
class _ProtectBackupDialog extends StatefulWidget {
  const _ProtectBackupDialog();

  @override
  State<_ProtectBackupDialog> createState() => _ProtectBackupDialogState();
}

/// State for [_ProtectBackupDialog].
///
/// Attributes:
///     _passphrase (TextEditingController): The passphrase.
///     _confirm (TextEditingController): The same again.
///     _visible (bool): Whether both are shown as typed.
///     _error (String?): Why the last attempt to protect was refused.
class _ProtectBackupDialogState extends State<_ProtectBackupDialog> {
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Protect with the passphrase, if it is long enough and typed the same
  /// twice.
  void _protect() {
    final l10n = AppLocalizations.of(context);
    final passphrase = _passphrase.text;
    if (passphrase.length < ProtectedBackup.minimumPassphraseLength) {
      setState(
        () => _error = l10n.settingsExportPassphraseTooShort(
          ProtectedBackup.minimumPassphraseLength,
        ),
      );
      return;
    }
    if (passphrase != _confirm.text) {
      setState(() => _error = l10n.settingsExportPassphraseMismatch);
      return;
    }
    Navigator.of(context).pop(ExportChoice(passphrase: passphrase));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final toggle = IconButton(
      tooltip: _visible
          ? l10n.settingsPassphraseHide
          : l10n.settingsPassphraseShow,
      icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _visible = !_visible),
    );
    return AlertDialog(
      // Scrollable, so the keyboard and a large text scale shrink the dialog
      // rather than pushing its buttons off the screen.
      scrollable: true,
      title: Text(l10n.settingsExportProtectTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.settingsExportProtectBody),
          const SizedBox(height: 16),
          TextField(
            controller: _passphrase,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.settingsExportPassphraseLabel,
              suffixIcon: toggle,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.settingsExportPassphraseConfirmLabel,
            ),
            onSubmitted: (_) => _protect(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(const ExportChoice()),
          child: Text(l10n.settingsExportWithoutPassphrase),
        ),
        FilledButton(
          onPressed: _protect,
          child: Text(l10n.settingsExportWithPassphrase),
        ),
      ],
    );
  }
}

/// The open dialog: the passphrase a protected backup was sealed with.
///
/// Attributes:
///     error (String?): Why the last passphrase did not open it.
class _OpenBackupDialog extends StatefulWidget {
  const _OpenBackupDialog({this.error});

  /// Why the last passphrase did not open it.
  final String? error;

  @override
  State<_OpenBackupDialog> createState() => _OpenBackupDialogState();
}

/// State for [_OpenBackupDialog].
///
/// Attributes:
///     _passphrase (TextEditingController): The passphrase.
///     _visible (bool): Whether it is shown as typed.
class _OpenBackupDialogState extends State<_OpenBackupDialog> {
  final TextEditingController _passphrase = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  void _open() => Navigator.of(context).pop(_passphrase.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.settingsImportPassphraseTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.settingsImportPassphraseBody),
          const SizedBox(height: 16),
          TextField(
            controller: _passphrase,
            autofocus: true,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.settingsExportPassphraseLabel,
              suffixIcon: IconButton(
                tooltip: _visible
                    ? l10n.settingsPassphraseHide
                    : l10n.settingsPassphraseShow,
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
            onSubmitted: (_) => _open(),
          ),
          if (widget.error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _open,
          child: Text(l10n.settingsImportPassphraseOpen),
        ),
      ],
    );
  }
}
