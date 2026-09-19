/// Browser hand-off.
///
/// The one place the app causes a network request to happen. It does not make
/// one: the browser does, in its own process, on the user's explicit action,
/// using no permission this app holds.
///
/// Includes:
///     - BrowserHandoff: The search base, the URL builder, and the
///       confirmation that has to precede a hand-off.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Browser hand-off: sends a search out, after saying what that means.
///
/// This is the one place the app causes a network request to happen, and it
/// does not make one: the browser does, in its own process, on the user's
/// explicit action, using no permission this app holds. That is what lets
/// ADR-0004 stand unamended and `assert_no_network.sh` stay green (ADR-0009).
///
/// **Always [LaunchMode.externalApplication].** `url_launcher_android` ships
/// a `WebViewActivity`, and `inAppWebView` would render the page *inside this
/// app*, which would mean this app making the request, which would need
/// `INTERNET`, which would reverse the whole privacy posture. It is one enum
/// value away and `browser_handoff_test.dart` fails the build on it.
abstract final class BrowserHandoff {
  /// Where a search is sent.
  ///
  /// A plain search engine rather than a drug database, deliberately. Sending
  /// the user to a specific medical site would be this app recommending a
  /// source, and the whole reason for the hand-off is that the app has stopped
  /// having an opinion at this point.
  static const String searchBase = 'https://duckduckgo.com/?q=';

  /// Build the URL a search would open.
  ///
  /// Exposed so a test can assert the term is encoded rather than
  /// concatenated; a drug name with a space or an ampersand in it would
  /// otherwise build a URL that searches for something else.
  ///
  /// Args:
  ///     term (String): What to search for.
  ///
  /// Returns:
  ///     Uri: The search URL, with [term] encoded as a query component.
  static Uri urlFor(String term) =>
      Uri.parse('$searchBase${Uri.encodeQueryComponent(term)}');

  /// Ask first, then open the browser.
  ///
  /// The confirmation is not a formality. A user who has been told all through
  /// this app that nothing leaves their device is entitled to be told, in
  /// specific terms, at the moment that stops being true: that the browser
  /// makes the request, that the browser keeps the history, and, when a term
  /// is pre-filled, exactly which words are about to end up in it.
  ///
  /// Args:
  ///     context (BuildContext): Where the dialog is shown.
  ///     term (String?, optional): What to search for, named back to the user
  ///         in the dialog. Defaults to null, which searches for a general
  ///         phrase instead.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether the browser opened. False when the user
  ///     declined.
  static Future<bool> confirmAndOpen(
    BuildContext context, {
    String? term,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.lookupLeavingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.lookupLeavingBody),
            if (term != null && term.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              // Named back to the user. A hand-off that silently carries a
              // drug name into browser history is precisely what this warning
              // exists to prevent, and "a search" would not tell them which.
              Text(l10n.lookupLeavingWithTermBody(term.trim())),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.lookupLeavingContinue),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    return launchUrl(
      urlFor(term?.trim() ?? 'menstrual cycle health information'),
      // See the class comment. Never inAppWebView.
      mode: LaunchMode.externalApplication,
    );
  }
}
