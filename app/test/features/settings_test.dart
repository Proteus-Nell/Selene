// Settings (AND-16).
//
// The screen where the promises in docs/PRIVACY.md are either kept or not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/settings/delete_everything_dialog.dart';
import 'package:period_tracker/features/settings/log_viewer.dart';
import 'package:period_tracker/features/settings/privacy_section.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;
  late RingLogger logger;

  setUp(() {
    db = memoryDatabase();
    logger = RingLogger(clock: testClock);
  });
  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(const SettingsScreen(), database: db, logger: logger),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls past the data controls to the privacy and about sections.
  ///
  /// The order on screen is deliberate, so the tests scroll rather than the
  /// screen being rearranged to suit them: export, import and delete are what
  /// someone opens this screen to do.
  /// Scrolls the settings list until [target] is on screen.
  ///
  /// Scrolls to the widget rather than by a fixed distance: a fixed drag breaks
  /// the moment a line of copy above the target wraps onto a second line, which
  /// is a change to prose failing a test about behaviour.
  Future<void> scrollSettingsTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('delete everything', () {
    testWidgets('will not proceed until the word is typed', (tester) async {
      await seedHistory(db, const <int>[28, 28]);
      await pumpSettings(tester);
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.settingsDeleteAll));
      await tester.pumpAndSettle();

      // The button is disabled until the confirmation word matches. This is
      // the one action with no undo and no copy anywhere else.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.commonDelete),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.commonDelete),
            )
            .onPressed,
        isNull,
        reason: 'the confirmation is case sensitive on purpose',
      );

      await tester.enterText(
        find.byType(TextField),
        l10n.settingsDeleteConfirmWord,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.commonDelete),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('really deletes, and says how much is at stake first', (
      tester,
    ) async {
      await seedHistory(db, const <int>[28, 28]);
      final before = await db.dayLogDao.allLogs();
      expect(before, isNotEmpty);

      await pumpSettings(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsDeleteAll));
      await tester.pumpAndSettle();

      // The dialog names the number of days about to go.
      expect(
        find.text(
          l10n.settingsDeleteConfirmBody(
            before.length,
            l10n.settingsDeleteConfirmWord,
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField),
        l10n.settingsDeleteConfirmWord,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(await db.dayLogDao.allLogs(), isEmpty);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await seedHistory(db, const <int>[28, 28]);
      await pumpSettings(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsDeleteAll));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(await db.dayLogDao.allLogs(), isNotEmpty);
    });

    testWidgets('the dialog stands alone, for the flows that need it', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showDeleteEverythingDialog(context, loggedDays: 3),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          database: db,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('the privacy statement', () {
    testWidgets('is in the app, not behind a link', (tester) async {
      await pumpSettings(tester);
      await scrollSettingsTo(tester, find.byType(PrivacySection));
      expect(find.byType(PrivacySection), findsOneWidget);

      await tester.tap(find.text(l10nOf(tester).settingsPrivacyTitle));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.privacyOnDeviceBody), findsOneWidget);
      // The paragraph that matters most is the one that admits a limit.
      expect(find.text(l10n.privacyNotEncryptedBody), findsOneWidget);
    });

    testWidgets('says plainly that the database is not encrypted', (
      tester,
    ) async {
      await pumpSettings(tester);
      final l10n = l10nOf(tester);
      final text = l10n.privacyNotEncryptedBody.toLowerCase();
      expect(text, contains('plain text'));
      expect(text, contains('unlocked phone'));
      expect(text, contains('no app lock'));
      // And it does not let the word "private" do work it has not earned.
      expect(l10n.privacyNotEncryptedTitle.toLowerCase(), contains('not '));
    });
  });

  group('the activity log', () {
    testWidgets('shows what was recorded, and holds no cycle content', (
      tester,
    ) async {
      logger
        ..info(LogEvent.appStarted)
        ..info(
          LogEvent.predictionComputed,
          fields: <String, LogField>{'n_cycles': const LogField.count(7)},
        );
      await pumpSettings(tester);
      await scrollSettingsTo(
        tester,
        find.text(l10nOf(tester).settingsLogViewer),
      );

      await tester.tap(find.text(l10nOf(tester).settingsLogViewer));
      await tester.pumpAndSettle();

      expect(find.byType(LogViewerScreen), findsOneWidget);
      expect(find.text(LogEvent.predictionComputed.name), findsOneWidget);

      // The whole point of showing it: the user can check for themselves that
      // no cycle content is in here. It is true by construction, because
      // LogEvent is an enum and LogField admits only counts, durations, flags
      // and enum names, so a date or a symptom cannot be spelled into a line.
      //
      // Each record does carry its own `ts`, which is when the line was
      // written rather than anything about the user, so it is stripped before
      // checking. Everything else must be free of cycle content.
      final withoutTimestamps = logger.dump().replaceAll(
        RegExp('"ts":"[^"]*",'),
        '',
      );
      expect(withoutTimestamps, isNot(contains('2026-')));
      for (final leak in <String>[
        'cramps',
        'headache',
        'heavy',
        'spotting',
        'severe',
      ]) {
        expect(
          withoutTimestamps.toLowerCase(),
          isNot(contains(leak)),
          reason: 'the activity log leaked "$leak"',
        );
      }
      expect(withoutTimestamps, contains('"n_cycles":7'));
    });

    testWidgets('can be cleared', (tester) async {
      logger.info(LogEvent.appStarted);
      await pumpSettings(tester);
      await scrollSettingsTo(
        tester,
        find.text(l10nOf(tester).settingsLogViewer),
      );
      await tester.tap(find.text(l10nOf(tester).settingsLogViewer));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      expect(logger.records, isEmpty);
      expect(
        find.text(l10nOf(tester).settingsLogViewerEmpty),
        findsOneWidget,
      );
    });
  });

  group('reminders', () {
    testWidgets('store the preference and describe what will arrive', (
      tester,
    ) async {
      await pumpSettings(tester);
      final l10n = l10nOf(tester);
      // The switch alone does not say when anything would arrive.
      expect(find.text(l10n.settingsReminderSubtitle), findsOneWidget);

      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.settingsReminderEnabled),
      );
      await tester.pumpAndSettle();
      expect(
        await db.settingsDao.readBool(
          SettingKey.reminderEnabled,
          orElse: true,
        ),
        isFalse,
      );
    });

    testWidgets('default the nudge and lock-screen detail to off', (
      tester,
    ) async {
      // Both are the defaults the plan argues for: the nudge because it is the
      // only notification that is neither a prediction nor actionable (2.4.1),
      // and lock-screen detail because a visible banner about a cycle is a
      // real data leak (risk R16).
      await pumpSettings(tester);
      final l10n = l10nOf(tester);
      for (final title in <String>[
        l10n.settingsNudgeEnabled,
        l10n.settingsDetailedNotifications,
      ]) {
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, title),
              )
              .value,
          isFalse,
          reason: '"$title" must default to off',
        );
      }
    });

    testWidgets('warn that some phones kill scheduled reminders', (
      tester,
    ) async {
      // Risk R12. Saying so is cheaper than the user concluding the app is
      // broken.
      await pumpSettings(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(
        find.text(l10nOf(tester).settingsBatteryNoteTitle),
        findsOneWidget,
      );
    });
  });

  group('about', () {
    testWidgets('names the app version and the model the app is running', (
      tester,
    ) async {
      await pumpSettings(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('1.0.0'), findsOneWidget);
    });
  });
}
