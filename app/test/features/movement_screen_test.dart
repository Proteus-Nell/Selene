// The pain-and-movement reference screen, and the way in (AND-36).
//
// movement_sources_test.dart and movement_copy_test.dart both read the ARB,
// which says nothing about whether any of it reaches a screen. This file is the
// part that pumps it: the sections render, the reference is reachable from
// insights, and nothing on it is a field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/movement/movement_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const MovementScreen(), database: db));
    await tester.pumpAndSettle();
  }

  group('the reference', () {
    testWidgets('opens with the framing sentence, before any claim', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).movementIntro), findsOneWidget);
    });

    testWidgets('covers every section the sources file cites', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final title in <String>[
        l10n.movementPainTitle,
        l10n.movementNotAvoidedTitle,
        l10n.movementHowItFeelsTitle,
        l10n.movementRestTitle,
        l10n.movementStopSignalsTitle,
        l10n.movementPhaseClaimsTitle,
        l10n.movementSeeSomeoneTitle,
      ]) {
        final finder = find.text(title);
        await tester.scrollUntilVisible(finder, 200);
        expect(finder, findsOneWidget, reason: '$title is missing');
      }
    });

    testWidgets('carries the claim that a period is not a reason to stop', (
      tester,
    ) async {
      // Pinned to the rendered screen as well as to the ARB, because a section
      // can lose a paragraph without anything in the ARB changing — and this is
      // the paragraph the whole task turns on.
      await pump(tester);
      final finder = find.text(l10nOf(tester).movementNotAvoidedBody);
      await tester.scrollUntilVisible(finder, 200);
      expect(finder, findsOneWidget);
    });

    testWidgets('carries the signals that are a reason to stop', (
      tester,
    ) async {
      // The other half of the same balance. A page that says movement is fine
      // during a period and never says what is worth stopping for would be
      // half a reference.
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final body in <String>[
        l10n.movementStopSignalsBody,
        l10n.movementAnaemiaBody,
      ]) {
        final finder = find.text(body);
        await tester.scrollUntilVisible(finder, 200);
        expect(finder, findsOneWidget);
      }
    });

    testWidgets('has nothing on it to fill in', (tester) async {
      // The whole premise: no exercise entry, no plan, no schema change. A
      // field appearing here would be a training log wearing a text box.
      await pump(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Radio<Object?>), findsNothing);
      expect(find.byType(DropdownButton<Object?>), findsNothing);
    });

    testWidgets('survives a 200% text scale without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const MovementScreen(),
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
      // pain and exertion sitting among their figures would read as a response
      // to them, which is the one thing it must never be.
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      final link = find.text(l10n.movementEntryTitle);
      await tester.scrollUntilVisible(link, 200);
      expect(link, findsOneWidget);
      expect(find.text(l10n.movementEntrySubtitle), findsOneWidget);
    });

    testWidgets('opens the reference when tapped', (tester) async {
      await seedHistory(db, const <int>[28, 29, 28, 30, 28]);
      await tester.pumpWidget(harness(const InsightsScreen(), database: db));
      await tester.pumpAndSettle();

      final link = find.text(l10nOf(tester).movementEntryTitle);
      await tester.scrollUntilVisible(link, 200);
      // scrollUntilVisible stops the moment the row is partly on screen, and
      // the last card on this list stops half over the bottom edge. Tapping
      // its centre from there misses the viewport entirely.
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.byType(MovementScreen), findsOneWidget);
    });
  });
}
