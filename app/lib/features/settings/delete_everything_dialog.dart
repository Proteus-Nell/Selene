/// Delete-everything confirmation.
///
/// Asks the user to type a word before the one action in the app that has no
/// undo and no copy anywhere else. There is no cloud backup by design, so a
/// user who has not exported loses everything the app holds for them.
///
/// Includes:
///     - showDeleteEverythingDialog: Opens the dialog, reports the answer.
///     - _DeleteEverythingDialog: The dialog itself.
///     - _DeleteEverythingDialogState: What has been typed, and whether it
///       matches.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Ask the user to type a word before deleting everything.
///
/// A typed confirmation rather than a second "are you sure", because this is
/// the one action in the app with no undo and no copy anywhere else: there is
/// no cloud backup by design, so if the user has not exported, the data is
/// simply gone. Making the confirmation cost a deliberate act is proportionate
/// to that.
///
/// Args:
///     context (BuildContext): What to open the dialog over.
///     loggedDays (int): How many days are about to go, quoted back to the
///         user so the size of it is in front of them while they decide.
///
/// Returns:
///     `Future<bool?>`: True only if the user typed the word and confirmed.
///     False on cancel, and null if the dialog was dismissed by tapping away
///     or by the back gesture, both of which must be read as "no".
Future<bool?> showDeleteEverythingDialog(
  BuildContext context, {
  required int loggedDays,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => _DeleteEverythingDialog(loggedDays: loggedDays),
);

/// The dialog: what is about to go, a word to type, and the delete button.
///
/// Attributes:
///     loggedDays (int): How many days are about to go.
class _DeleteEverythingDialog extends StatefulWidget {
  /// Creates the dialog.
  ///
  /// Args:
  ///     loggedDays (int): How many days are about to go.
  const _DeleteEverythingDialog({required this.loggedDays});

  /// How many days are about to go.
  final int loggedDays;

  @override
  State<_DeleteEverythingDialog> createState() =>
      _DeleteEverythingDialogState();
}

/// State for [_DeleteEverythingDialog]: what has been typed so far.
///
/// Attributes:
///     _controller (TextEditingController): The typed text.
///     _matches (bool): Whether it matches the required word, which is the
///         only thing that enables the delete button.
class _DeleteEverythingDialogState extends State<_DeleteEverythingDialog> {
  /// The typed text.
  final TextEditingController _controller = TextEditingController();

  /// Whether the typed text matches the required word, trimmed.
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
    // No `insetPadding` override here, deliberately. The obvious fix for a
    // dialog under a cutout is to inset it by MediaQuery's view padding, and it
    // is dead code: `showDialog` defaults to `useSafeArea: true`, so by the
    // time this builder runs the cutout has already been consumed and both
    // `paddingOf` and `viewPaddingOf` read zero. An override computed from them
    // reproduces Material's default of 40 horizontal, 24 vertical exactly.
    //
    // What actually put this dialog under the cutout is below: it carries a
    // text field, so the keyboard opens under it and the space left over is
    // shorter than the dialog. An unscrollable dialog does not shrink to fit.
    // It overflows its box in both directions and paints straight through the
    // safe area, which is why the title appeared behind the camera.
    return AlertDialog(
      // AlertDialog's own `scrollable`, not a SingleChildScrollView inside the
      // content. The difference matters at a large text scale: a scroll view
      // in the content still leaves the title and the actions to be laid out
      // around it, and their combined height is what pushed the dialog past
      // the top of the screen. `scrollable` puts the title in the scroll view
      // too, so the whole dialog can shrink to fit.
      scrollable: true,
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
