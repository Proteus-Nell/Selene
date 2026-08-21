// The conditions screen (AND-26).
//
// The unusual thing about this feature is that the app asks the user for
// information it has decided in advance not to act on, so the screen has to say
// that plainly. A user who enters PCOS and then waits for better predictions
// has been misled by omission.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;
  late ConditionRepository conditions;

  setUp(() {
    db = memoryDatabase();
    conditions = ConditionRepository(database: db, clock: testClock);
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const ConditionsScreen(), database: db));
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('says the conditions do not change the prediction', (
      tester,
    ) async {
      // Stated on the screen itself, above the list, not behind an info icon.
      // ADR-0010 is a decision the user is entitled to know about, because it
      // is the difference between "the app will now do better" and "you will
      // now be able to read your own history".
      await pump(tester);
      final copy = l10nOf(tester).conditionsSubtitle.toLowerCase();
      expect(find.text(l10nOf(tester).conditionsSubtitle), findsOneWidget);
      expect(
        copy,
        contains('not used'),
        reason:
            'the subtitle no longer says these are not used for predictions, '
            'which is the one thing about this screen a user cannot guess',
      );
    });

    testWidgets('says so plainly when nothing is recorded', (tester) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).conditionsEmpty), findsOneWidget);
    });

    testWidgets('lists what is recorded, with its dates', (tester) async {
      await conditions.add(
        condition: Condition.pcos,
        start: testClock.today().addDays(-100),
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(conditionLabel(l10n, Condition.pcos)), findsOneWidget);
      expect(find.text(l10n.conditionsOngoing), findsOneWidget);
    });

    testWidgets('an ended condition stays on the list', (tester) async {
      // Deleting on end would discard the fact the span was recorded for.
      final record = await conditions.add(
        condition: Condition.breastfeeding,
        start: testClock.today().addDays(-200),
      );
      await conditions.end(id: record.id, end: testClock.today().addDays(-30));
      await pump(tester);

      final l10n = l10nOf(tester);
      expect(
        find.text(conditionLabel(l10n, Condition.breastfeeding)),
        findsOneWidget,
      );
      expect(find.text(l10n.conditionsOngoing), findsNothing);
      expect(find.text(l10n.conditionsReopen), findsOneWidget);
    });

    testWidgets('reopening one clears the end date', (tester) async {
      final record = await conditions.add(
        condition: Condition.perimenopause,
        start: testClock.today().addDays(-200),
      );
      await conditions.end(id: record.id, end: testClock.today().addDays(-30));
      await pump(tester);

      await tester.tap(find.text(l10nOf(tester).conditionsReopen));
      await tester.pumpAndSettle();
      expect((await conditions.all()).single.end, isNull);
    });

    testWidgets('deleting one removes it', (tester) async {
      await conditions.add(
        condition: Condition.other,
        start: testClock.today(),
      );
      await pump(tester);

      await tester.tap(find.text(l10nOf(tester).conditionsRemove));
      await tester.pumpAndSettle();
      expect(await conditions.all(), isEmpty);
    });
  });

  group('the overlap count', () {
    testWidgets('names how many cycles were logged alongside it', (
      tester,
    ) async {
      // The sentence a flag could not have produced, and the reason the table
      // stores spans.
      await seedHistory(db, const <int>[28, 28, 28, 28]);
      await conditions.add(
        condition: Condition.hormonalContraceptionCombined,
        start: testClock.today().addDays(-365),
      );
      await pump(tester);

      expect(
        find.textContaining('cycle'),
        findsWidgets,
        reason: 'no cycle count appeared beside the condition',
      );
    });
  });

  group('every condition', () {
    testWidgets('has a label, so none of them renders blank', (tester) async {
      // A switch with a missing arm would not compile, but a label pointing at
      // an ARB key that was never added renders as an empty chip. Checked over
      // the whole enum rather than a sample.
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final condition in Condition.values) {
        final label = conditionLabel(l10n, condition);
        expect(
          label.trim(),
          isNotEmpty,
          reason: '${condition.name} has no user-facing name',
        );
      }
    });

    testWidgets('is offered when adding one', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.conditionsAdd));
      await tester.pumpAndSettle();
      expect(find.text(l10n.conditionsAddTitle), findsOneWidget);
      expect(
        find.text(conditionLabel(l10n, Condition.pregnancy)),
        findsOneWidget,
      );
    });
  });
}
