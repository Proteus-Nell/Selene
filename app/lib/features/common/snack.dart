import 'package:flutter/material.dart';

/// How long a plain confirmation stays on screen.
const Duration _plainSnackDuration = Duration(seconds: 4);

/// How long a confirmation that offers an action stays on screen.
///
/// Longer than a plain one because there is something to do with it: read the
/// message, decide it was a mistake, reach for Undo. Four seconds is enough to
/// read a sentence and not enough to change your mind about it.
const Duration _actionableSnackDuration = Duration(seconds: 7);

/// Shows [message] as a pop-up that goes away by itself.
///
/// Every pop-up in the app goes through here rather than calling
/// `showSnackBar` directly, because of one line in Flutter's `SnackBar`
/// constructor:
///
/// ```dart
/// persist = persist ?? action != null;
/// ```
///
/// Any snack bar carrying an action therefore defaults to **never timing out**.
/// The timer still fires, looks at `persist`, and returns without hiding
/// anything. That is a defensible default for a library — an action the user
/// never saw is an action they never had — and the wrong one here: these
/// pop-ups confirm a tap that was just made, and a confirmation that has to be
/// swiped away by hand costs more attention than it conveys. Logging a period
/// left one on screen indefinitely.
///
/// The exception is a screen reader. [action] is reachable only after the
/// message has been announced and navigated to, and seven seconds is not enough
/// for that, so the timeout is dropped exactly when `accessibleNavigation` says
/// someone is using one — which is the behaviour Flutter's own documentation
/// describes for an actioned snack bar. Those get a close button, so there is
/// always a deliberate way out of a pop-up that will not leave on its own.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final persist = action != null && MediaQuery.accessibleNavigationOf(context);
  ScaffoldMessenger.of(context)
    // One at a time. These confirm the most recent action, so a queue of them
    // would report a tap the user has already moved on from.
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: action == null
            ? _plainSnackDuration
            : _actionableSnackDuration,
        persist: persist,
        showCloseIcon: persist,
      ),
    );
}
