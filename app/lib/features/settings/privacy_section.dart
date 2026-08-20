import 'package:flutter/material.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The privacy statement, shown in full inside the app.
///
/// The same text as `docs/PRIVACY.md`, and `privacy_text_test.dart` fails if
/// the two drift apart. It is here rather than behind a link because the
/// paragraph that matters most is the one saying the database is **not**
/// encrypted, and a promise the user has to go looking for is not a promise
/// (DECISIONS.md ADR-0004).
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
        _Paragraph(l10n.privacyNotEncryptedTitle, l10n.privacyNotEncryptedBody),
        _Paragraph(l10n.privacyBackupTitle, l10n.privacyBackupBody),
        _Paragraph(l10n.privacyDeletionTitle, l10n.privacyDeletionBody),
        _Paragraph(l10n.privacyLogsTitle, l10n.privacyLogsBody),
        _Paragraph(l10n.privacyExportTitle, l10n.privacyExportBody),
      ],
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.title, this.body);

  final String title;
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
