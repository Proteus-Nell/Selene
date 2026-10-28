// The summary for a doctor and the spreadsheet files, made from Settings
// (ADR-0024).
//
// What is pinned here is the path a person takes: the question that says what
// goes in and that intercourse never does, a folder they choose, and the files
// that land in it. The folder picker is platform code, so it is faked to answer
// with a temporary directory; everything behind it is the app's own, writing
// real files. summary_pdf_test.dart and summary_csv_test.dart cover what is in
// them.

import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';

import '../e2e/smoke_flow.dart' show FakeFileSelector;
import 'harness.dart';

void main() {
  late AppDatabase db;
  late Directory folder;

  setUp(() {
    db = memoryDatabase();
    folder = Directory.systemTemp.createTempSync('selene-summary-');
    FileSelectorPlatform.instance = FakeFileSelector(directory: folder);
  });
  tearDown(() async {
    await db.close();
    folder.deleteSync(recursive: true);
  });

  /// Alternate the real event loop, where files and SQLite finish, with
  /// frames, where the screen moves on, until the screen is idle.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 30; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          round > 2) {
        return;
      }
    }
  }

  Future<void> open(WidgetTester tester, {bool logged = true}) async {
    if (logged) {
      await tester.runAsync(
        () => CycleRepository(database: db, clock: testClock).addAll(
          <DayLog>[
            DayLog(
              date: CivilDate(2026, 5, 3),
              flow: FlowIntensity.heavy,
              symptoms: const <Symptom, SymptomSeverity>{
                Symptom.cramps: SymptomSeverity.moderate,
              },
              intercourse: Intercourse.protected,
            ),
            DayLog(date: CivilDate(2026, 6, 1), flow: FlowIntensity.medium),
          ],
        ),
      );
    }
    await tester.pumpWidget(harness(const SettingsScreen(), database: db));
    await tester.pumpAndSettle();
  }

  /// Tap the row titled [title], and answer the question with [span].
  Future<void> make(WidgetTester tester, String title, String span) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(span));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  testWidgets('asks how far back, and says what goes in and what never does', (
    tester,
  ) async {
    await open(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.settingsSummary));
    await tester.pumpAndSettle();
    expect(find.text(l10n.summarySpanTitle), findsOneWidget);
    expect(find.text(l10n.summarySpanBody), findsOneWidget);
    expect(l10n.summarySpanBody, contains('Intercourse is never included'));
    for (final span in <String>[
      l10n.summarySpanThreeMonths,
      l10n.summarySpanSixMonths,
      l10n.summarySpanYear,
      l10n.summarySpanEverything,
    ]) {
      expect(find.text(span), findsOneWidget);
    }
  });

  testWidgets('writes the PDF in the folder chosen', (tester) async {
    await open(tester);
    final l10n = l10nOf(tester);
    await make(tester, l10n.settingsSummary, l10n.summarySpanEverything);

    final written = folder.listSync().whereType<File>().toList();
    expect(written, hasLength(1));
    expect(
      written.single.uri.pathSegments.last,
      'selene-summary-2026-05-03-to-2026-06-30.pdf',
    );
    final bytes = await tester.runAsync(written.single.readAsBytes);
    expect(String.fromCharCodes(bytes!.take(8)), '%PDF-1.4');
    expect(find.text(l10n.settingsSummaryDone), findsOneWidget);
  });

  testWidgets('writes the three spreadsheet files, with no intercourse in '
      'them', (tester) async {
    await open(tester);
    final l10n = l10nOf(tester);
    await make(tester, l10n.settingsSpreadsheet, l10n.summarySpanSixMonths);

    final names =
        folder
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    expect(names, <String>[
      'selene-conditions-and-medicines-2025-12-30-to-2026-06-30.csv',
      'selene-cycles-2025-12-30-to-2026-06-30.csv',
      'selene-days-2025-12-30-to-2026-06-30.csv',
    ]);
    final days = await tester.runAsync(
      () => File(
        '${folder.path}/selene-days-2025-12-30-to-2026-06-30.csv',
      ).readAsString(),
    );
    expect(days, contains('2026-05-03,1,heavy'));
    expect(days!.toLowerCase(), isNot(contains('protected')));
    expect(find.text(l10n.settingsSpreadsheetDone(3)), findsOneWidget);
  });

  testWidgets('writes nothing for a span with nothing in it, and says so', (
    tester,
  ) async {
    await open(tester, logged: false);
    final l10n = l10nOf(tester);
    await make(tester, l10n.settingsSummary, l10n.summarySpanThreeMonths);
    expect(folder.listSync(), isEmpty);
    expect(find.text(l10n.settingsSummaryNothing), findsOneWidget);
  });
}
