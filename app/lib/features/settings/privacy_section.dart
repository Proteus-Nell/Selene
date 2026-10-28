/// The privacy statement section.
///
/// Renders the whole privacy text inside Settings rather than behind a link,
/// because the paragraph that matters most is the one saying what the
/// encryption does not protect, and a limit the user has to go looking for is
/// not a stated limit.
///
/// Includes:
///     - PrivacySection: The expandable section.
///     - _Paragraph: One heading and its body.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Privacy section: the privacy statement, shown in full inside the app.
///
/// The same text as `docs/PRIVACY.md`, and `privacy_text_test.dart` fails if
/// the two drift apart. It is here rather than behind a link because the
/// paragraph that matters most is the one saying what the encryption does
/// **not** protect: an unlocked phone (DECISIONS.md ADR-0018).
class PrivacySection extends StatelessWidget {
  /// Creates the privacy section.
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      leading: const Icon(Icons.lock_outline),
      title: Text(l10n.settingsPrivacyTitle),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Paragraph(l10n.privacyOnDeviceTitle, l10n.privacyOnDeviceBody),
        _Paragraph(l10n.privacySharingTitle, l10n.privacySharingBody),
        _Paragraph(l10n.privacyEncryptedTitle, l10n.privacyEncryptedBody),
        _Paragraph(l10n.privacyBackupTitle, l10n.privacyBackupBody),
        _Paragraph(l10n.privacyDeletionTitle, l10n.privacyDeletionBody),
        _Paragraph(l10n.privacyLogsTitle, l10n.privacyLogsBody),
        _Paragraph(l10n.privacyExportTitle, l10n.privacyExportBody),
      ],
    );
  }
}

/// One paragraph of the privacy statement: a heading and its body.
///
/// Attributes:
///     title (String): The heading.
///     body (String): The paragraph beneath it.
class _Paragraph extends StatelessWidget {
  /// Creates a paragraph.
  ///
  /// Args:
  ///     title (String): The heading.
  ///     body (String): The paragraph beneath it.
  const _Paragraph(this.title, this.body);

  /// The heading.
  final String title;

  /// The paragraph beneath it.
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
