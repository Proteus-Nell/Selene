// The nutrition reference screen (AND-27).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/cycles/nutrition_hint.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/nutrition/nutrition_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const NutritionScreen(), database: db));
    await tester.pumpAndSettle();
  }

  /// Logs [count] days where heavy flow and moderate fatigue coincide.
  Future<void> logCoincidingDays(int count) async {
    for (var i = 0; i < count; i++) {
      await db.dayLogDao.save(
        DayLog(
          date: testClock.today().addDays(-i * 5),
          flow: FlowIntensity.heavy,
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.energy: SymptomSeverity.moderate,
          },
        ),
      );
    }
  }

  group('the reference', () {
    testWidgets('opens with the framing sentence, before any nutrient', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).nutritionIntro), findsOneWidget);
    });

    testWidgets('covers iron, vitamin C, magnesium and zinc', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final title in <String>[
        l10n.nutritionIronTitle,
        l10n.nutritionVitaminCTitle,
        l10n.nutritionMagnesiumTitle,
        l10n.nutritionZincTitle,
      ]) {
        final finder = find.text(title);
        await tester.scrollUntilVisible(finder, 200);
        expect(finder, findsOneWidget, reason: '$title is missing');
      }
    });

    testWidgets('says vitamin C is here because of iron absorption', (
      tester,
    ) async {
      // Otherwise it reads as a second unrelated thing to think about, which is
      // how a focused reference turns into a supplement list.
      await pump(tester);
      final body = l10nOf(tester).nutritionVitaminCBody.toLowerCase();
      expect(body, contains('absorb'));
      expect(body, contains('iron'));
    });

    testWidgets('carries the caution about supplementing without a test', (
      tester,
    ) async {
      await pump(tester);
      final finder = find.text(l10nOf(tester).nutritionIronCautionBody);
      await tester.scrollUntilVisible(finder, 200);
      expect(finder, findsOneWidget);
    });
  });

  group('the hint', () {
    testWidgets('is absent with nothing logged', (tester) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).nutritionHintBody), findsNothing);
    });

    testWidgets('is absent for a single heavy, tired day', (tester) async {
      await logCoincidingDays(1);
      await pump(tester);
      expect(find.text(l10nOf(tester).nutritionHintBody), findsNothing);
    });

    testWidgets('appears once the pattern is a pattern', (tester) async {
      await logCoincidingDays(NutritionHints.minCoincidences);
      await pump(tester);
      expect(find.text(l10nOf(tester).nutritionHintBody), findsOneWidget);
    });

    testWidgets('sits above the reference text rather than after it', (
      tester,
    ) async {
      // A reader who came here because of the hint should not have to scroll
      // past three nutrients to find it.
      await logCoincidingDays(NutritionHints.minCoincidences);
      await pump(tester);

      final hint = tester.getTopLeft(
        find.text(l10nOf(tester).nutritionHintBody),
      );
      final iron = tester.getTopLeft(
        find.text(l10nOf(tester).nutritionIronTitle),
      );
      expect(hint.dy, lessThan(iron.dy));
    });

    testWidgets('appears at most once', (tester) async {
      await logCoincidingDays(NutritionHints.minCoincidences + 4);
      await pump(tester);
      expect(find.text(l10nOf(tester).nutritionHintBody), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('survives a 200% text scale without overflowing', (
      tester,
    ) async {
      await logCoincidingDays(NutritionHints.minCoincidences);
      await tester.pumpWidget(
        harness(
          const NutritionScreen(),
          database: db,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
