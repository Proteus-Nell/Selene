// The one-time re-export prompt (AND-28, ADR-0011).
//
// This banner is the whole mitigation for a decision that costs users
// something real. Export format v2 refuses v1 files, and this app has no cloud
// sync and no Play Store restore — the export file *is* the recovery path (risk
// R8) — so every backup a user is holding stops working the moment they update.
//
// That is defensible only if they are told while they still have a working
// phone to export from. Discovering it after losing the phone is not a
// trade-off anyone agreed to. So the conditions under which this appears, and
// the conditions under which it does not, are worth testing carefully in both
// directions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/log/log_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// Puts the database in the state an upgrade leaves it in.
  ///
  /// A database written before AND-28 simply has no acknowledgement row; that
  /// absence is the signal, which is why simulating an upgrade is a delete
  /// rather than a flag.
  Future<void> simulateUpgradeFromOlderBuild() => db.customStatement(
    'DELETE FROM settings WHERE setting_key = ?',
    <Object?>[SettingKey.exportFormatAcknowledged.wireName],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LogScreen(), database: db));
    await tester.pumpAndSettle();
  }

  group('a fresh install', () {
    testWidgets('is never warned about backups it has never taken', (
      tester,
    ) async {
      // The acknowledgement is seeded at onCreate for exactly this. Warning a
      // new user that their backups will not restore is both alarming and
      // false.
      await pump(tester);
      expect(find.text(l10nOf(tester).reExportTitle), findsNothing);
    });
  });

  group('after updating from an older build', () {
    testWidgets('the warning appears on the log screen', (tester) async {
      // On the log screen rather than in settings, because it has to reach
      // someone who never opens settings — which is most people, and settings
      // is where a user who already backs up regularly would look anyway.
      await simulateUpgradeFromOlderBuild();
      await pump(tester);
      expect(find.text(l10nOf(tester).reExportTitle), findsOneWidget);
    });

    testWidgets('it says the old files will not restore, and that the data '
        'in the app is fine', (tester) async {
      // Both halves matter. A user who reads only the first sentence must not
      // conclude their history is gone.
      await simulateUpgradeFromOlderBuild();
      await pump(tester);
      final body = l10nOf(tester).reExportBody.toLowerCase();
      expect(
        body.contains('no longer be restored') || body.contains('cannot'),
        isTrue,
        reason: 'the warning does not say the old files will not restore',
      );
      expect(
        body,
        contains('untouched'),
        reason:
            'the warning does not say the data in the app is safe, so it reads '
            'as an announcement of data loss',
      );
    });

    testWidgets('dismissing it takes it away and keeps it away', (
      tester,
    ) async {
      // Dismissing counts. The release notes carry the same message, and a
      // warning that returns every launch is one people learn to tap past
      // without reading, which costs it the one audience it has.
      await simulateUpgradeFromOlderBuild();
      await pump(tester);

      await tester.tap(find.text(l10nOf(tester).reExportDismiss));
      await tester.pumpAndSettle();

      expect(find.text(l10nOf(tester).reExportTitle), findsNothing);
      expect(await db.settingsDao.needsReExportPrompt(), isFalse);
    });

    testWidgets('opening settings does not count as having exported', (
      tester,
    ) async {
      // Only a completed export clears it. Otherwise a user who taps through
      // and then changes their mind loses the warning without ever having a
      // new file.
      await simulateUpgradeFromOlderBuild();
      await pump(tester);

      await tester.tap(find.text(l10nOf(tester).reExportAction));
      await tester.pumpAndSettle();

      expect(
        await db.settingsDao.needsReExportPrompt(),
        isTrue,
        reason: 'navigating to settings silently cleared the warning',
      );
    });

    testWidgets('an export clears it', (tester) async {
      // Asserted at the DAO rather than by driving the file picker, which
      // needs a platform channel. The settings screen calls exactly this on a
      // successful write.
      await simulateUpgradeFromOlderBuild();
      await pump(tester);
      expect(find.text(l10nOf(tester).reExportTitle), findsOneWidget);

      await db.settingsDao.acknowledgeExportFormat();
      await tester.pumpAndSettle();

      expect(find.text(l10nOf(tester).reExportTitle), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('the warning survives a 200% text scale', (tester) async {
      await simulateUpgradeFromOlderBuild();
      await tester.pumpWidget(
        harness(
          const LogScreen(),
          database: db,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
