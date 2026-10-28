// The medicines under Conditions and medication, and their conflict flags
// (ADR-0014, ADR-0015, ADR-0021).
//
// A flag informs and nothing more, at the owner's direction: it says what
// connects two medicines' labels, and offers the pair to a browser. What is
// pinned here is that it appears for a pair the labels connect, that a pair
// they do not connect is never presented as safe, that the browser is
// reached only through the usual confirmation, and that a recorded kind of
// contraception is compared with the medicines as what its products share.
//
// The medicines are a handful written out here rather than the bundle the app
// ships, so that a refresh of openFDA's export cannot change what these tests
// see.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';

import '../data/reference/medicine_fixture.dart';
import 'harness.dart';

/// In key order, as the generator writes them: one label that names another,
/// one that connects with nothing but a combined pill, and the pill.
final List<FixtureDrug> _drugs = <FixtureDrug>[
  fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN'),
  fixtureDrug(
    'drospirenone+ethinyl-estradiol.oral.rx',
    name: 'DROSPIRENONE AND ETHINYL ESTRADIOL',
    substances: <String>['DROSPIRENONE', 'ETHINYL ESTRADIOL'],
    type: 'rx',
  ),
  fixtureDrug('ibuprofen.oral.otc', name: 'IBUPROFEN', sections: _ibuprofen),
  fixtureDrug(
    'tranexamic-acid.oral.rx',
    name: 'TRANEXAMIC ACID',
    type: 'rx',
    sections: <List<String>>[
      <String>['contraindications', _tranexamic],
    ],
  ),
];

const String _tranexamic =
    'Concomitant use of combined hormonal contraceptives. Active '
    'thromboembolic disease.';

final List<List<String>> _ibuprofen = <List<String>>[
  <String>[
    'ask_doctor_or_pharmacist',
    'Ask a doctor or pharmacist before use if you are taking aspirin.',
  ],
];

const GroupSource _guidance = GroupSource(
  title: 'Labeling for Combined Hormonal Contraceptives',
  publisher: 'U.S. Food and Drug Administration',
  url: 'https://www.fda.gov/',
  retrieved: '2026-10-28',
);

/// The combined pill as these drugs make it: the one pill above, in the one
/// group tranexamic acid's label names.
const MedicineGroup _combined = MedicineGroup(
  name: 'combined hormonal contraceptives',
  phrases: <String>['combined hormonal contraceptive'],
  members: <String>{'drospirenone+ethinyl-estradiol.oral.rx'},
  sources: <GroupSource>[_guidance],
);

const MedicineGroups _groups = MedicineGroups(
  <MedicineGroup>[_combined],
  conditions: <Condition, ConditionKind>{
    Condition.hormonalContraceptionCombined: ConditionKind(
      condition: Condition.hormonalContraceptionCombined,
      kind: <String>{'drospirenone+ethinyl-estradiol.oral.rx'},
      names: <String>[],
      groups: <MedicineGroup>[_combined],
      source: _guidance,
    ),
  },
);

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
          medicineBundleProvider.overrideWith(
            (ref) => fixtureBundle(_drugs, groups: _groups),
          ),
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
      // The pair is still there to be looked up, saying that no label connects
      // it and that the result is worth verifying: never as cleared.
      expect(
        find.text(l10n.checkerPairTitle('ASPIRIN', 'TRANEXAMIC ACID')),
        findsOneWidget,
      );
      expect(find.text(l10n.checkerNothingFoundPair), findsOneWidget);
      expect(find.text(l10n.conditionsConflictsIntro), findsNothing);
      expect(find.text(l10n.conditionsConflictLabels), findsNothing);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
    });

    testWidgets('comes before the pairs that are not flagged, each of which '
        'can be looked up too', (tester) async {
      // Three medicines, three pairs, one flagged. The other two are listed
      // after it, each with the sentence and its own way to the browser.
      await record(const <String>[
        'aspirin.oral.otc',
        'ibuprofen.oral.otc',
        'tranexamic-acid.oral.rx',
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerNothingFoundNote));
      final expected = <String>[
        l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN'),
        l10n.checkerPairTitle('ASPIRIN', 'TRANEXAMIC ACID'),
        l10n.checkerPairTitle('IBUPROFEN', 'TRANEXAMIC ACID'),
      ];
      final titles = <String?>[
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          if (expected.contains(text.data)) text.data,
      ];
      expect(titles, expected);
      expect(find.text(l10n.checkerNothingFoundPair), findsNWidgets(2));
      expect(find.text(l10n.conditionsConflictLookUp), findsNWidgets(3));
      expect(find.text(l10n.conditionsConflictLabels), findsOneWidget);
    });

    testWidgets('that the labels do not connect can be looked up online', (
      tester,
    ) async {
      await record(const <String>[
        'aspirin.oral.otc',
        'tranexamic-acid.oral.rx',
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLookUp));
      await tester.tap(find.text(l10n.conditionsConflictLookUp));
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.lookupLeavingWithTermBody(
            'aspirin and tranexamic acid interaction',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
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

  group('a recorded kind of contraception', () {
    Future<void> recordPill({CivilDate? end}) => db.conditionDao.add(
      condition: Condition.hormonalContraceptionCombined,
      start: testClock.today().addDays(-30),
      end: end,
    );

    String title(WidgetTester tester, String medicine) {
      final l10n = l10nOf(tester);
      return l10n.checkerPairTitle(
        l10n.conditionHormonalContraceptionCombined,
        medicine,
      );
    }

    testWidgets('is compared with a single medicine, and flagged where its '
        'label names the kind', (tester) async {
      await recordPill();
      await record(const <String>['tranexamic-acid.oral.rx']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(title(tester, 'TRANEXAMIC ACID')));
      expect(
        find.text(
          l10n.checkerMentionsGroupShort(
            'TRANEXAMIC ACID',
            'combined hormonal contraceptives',
            l10n.conditionKindCombined,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.text(l10n.conditionsConflictsIntro), findsOneWidget);
    });

    testWidgets('opens what the label says, and where the group comes from', (
      tester,
    ) async {
      await recordPill();
      await record(const <String>['tranexamic-acid.oral.rx']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLabel));
      await tester.tap(find.text(l10n.conditionsConflictLabel));
      await tester.pumpAndSettle();
      expect(find.byType(ConditionPairScreen), findsOneWidget);
      expect(
        find.text(
          'Concomitant use of combined hormonal contraceptives.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.checkerGroupSources(
            'combined hormonal contraceptives',
            '“Labeling for Combined Hormonal Contraceptives”, U.S. Food and '
                'Drug Administration',
          ),
        ),
        findsOneWidget,
      );
      // The record says which kind, not which product, and the screen says
      // what it was compared as.
      expect(
        find.text(l10n.conditionsConflictKind(l10n.conditionKindCombined)),
        findsOneWidget,
      );
    });

    testWidgets('is looked up online by its own name', (tester) async {
      await recordPill();
      await record(const <String>['tranexamic-acid.oral.rx']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLookUp));
      await tester.tap(find.text(l10n.conditionsConflictLookUp));
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.lookupLeavingWithTermBody(
            'combined pill and tranexamic acid interaction',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
    });

    testWidgets('that a label does not name is not called safe', (
      tester,
    ) async {
      await recordPill();
      await record(const <String>['ibuprofen.oral.otc']);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerNothingFoundNote));
      expect(find.text(title(tester, 'IBUPROFEN')), findsOneWidget);
      expect(find.text(l10n.checkerNothingFoundPair), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.text(l10n.conditionsConflictLabel), findsNothing);
    });

    testWidgets('is left out where its own product is recorded', (
      tester,
    ) async {
      // The pill recorded twice, as a condition and by name: the medicine,
      // with its own label, stands for it.
      await recordPill();
      await record(const <String>[
        'drospirenone+ethinyl-estradiol.oral.rx',
        'tranexamic-acid.oral.rx',
      ]);
      await pump(tester);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.conditionsConflictLabels));
      expect(
        find.text(
          l10n.checkerPairTitle(
            'DROSPIRENONE AND ETHINYL ESTRADIOL',
            'TRANEXAMIC ACID',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(title(tester, 'TRANEXAMIC ACID')), findsNothing);
    });

    testWidgets('that has ended takes no part', (tester) async {
      await recordPill(end: testClock.today().addDays(-5));
      await record(const <String>['tranexamic-acid.oral.rx']);
      await pump(tester);
      expect(
        find.text(l10nOf(tester).conditionsConflictsHeading),
        findsNothing,
      );
    });
  });
}
