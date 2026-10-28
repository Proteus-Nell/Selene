// The two questions a protected backup asks (ADR-0019).
//
// The export and import around them are run end to end in the smoke flow.
// What is pinned here is the dialogs' own rules: a passphrase too short or
// typed differently twice is refused with a reason, and an export without one
// is a choice of its own rather than what happens on the way out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/transfer/protected_backup.dart';
import 'package:period_tracker/features/settings/backup_dialogs.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

void main() {
  late Object? answer;

  Future<AppLocalizations> pumpOpener(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) open,
  ) async {
    answer = 'unanswered';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answer = await open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(AlertDialog)));
  }

  group('the protect dialog', () {
    testWidgets('refuses a passphrase that is too short, and says why', (
      tester,
    ) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'short');
      await tester.enterText(fields.at(1), 'short');
      await tester.tap(find.text(l10n.settingsExportWithPassphrase));
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.settingsExportPassphraseTooShort(
            ProtectedBackup.minimumPassphraseLength,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('refuses two passphrases that differ', (tester) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'four unrelated words');
      await tester.enterText(fields.at(1), 'four unrelated wordz');
      await tester.tap(find.text(l10n.settingsExportWithPassphrase));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsExportPassphraseMismatch), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('hands back the passphrase once it is right', (tester) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'four unrelated words');
      await tester.enterText(fields.at(1), 'four unrelated words');
      await tester.tap(find.text(l10n.settingsExportWithPassphrase));
      await tester.pumpAndSettle();
      expect(answer, isA<ExportChoice>());
      expect((answer! as ExportChoice).passphrase, 'four unrelated words');
    });

    testWidgets('offers an export without one, as a choice of its own', (
      tester,
    ) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      await tester.tap(find.text(l10n.settingsExportWithoutPassphrase));
      await tester.pumpAndSettle();
      expect(answer, isA<ExportChoice>());
      expect((answer! as ExportChoice).passphrase, isNull);
    });

    testWidgets('can be cancelled, which exports nothing', (tester) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(answer, isNull);
    });

    testWidgets('hides the passphrase until asked to show it', (tester) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField).first).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip(l10n.settingsPassphraseShow));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('says a forgotten passphrase cannot be recovered', (
      tester,
    ) async {
      final l10n = await pumpOpener(tester, showProtectBackupDialog);
      expect(find.text(l10n.settingsExportProtectBody), findsOneWidget);
      expect(
        l10n.settingsExportProtectBody.toLowerCase(),
        contains('nobody can recover'),
      );
    });
  });

  group('the open dialog', () {
    testWidgets('hands back what was typed', (tester) async {
      final l10n = await pumpOpener(tester, showOpenBackupDialog);
      await tester.enterText(find.byType(TextField), 'four unrelated words');
      await tester.tap(find.text(l10n.settingsImportPassphraseOpen));
      await tester.pumpAndSettle();
      expect(answer, 'four unrelated words');
    });

    testWidgets('says why the last one did not open it', (tester) async {
      const reason = 'That passphrase does not open this backup.';
      await pumpOpener(
        tester,
        (context) => showOpenBackupDialog(context, error: reason),
      );
      expect(find.text(reason), findsOneWidget);
    });
  });
}
