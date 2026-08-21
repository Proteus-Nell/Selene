// Flow collapsed to bleeding yes/no (AND-24).
//
// The feature is a display preference, and the whole difficulty is keeping it
// one. Two things could turn it into a data change without anything on screen
// saying so:
//
// 1. Writing `spotting` for "yes". Segmentation reads nothing but
//    `isBleedingDay`, and spotting is deliberately not a bleeding day, so a
//    user who turned this on would stop having cycles detected at all. Their
//    prediction would degrade to TooIrregular and the app would never explain
//    why. This is the single mistake the task called out, and there is a test
//    for it that reads the segmenter rather than the widget.
//
// 2. Rewriting an intensity the user already recorded. The subtitle in settings
//    promises that anything recorded is kept and comes back — a promise checked
//    here rather than taken on trust.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/domain/cycles/segmentation.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> simplify({required bool value}) =>
      db.settingsDao.writeBool(SettingKey.flowSimplified, value: value);

  Future<void> pumpLog(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LogScreen(), database: db));
    await tester.pumpAndSettle();
  }

  /// Everything the database holds about days, in a comparable form.
  Future<List<String>> snapshot(AppDatabase database) async {
    final logs = await database.dayLogDao.allLogs();
    return logs
        .map(
          (log) =>
              '${log.date.toIso8601()} ${log.flow.name} '
              '${log.symptoms.entries.map((e) => '${e.key.name}=${e.value.name}').join(',')}',
        )
        .toList();
  }

  group('the control', () {
    testWidgets('is the graded picker by default', (tester) async {
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logFlowSpotting), findsOneWidget);
      expect(find.text(l10n.logBleedingYes), findsNothing);
    });

    testWidgets('collapses to two answers when the preference is set', (
      tester,
    ) async {
      await simplify(value: true);
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logBleedingYes), findsOneWidget);
      expect(find.text(l10n.logBleedingNo), findsOneWidget);
      for (final gone in <String>[
        l10n.logFlowSpotting,
        l10n.logFlowLight,
        l10n.logFlowMedium,
        l10n.logFlowHeavy,
      ]) {
        expect(find.text(gone), findsNothing, reason: '$gone is still offered');
      }
    });

    testWidgets('follows the preference without a restart', (tester) async {
      // The switch and the editor read one stream, so they cannot disagree.
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logFlowHeavy), findsOneWidget);

      await simplify(value: true);
      await tester.pumpAndSettle();
      expect(find.text(l10n.logFlowHeavy), findsNothing);
      expect(find.text(l10n.logBleedingYes), findsOneWidget);
    });
  });

  group('what "yes" records', () {
    testWidgets('is a bleeding intensity, so the day opens a cycle', (
      tester,
    ) async {
      // The mistake this test exists for: writing spotting here would leave
      // isBleedingDay false and the day would never start a period.
      await simplify(value: true);
      await pumpLog(tester);

      await tester.tap(find.text(l10nOf(tester).logBleedingYes));
      await tester.pumpAndSettle();

      final logs = await db.dayLogDao.allLogs();
      expect(logs, hasLength(1));
      expect(
        logs.single.flow,
        isNot(FlowIntensity.spotting),
        reason: 'spotting is not a bleeding day and would not open a cycle',
      );
      expect(logs.single.isBleedingDay, isTrue);
      expect(logs.single.flow, FlowIntensity.medium);
    });

    testWidgets('is seen as a period start by the segmenter itself', (
      tester,
    ) async {
      // Asserted through the code that actually decides, not through
      // isBleedingDay again. A day the user answered "yes" to has to become a
      // period start, or the feature silently costs them their history.
      await simplify(value: true);
      await pumpLog(tester);
      await tester.tap(find.text(l10nOf(tester).logBleedingYes));
      await tester.pumpAndSettle();

      final episodes = Segmentation.bleedingEpisodes(
        await db.dayLogDao.allLogs(),
      );
      expect(episodes.isOk, isTrue);
      expect(episodes.valueOrNull, hasLength(1));
      expect(episodes.valueOrNull!.single.start, testClock.today());
    });

    testWidgets('answering "no" clears the day', (tester) async {
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.heavy),
      );
      await simplify(value: true);
      await pumpLog(tester);

      await tester.tap(find.text(l10nOf(tester).logBleedingNo));
      await tester.pumpAndSettle();

      // The day carried nothing else, so it is removed rather than stored as an
      // empty row — "logged as nothing" must stay distinguishable from "not
      // logged" for the segmentation downstream.
      expect(await db.dayLogDao.allLogs(), isEmpty);
    });
  });

  group('nothing recorded is lost', () {
    testWidgets('a heavy day reads as yes and stays heavy', (tester) async {
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.heavy),
      );
      await simplify(value: true);
      await pumpLog(tester);

      final yes = find.ancestor(
        of: find.text(l10nOf(tester).logBleedingYes),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(yes).selected, isTrue);

      // Confirming the answer it already shows must not downgrade it.
      await tester.tap(find.text(l10nOf(tester).logBleedingYes));
      await tester.pumpAndSettle();
      expect((await db.dayLogDao.allLogs()).single.flow, FlowIntensity.heavy);
    });

    testWidgets('a spotting day reads as no and stays spotting', (
      tester,
    ) async {
      // Spotting is not bleeding, so it answers "no" — and re-confirming "no"
      // must not erase the distinction the user actually recorded.
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.spotting),
      );
      await simplify(value: true);
      await pumpLog(tester);

      final no = find.ancestor(
        of: find.text(l10nOf(tester).logBleedingNo),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(no).selected, isTrue);

      await tester.tap(find.text(l10nOf(tester).logBleedingNo));
      await tester.pumpAndSettle();
      expect(
        (await db.dayLogDao.allLogs()).single.flow,
        FlowIntensity.spotting,
      );
    });

    testWidgets('turning the preference on and off changes no data at all', (
      tester,
    ) async {
      // The assertion the task asks for, over every intensity at once rather
      // than a representative one: a bug that only mangles `light` would pass a
      // single-case version of this.
      var day = testClock.today().addDays(-10);
      for (final flow in FlowIntensity.values) {
        await db.dayLogDao.save(
          DayLog(
            date: day,
            flow: flow,
            symptoms: const <Symptom, SymptomSeverity>{
              Symptom.cramps: SymptomSeverity.severe,
            },
          ),
        );
        day = day.addDays(1);
      }
      final before = await snapshot(db);

      await pumpLog(tester);
      await simplify(value: true);
      await tester.pumpAndSettle();
      await simplify(value: false);
      await tester.pumpAndSettle();

      expect(
        await snapshot(db),
        before,
        reason: 'a display preference rewrote stored days',
      );
    });

    testWidgets('the graded picker shows the original intensity again', (
      tester,
    ) async {
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.light),
      );
      await simplify(value: true);
      await pumpLog(tester);
      await simplify(value: false);
      await tester.pumpAndSettle();

      final light = find.ancestor(
        of: find.text(l10nOf(tester).logFlowLight),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(light).selected, isTrue);
    });
  });

  group('the export', () {
    testWidgets('carries the intensity even while flow is simplified', (
      tester,
    ) async {
      // The export is the only backup, and the only way the data leaves the
      // device. A display preference that quietly flattened it would mean a
      // user who turned this on could never get their graded history back —
      // not from the app, and not from their own file.
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.heavy),
      );
      await db.dayLogDao.save(
        DayLog(
          date: testClock.today().addDays(-1),
          flow: FlowIntensity.spotting,
        ),
      );
      await simplify(value: true);
      await pumpLog(tester);

      final text = ExportV1.encode(
        await ExportV1.build(database: db, clock: testClock),
      );
      expect(text, contains('"heavy"'));
      expect(text, contains('"spotting"'));
    });
  });

  group('the settings toggle', () {
    testWidgets('writes the preference', (tester) async {
      await tester.pumpWidget(harness(const SettingsScreen(), database: db));
      await tester.pumpAndSettle();

      // Settings is a long ListView and the display section is below the fold,
      // so the tile does not exist until it is scrolled to. Finding nothing
      // here would otherwise read as a missing toggle.
      final label = find.text(l10nOf(tester).settingsFlowSimplified);
      await tester.scrollUntilVisible(label, 120);
      await tester.pumpAndSettle();

      final tile = find.ancestor(
        of: label,
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(await db.settingsDao.readFlowSimplified(), isTrue);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    });
  });
}
