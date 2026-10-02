// The body-composition reference screen, and the way in (AND-35).
//
// weight_sources_test.dart and weight_copy_test.dart both read the ARB, which
// says nothing about whether any of it reaches a screen. This file is the part
// that pumps it: the sections render, the reference is reachable from insights,
// and nothing on it is a field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/weight/weight_hormones_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(const WeightHormonesScreen(), database: db),
    );
    await tester.pumpAndSettle();
  }

  group('the reference', () {
    testWidgets('opens with the framing sentence, before any mechanism', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).weightIntro), findsOneWidget);
    });

    testWidgets('covers every mechanism the sources file cites', (
      tester,
    ) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final title in <String>[
        l10n.weightOestrogenTitle,
        l10n.weightEnergyTitle,
        l10n.weightInsulinTitle,
        l10n.weightPcosTitle,
        l10n.weightThyroidTitle,
        l10n.weightChangeTitle,
      ]) {
        final finder = find.text(title);
        await tester.scrollUntilVisible(finder, 200);
        expect(finder, findsOneWidget, reason: '$title is missing');
      }
    });

    testWidgets('carries the claim that PCOS spans the whole spectrum', (
      tester,
    ) async {
      // Pinned to the rendered screen as well as to the ARB, because a section
      // can lose a paragraph without anything in the ARB changing.
      await pump(tester);
      final finder = find.text(l10nOf(tester).weightPcosSpectrumBody);
      await tester.scrollUntilVisible(finder, 200);
      expect(finder, findsOneWidget);
    });

    testWidgets('has nothing on it to fill in', (tester) async {
      // The whole premise: no weight entry, no weight log, no BMI. A field
      // appearing here would be a schema change wearing a text box.
      await pump(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('survives a 200% text scale without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const WeightHormonesScreen(),
          database: db,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the way in', () {
    testWidgets('is on insights, below the user own figures', (tester) async {
      // Everything above it on that screen is this user's data. A page about
      // body composition sitting among their figures would read as a response
      // to them, which is the one thing it must never be.
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await db.settingsDao.writeBool(
        SettingKey.revealHiddenReference,
        value: true,
      );
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      final link = find.text(l10n.weightEntryTitle);
      await tester.scrollUntilVisible(link, 200);
      expect(link, findsOneWidget);
      expect(find.text(l10n.weightEntrySubtitle), findsOneWidget);
    });

    testWidgets('opens the reference when tapped', (tester) async {
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await db.settingsDao.writeBool(
        SettingKey.revealHiddenReference,
        value: true,
      );
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      final link = find.text(l10nOf(tester).weightEntryTitle);
      await tester.scrollUntilVisible(link, 200);
      // scrollUntilVisible stops the moment the row is partly on screen, and
      // the last card on this list stops half over the bottom edge. Tapping
      // its centre from there misses the viewport entirely.
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.byType(WeightHormonesScreen), findsOneWidget);
    });

    testWidgets('is not offered until Learn has revealed it', (tester) async {
      // Learn keeps this page back until its tab has been held, and Insights
      // does not offer a way round that.
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).weightEntryTitle), findsNothing);
    });

    testWidgets('is not offered while the Learn tab is off', (tester) async {
      // The reference pages are shown only to someone who has switched the
      // Learn tab on, at the owner's direction, and Insights is no exception.
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).weightEntryTitle), findsNothing);
    });
  });
}
