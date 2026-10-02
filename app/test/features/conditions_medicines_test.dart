// The medicines under Conditions and medication, and their conflict flags
// (ADR-0014, ADR-0015).
//
// A flag informs and nothing more, at the owner's direction: it says what
// connects two medicines' labels, and offers the pair to a browser. What is
// pinned here is that it appears for a pair the labels connect, that a pair
// they do not connect is never presented as safe, and that the browser is
// reached only through the usual confirmation.
//
// The medicines are a handful written out here rather than the bundle the app
// ships, so that a refresh of openFDA's export cannot change what these tests
// see.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';

import '../data/reference/medicine_fixture.dart';
import 'harness.dart';

/// In key order, as the generator writes them: one label that names another,
/// and one that connects with nothing.
final List<FixtureDrug> _drugs = <FixtureDrug>[
  fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN'),
  fixtureDrug(
    'ibuprofen.oral.otc',
    name: 'IBUPROFEN',
    sections: <List<String>>[
      <String>[
        'ask_doctor_or_pharmacist',
        'Ask a doctor or pharmacist before use if you are taking aspirin.',
      ],
    ],
  ),
  fixtureDrug(
    'tranexamic-acid.oral.rx',
    name: 'TRANEXAMIC ACID',
    type: 'rx',
    sections: <List<String>>[
      <String>['contraindications', 'Active thromboembolic disease.'],
    ],
  ),
];

void main() {
  late AppDatabase db;
  late MedicineListRepository medicines;
  late MedicineIndex index;

  setUp(() {
    db = memoryDatabase();
    medicines = MedicineListRepository(db.settingsDao);
    index = fixtureIndex(_drugs);
  });
  tearDown(() => db.close());

  Future<void> record(List<String> keys) async {
    for (final key in keys) {
      await medicines.add(index.byKey(key)!);
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        const ConditionsScreen(),
        database: db,
        overrides: <Override>[
          medicineBundleProvider.overrideWith((ref) => fixtureBundle(_drugs)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('the medicines', () {
    testWidgets('say plainly when none are recorded', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsMedicinesEmpty));
      expect(find.text(l10n.conditionsMedicinesIntro), findsOneWidget);
    });

    testWidgets('take one picked from the list, and keep it', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerAdd));
      await tester.tap(find.text(l10n.checkerAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'tranexamic');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRANEXAMIC ACID'));
      await tester.pumpAndSettle();

      expect((await medicines.read()).single.key, 'tranexamic-acid.oral.rx');
      await reveal(
        tester,
        find.byTooltip(l10n.checkerRemove('TRANEXAMIC ACID')),
      );
      expect(find.byType(ConditionsScreen), findsOneWidget);
    });

    testWidgets('let one be taken off', (tester) async {
      await record(const <String>['aspirin.oral.otc']);
      await pump(tester);
      final l10n = l10nOf(tester);
      final remove = find.byTooltip(l10n.checkerRemove('ASPIRIN'));
      await reveal(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(await medicines.read(), isEmpty);
      expect(find.text(l10n.conditionsMedicinesEmpty), findsOneWidget);
    });

    testWidgets('show one the bundle no longer lists, and say so', (
      tester,
    ) async {
      // A refresh of the US data can drop a medicine someone recorded. It is
      // theirs, so it stays, marked rather than silently compared as nothing.
      await db.settingsDao.writeRaw(
        'recorded_medicines',
        MedicineListRepository.encode(const <RecordedMedicine>[
          RecordedMedicine(key: 'gone.oral.rx', name: 'GONE'),
        ]),
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsMedicineGone));
      expect(find.text('GONE'), findsOneWidget);
    });
  });

  group('a flag', () {
    testWidgets('appears for a pair the labels connect, and says how', (
      tester,
    ) async {
      await record(const <String>['aspirin.oral.otc', 'ibuprofen.oral.otc']);
      await pump(tester);
      final l10n = l10nOf(tester);
      final reason = find.text(
        l10n.checkerMentionsNameShort('IBUPROFEN', 'aspirin'),
      );
      await reveal(tester, reason);
      expect(find.text(l10n.conditionsConflictsHeading), findsOneWidget);
      expect(find.text(l10n.conditionsConflictsIntro), findsOneWidget);
      expect(
        find.text(l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN')),
        findsOneWidget,
      );
    });

    testWidgets('does not appear for a pair they do not, which is not called '
        'safe', (tester) async {
      await record(const <String>[
        'aspirin.oral.otc',
        'tranexamic-acid.oral.rx',
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerNothingFoundNote));
      expect(find.text(l10n.conditionsConflictsNone), findsOneWidget);
      expect(
        find.text(l10n.checkerPairTitle('ASPIRIN', 'TRANEXAMIC ACID')),
        findsNothing,
      );
    });

    testWidgets('beside others that are not flagged says those are not '
        'cleared', (tester) async {
      // Three medicines, three pairs, one flagged. Without a word about the
      // other two, they would read as checked and fine.
      await record(const <String>[
        'aspirin.oral.otc',
        'ibuprofen.oral.otc',
        'tranexamic-acid.oral.rx',
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerNothingFoundNote));
      expect(
        find.text(l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN')),
        findsOneWidget,
      );
      expect(find.text(l10n.conditionsConflictsOthers(2)), findsOneWidget);
    });

    testWidgets('is not shown for one medicine alone', (tester) async {
      await record(const <String>['ibuprofen.oral.otc']);
      await pump(tester);
      expect(
        find.text(l10nOf(tester).conditionsConflictsHeading),
        findsNothing,
      );
    });

    testWidgets('offers the pair to a browser, after saying what will be '
        'searched', (tester) async {
      await record(const <String>['aspirin.oral.otc', 'ibuprofen.oral.otc']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLookUp));
      await tester.tap(find.text(l10n.conditionsConflictLookUp));
      await tester.pumpAndSettle();
      expect(find.text(l10n.lookupLeavingTitle), findsOneWidget);
      expect(
        find.text(
          l10n.lookupLeavingWithTermBody('aspirin and ibuprofen interaction'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
      expect(find.text(l10n.lookupLeavingFailed), findsNothing);
    });

    testWidgets('opens the checker on the pair, where the label is quoted', (
      tester,
    ) async {
      await record(const <String>['aspirin.oral.otc', 'ibuprofen.oral.otc']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLabels));
      await tester.tap(find.text(l10n.conditionsConflictLabels));
      await tester.pumpAndSettle();
      expect(find.byType(InteractionCheckerScreen), findsOneWidget);
      expect(
        find.text(
          'Ask a doctor or pharmacist before use if you are taking aspirin.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });
}
