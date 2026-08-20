import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';
import 'package:period_tracker/notifications/scheduler.dart';

/// A file picker that answers with a directory and a file the test chose.
///
/// The picker itself is platform code and cannot run in a test, but everything
/// behind it is ours. Faking only the choice keeps the real export and import
/// paths, the confirmation dialog and the database writes inside the test,
/// which is where the risk actually lives: this is the only backup mechanism
/// the app has (risk R8).
class FakeFileSelector extends FileSelectorPlatform {
  /// Answers directory prompts with [directory] and open prompts with [file].
  FakeFileSelector({required this.directory, this.file});

  /// Where an export is told to go.
  final Directory directory;

  /// What an import is told to read. Set once an export has produced one.
  File? file;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => directory.path;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final chosen = file;
    return chosen == null ? null : XFile(chosen.path);
  }
}

/// Pumps for a bounded time rather than until quiet.
///
/// The export and import paths show a progress indicator, which animates
/// continuously, so `pumpAndSettle` never returns while one is on screen. This
/// advances the clock enough for the work to finish without waiting for a
/// quiescence that will not come.
Future<void> _pumpFor(WidgetTester tester, [int seconds = 2]) async {
  await tester.pump();
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Alternates the two clocks this test has to satisfy.
///
/// `testWidgets` runs its body in a fake-async zone, and the two halves of this
/// flow advance on different engines. Files and SQLite complete on the real
/// event loop, which only turns inside [WidgetTester.runAsync]; animations and
/// rebuilds only advance when frames are pumped, which only happens outside it.
/// Doing one and not the other leaves the other's continuations queued
/// indefinitely — and because drift serialises access behind a lock, a
/// half-finished transaction shows up much later as a query that never returns,
/// which looks nothing like its cause.
Future<void> _settle(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _pumpFor(tester, 1);
  }
}

/// Taps something whose handler does real file I/O.
///
/// The tap itself has to happen inside `runAsync`: started from the fake zone,
/// the handler's `await` on a file would never resume, so the file would appear
/// on disk while the screen sat busy for ever and the next tap silently landed
/// on a disabled control.
Future<void> _tapWithIo(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await _settle(tester);
}

/// Reads the day logs, on the real event loop.
///
/// Every assertion about stored state goes through here rather than awaiting
/// the database directly, for the reason given on [_settle].
Future<List<DayLog>> _storedLogs(WidgetTester tester, AppDatabase db) async {
  final logs = await tester.runAsync(db.dayLogDao.allLogs);
  return logs!;
}

/// The localisations, from anywhere in a pumped tree.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Onboard, log cycles, see a window, export, wipe, import, see it again.
///
/// The one test that runs the whole app in sequence. Every piece below is unit
/// tested somewhere else; what this adds is that they still fit together, which
/// is the failure no amount of unit testing catches.
Future<void> runSmokeFlow(WidgetTester tester) async {
  final directory = Directory.systemTemp.createTempSync('period_e2e');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  final picker = FakeFileSelector(directory: directory);
  FileSelectorPlatform.instance = picker;

  final clock = FixedClock.iso('2026-06-30');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    await buildAppScope(
      database: db,
      clock: clock,
      logger: RingLogger(clock: clock),
      // The scheduling rules are tested against a recording gateway in
      // notifications/; here the point is the flow, and a real plugin has no
      // platform behind it off-device.
      notificationGateway: const NoopNotificationGateway(),
    ),
  );
  await _pumpFor(tester);

  // 1. Onboarding: read the disclaimer, then skip the first date. Skipping is
  //    the harder path, because the app has to be usable with nothing logged.
  expect(find.text(_l10n(tester).onboardingTitle), findsOneWidget);
  await tester.tap(find.text(_l10n(tester).onboardingAcknowledge));
  await _pumpFor(tester);
  await tester.tap(find.text(_l10n(tester).onboardingFirstEntrySkip));
  await _pumpFor(tester);

  // 2. Log four period starts through the calendar, 28 days apart, which is
  //    three completed cycles.
  await tester.tap(find.text(_l10n(tester).navCalendar));
  await _pumpFor(tester);
  for (final daysBack in <int>[84, 56, 28, 0]) {
    await _logStartThroughCalendar(tester, clock.today().addDays(-daysBack));
  }
  expect(await _storedLogs(tester, db), hasLength(4));

  // 3. A window renders, as a range and never as a bare date.
  await tester.tap(find.text(_l10n(tester).navInsights));
  await _pumpFor(tester);
  expect(find.text(_l10n(tester).insightsNextPeriodTitle), findsOneWidget);
  // More than one match is the right answer: the predicted window and the
  // user's observed range are both stated as ranges, which is the rule this
  // screen exists to keep (docs/PLAN.md 6.2).
  expect(find.textContaining(_betweenPrefix(tester)), findsWidgets);

  // 4. Export to the chosen directory.
  await tester.tap(find.text(_l10n(tester).navSettings));
  await _pumpFor(tester);
  await _tapWithIo(tester, find.text(_l10n(tester).settingsExport));

  final written = directory
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  expect(written, hasLength(1), reason: 'export wrote no file');
  picker.file = written.single;

  // 5. Delete everything, with the typed confirmation.
  await tester.tap(find.text(_l10n(tester).settingsDeleteAll));
  await _settle(tester);
  await tester.enterText(
    find.byType(TextField),
    _l10n(tester).settingsDeleteConfirmWord,
  );
  await _pumpFor(tester);
  await tester.tap(
    find.widgetWithText(FilledButton, _l10n(tester).commonDelete),
  );
  await _settle(tester);
  expect(await _storedLogs(tester, db), isEmpty);

  // 6. Restore from the backup, confirming the replacement.
  await _tapWithIo(tester, find.text(_l10n(tester).settingsImport));
  await _tapWithIo(
    tester,
    find.widgetWithText(FilledButton, _l10n(tester).settingsImport),
  );

  // 7. The state came back, and so did the prediction.
  expect(await _storedLogs(tester, db), hasLength(4));
  await tester.tap(find.text(_l10n(tester).navInsights));
  await _settle(tester);
  expect(find.text(_l10n(tester).insightsNextPeriodTitle), findsOneWidget);
  expect(find.textContaining(_betweenPrefix(tester)), findsWidgets);

  // Tear the tree down here rather than leaving it to the framework. Disposing
  // the ProviderScope cancels drift's stream queries, and drift schedules a
  // zero-duration timer when the last subscriber goes. Left to the framework,
  // that lands *after* flutter_test's pending-timer check, which fails the test
  // on the way out and then wedges the runner for minutes. Unmounting inside
  // the body puts the timer where a pump can run it.
  await tester.pumpWidget(const SizedBox.shrink());
  await _pumpFor(tester);
}

/// The first few words of the window line, for a language-agnostic match.
String _betweenPrefix(WidgetTester tester) {
  final rendered = _l10n(tester).insightsWindowRange('X', 'Y');
  return rendered.split('X').first.trim();
}

/// Long-presses [date] in the calendar and records a medium flow.
Future<void> _logStartThroughCalendar(
  WidgetTester tester,
  CivilDate date,
) async {
  // Step toward the month holding the target day, in whichever direction it
  // lies. Walking one way only works until the second date, and then silently
  // never arrives.
  var guard = 0;
  while (!_monthContains(tester, date) && guard < 24) {
    final shown = tester
        .widgetList<DayCell>(find.byType(DayCell))
        .map((cell) => cell.date)
        .toList();
    final goBack = shown.isEmpty || date < shown.first;
    await tester.tap(
      find.byIcon(goBack ? Icons.chevron_left : Icons.chevron_right),
    );
    await _pumpFor(tester);
    guard++;
  }
  final cell = find.byWidgetPredicate(
    (widget) => widget is DayCell && widget.date == date,
  );
  expect(cell, findsOneWidget, reason: 'no cell for ${date.toIso8601()}');

  await tester.longPress(cell);
  await _pumpFor(tester);
  await tester.tap(find.text(_l10n(tester).logFlowMedium));
  await _pumpFor(tester);
  await _answerPermissionPrompt(tester);
  await tester.tap(find.text(_l10n(tester).commonClose));
  await _pumpFor(tester);
}

/// Declines the notification prompt, if this was the moment it appeared.
///
/// The app asks for notification permission the first time a cycle actually
/// exists, which is mid-edit on the first day logged here. Answering it is part
/// of the flow rather than an interruption to work around: until it is
/// answered, its barrier covers the sheet underneath, so every later tap in
/// this helper would land on the barrier instead of the control it names — and
/// a tap on a barrier still dismisses the sheet, so the flow would appear to
/// work while testing nothing.
Future<void> _answerPermissionPrompt(WidgetTester tester) async {
  final prompt = find.text(_l10n(tester).settingsNotificationPermissionTitle);
  if (prompt.evaluate().isEmpty) return;
  // Exactly one, ever. Two stacked prompts is a real defect this flow caught,
  // and `notification_sync_test.dart` holds the line on it.
  expect(prompt, findsOneWidget);
  await tester.tap(find.text(_l10n(tester).commonNotNow));
  await _pumpFor(tester);
}

bool _monthContains(WidgetTester tester, CivilDate date) => tester
    .widgetList<DayCell>(find.byType(DayCell))
    .any((cell) => cell.date == date);
