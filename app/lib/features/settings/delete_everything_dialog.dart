import 'package:flutter/material.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Asks the user to type a word before deleting everything.
///
/// A typed confirmation rather than a second "are you sure", because this is
/// the one action in the app with no undo and no copy anywhere else: there is
/// no cloud backup by design, so if the user has not exported, the data is
/// simply gone. Making the confirmation cost a deliberate act is proportionate
/// to that.
///
/// Returns true only if the user typed the word and confirmed.
Future<bool?> showDeleteEverythingDialog(
  BuildContext context, {
  required int loggedDays,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => _DeleteEverythingDialog(loggedDays: loggedDays),
);

class _DeleteEverythingDialog extends StatefulWidget {
  const _DeleteEverythingDialog({required this.loggedDays});

  final int loggedDays;

  @override
  State<_DeleteEverythingDialog> createState() =>
      _DeleteEverythingDialogState();
}

class _DeleteEverythingDialogState extends State<_DeleteEverythingDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final word = l10n.settingsDeleteConfirmWord;
    return AlertDialog(
      title: Text(l10n.settingsDeleteConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.settingsDeleteConfirmBody(widget.loggedDays, word)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.settingsDeleteConfirmHint(word),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) =>
                setState(() => _matches = value.trim() == word),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
