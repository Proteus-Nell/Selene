// The interaction checker (ADR-0014, ADR-0021, ADR-0023).
//
// What is pinned here is what the screen says, because each part of it is
// something a reader would otherwise assume: that a pair with nothing found is
// safe together, that a quoted mention is this app's opinion rather than the
// label's own words, and that the search for a pair goes out without asking.
//
// The medicines are a handful written out here rather than the bundle the app
// ships, so that a refresh of openFDA's export cannot change what these tests
// see. medicines_test.dart covers the real bundle. The herbs are
// supplement_fixture.dart's two, and supplements_test.dart covers the real
// reference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';

import '../../data/reference/medicine_fixture.dart';
import '../../data/reference/supplement_fixture.dart';
import '../harness.dart';

const String _nsaid = 'Nonsteroidal Anti-inflammatory Drug';

/// Five medicines, in key order as the generator writes them: one label that
/// names another, two in one class, one that connects with nothing, and one
/// the fixture St. John's wort's sheet names.
final List<FixtureDrug> _drugs = <FixtureDrug>[
  fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN'),
  fixtureDrug(
    'ibuprofen.oral.otc',
    name: 'IBUPROFEN',
    classes: <String>[_nsaid],
    sections: <List<String>>[
      <String>['purpose', 'Pain reliever'],
      <String>[
        'ask_doctor_or_pharmacist',
        'Ask a doctor or pharmacist before use if you are taking aspirin.',
      ],
    ],
  ),
  fixtureDrug(
    'naproxen.oral.rx',
    name: 'NAPROXEN',
    type: 'rx',
    classes: <String>[_nsaid],
  ),
  fixtureDrug(
    'tranexamic-acid.oral.rx',
    name: 'TRANEXAMIC ACID',
    type: 'rx',
    sections: <List<String>>[
      <String>['contraindications', 'Active thromboembolic disease.'],
    ],
  ),
  fixtureDrug(
    'warfarin-sodium.oral.rx',
    name: 'WARFARIN SODIUM',
    type: 'rx',
    terms: <String>['warfarin', 'warfarin sodium'],
    sections: <List<String>>[
      <String>[
        'drug_interactions',
        "Botanicals such as St. John's wort may decrease its effect.",
      ],
    ],
  ),
];

void main() {
  late AppDatabase db;
  late MedicineIndex index;

  setUp(() async {
    db = memoryDatabase();
    index = fixtureIndex(_drugs);
  });
  tearDown(() => db.close());

  /// The drug with [key], as the bundle's index has it.
  MedicineEntry entry(String key) => index.byKey(key)!;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    MedicineGroups groups = MedicineGroups.none,
  }) async {
    await tester.pumpWidget(
      harness(
        child,
        database: db,
        overrides: <Override>[
          medicineBundleProvider.overrideWith(
            (ref) => fixtureBundle(_drugs, groups: groups),
          ),
          supplementAssetsProvider.overrideWithValue(
            fixtureSupplementAssets(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> check(
    WidgetTester tester,
    List<String> keys, {
    List<String> herbs = const <String>[],
    MedicineGroups groups = MedicineGroups.none,
  }) => pump(
    tester,
    InteractionCheckerScreen(
      initial: <MedicineEntry>[...keys.map(entry)],
      initialSupplements: <Supplement>[...herbs.map(fixtureHerb)],
    ),
    groups: groups,
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('says what it reads, and that it cannot call a combination '
        'safe', (tester) async {
      await check(tester, const <String>[]);
      expect(find.text(l10nOf(tester).checkerIntro), findsOneWidget);
    });

    testWidgets('asks for two medicines before it compares', (tester) async {
      await check(tester, const <String>['aspirin.oral.otc']);
      expect(find.text(l10nOf(tester).checkerNeedTwo), findsOneWidget);
    });

    testWidgets('sends the reader to a pharmacist, and says the labelling is '
        'from the US', (tester) async {
      await check(tester, const <String>[]);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.lookupMedicinesUsOnly));
      expect(find.text(l10n.checkerAskPharmacist), findsOneWidget);
      expect(find.text(l10n.lookupMedicinesUsOnly), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('takes a medicine found by searching', (tester) async {
      await check(tester, const <String>['aspirin.oral.otc']);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.checkerAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ibu');
      await tester.pumpAndSettle();
      await tester.tap(find.text('IBUPROFEN'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractionCheckerScreen), findsOneWidget);
      expect(find.text('IBUPROFEN'), findsOneWidget);
      expect(find.text(l10n.checkerNeedTwo), findsNothing);
    });

    testWidgets('does not take one twice', (tester) async {
      await check(tester, const <String>['ibuprofen.oral.otc']);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.checkerAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ibuprofen');
      await tester.pumpAndSettle();
      await tester.tap(find.text('IBUPROFEN'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.checkerAlreadyAdded('IBUPROFEN')), findsOneWidget);
      expect(find.text(l10n.checkerNeedTwo), findsOneWidget);
    });

    testWidgets('lets a medicine be taken off it', (tester) async {
      await check(tester, const <String>[
        'aspirin.oral.otc',
        'ibuprofen.oral.otc',
      ]);
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.checkerRemove('ASPIRIN')));
      await tester.pumpAndSettle();
      expect(find.text('ASPIRIN'), findsNothing);
      expect(find.text(l10n.checkerNeedTwo), findsOneWidget);
    });

    testWidgets('starts with the medicine whose page it was opened from', (
      tester,
    ) async {
      await pump(tester, MedicineScreen(entry: entry('naproxen.oral.rx')));
      await tester.tap(find.text(l10nOf(tester).lookupMedicineCheck));
      await tester.pumpAndSettle();
      expect(find.byType(InteractionCheckerScreen), findsOneWidget);
      expect(find.text('NAPROXEN'), findsOneWidget);
    });

    testWidgets('is offered on Look something up', (tester) async {
      await pump(tester, const LookupScreen());
      await tester.tap(find.text(l10nOf(tester).checkerTitle));
      await tester.pumpAndSettle();
      expect(find.byType(InteractionCheckerScreen), findsOneWidget);
    });
  });

  group('a pair', () {
    testWidgets("quotes where one label names the other, in the label's "
        'own words', (tester) async {
      await check(tester, const <String>[
        'aspirin.oral.otc',
        'ibuprofen.oral.otc',
      ]);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN')),
        findsOne,
      );
      expect(
        find.text(
          l10n.checkerMentionsName(
            'IBUPROFEN',
            'aspirin',
            l10n.lookupSectionAskDoctorOrPharmacist,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ask a doctor or pharmacist before use if you are taking aspirin.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('says when both are in one FDA class', (tester) async {
      await check(tester, const <String>[
        'ibuprofen.oral.otc',
        'naproxen.oral.rx',
      ]);
      expect(
        find.text(l10nOf(tester).checkerSharedClass(1, _nsaid)),
        findsOneWidget,
      );
    });

    testWidgets('says when both are in one group, as the group table has it', (
      tester,
    ) async {
      // Aspirin carries no FDA class here, so the class says nothing, and
      // the group does.
      const nsaids = MedicineGroup(
        name: 'NSAIDs',
        phrases: <String>['NSAID'],
        members: <String>{'aspirin.oral.otc', 'ibuprofen.oral.otc'},
      );
      await check(
        tester,
        const <String>['aspirin.oral.otc', 'ibuprofen.oral.otc'],
        groups: const MedicineGroups(<MedicineGroup>[nsaids]),
      );
      expect(
        find.text(l10nOf(tester).checkerSharedGroup('NSAIDs')),
        findsOneWidget,
      );
    });

    testWidgets('that nothing connects is not called safe', (tester) async {
      await check(tester, const <String>[
        'aspirin.oral.otc',
        'tranexamic-acid.oral.rx',
      ]);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.checkerNothingFoundPair), findsOneWidget);
      expect(find.text(l10n.checkerNothingFoundNote), findsOneWidget);
    });

    testWidgets('that the labels connect comes before one they do not', (
      tester,
    ) async {
      await check(tester, const <String>[
        'aspirin.oral.otc',
        'tranexamic-acid.oral.rx',
        'ibuprofen.oral.otc',
      ]);
      final l10n = l10nOf(tester);
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .where(
            (data) =>
                data != null &&
                (data == l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN') ||
                    data ==
                        l10n.checkerPairTitle('ASPIRIN', 'TRANEXAMIC ACID') ||
                    data ==
                        l10n.checkerPairTitle('TRANEXAMIC ACID', 'IBUPROFEN')),
          )
          .toList();
      expect(titles.first, l10n.checkerPairTitle('ASPIRIN', 'IBUPROFEN'));
      expect(titles, hasLength(3));
    });

    testWidgets('can be looked up online, after saying what will be searched', (
      tester,
    ) async {
      await check(tester, const <String>[
        'aspirin.oral.otc',
        'ibuprofen.oral.otc',
      ]);
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerSearchOnline));
      await tester.tap(find.text(l10n.checkerSearchOnline));
      await tester.pumpAndSettle();
      expect(find.text(l10n.lookupLeavingTitle), findsOneWidget);
      expect(
        find.text(
          l10n.lookupLeavingWithTermBody('aspirin and ibuprofen interaction'),
        ),
        findsOneWidget,
      );

      // Declining is a choice, not a failure, and is not reported as one.
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
      expect(find.text(l10n.lookupLeavingTitle), findsNothing);
      expect(find.text(l10n.lookupLeavingFailed), findsNothing);
    });
  });

  group('a herb', () {
    testWidgets('is added from the herbs, and asks for a medicine to compare '
        'it with', (tester) async {
      await check(tester, const <String>[]);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.checkerAddSupplement));
      await tester.pumpAndSettle();
      // Every herb, before anything is typed.
      expect(find.text('St. John’s Wort'), findsOneWidget);
      await tester.tap(find.text('Ginger'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractionCheckerScreen), findsOneWidget);
      expect(find.text('Ginger'), findsOneWidget);
      expect(find.text(l10n.checkerSupplementKind), findsOneWidget);
      expect(find.text(l10n.checkerNeedMedicine), findsOneWidget);
    });

    testWidgets('is not added twice', (tester) async {
      await check(tester, const <String>[], herbs: const <String>['ginger']);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.checkerAddSupplement));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ginger'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.checkerAlreadyAdded('Ginger')), findsOneWidget);
    });

    testWidgets('can be taken off the list', (tester) async {
      await check(
        tester,
        const <String>['aspirin.oral.otc'],
        herbs: const <String>['ginger'],
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.checkerRemove('Ginger')));
      await tester.pumpAndSettle();
      expect(find.text('Ginger'), findsNothing);
      expect(find.text(l10n.checkerNeedTwo), findsOneWidget);
    });

    testWidgets("quotes where its fact sheet names the medicine, in NCCIH's "
        'own words', (tester) async {
      await check(
        tester,
        const <String>['ibuprofen.oral.otc'],
        herbs: const <String>['ginger'],
      );
      final l10n = l10nOf(tester);
      expect(find.byType(SupplementPairCard), findsOneWidget);
      expect(
        find.text(l10n.checkerPairTitle('Ginger', 'IBUPROFEN')),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.checkerSheetMentionsName(
            'Ginger',
            'ibuprofen',
            supplementSafetyHeading,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Taking ginger with ibuprofen may raise the risk of bleeding.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('quotes a list item under the line it hangs from, and the '
        'label naming the herb', (tester) async {
      await check(
        tester,
        const <String>['warfarin-sodium.oral.rx'],
        herbs: const <String>['st-johns-wort'],
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(
          l10n.checkerMentionsName(
            'WARFARIN SODIUM',
            "St. John's wort",
            l10n.lookupSectionInteractions,
          ),
        ),
        findsOneWidget,
      );
      await reveal(tester, find.text(fixtureLeadIn));
      expect(
        find.text(
          l10n.checkerSheetMentionsName(
            'St. John’s Wort',
            'Warfarin',
            supplementSafetyHeading,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(fixtureLeadIn), findsOneWidget);
      expect(find.text('Warfarin', findRichText: true), findsOneWidget);
    });

    testWidgets('that nothing connects is not called safe', (tester) async {
      await check(
        tester,
        const <String>['aspirin.oral.otc'],
        herbs: const <String>['ginger'],
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.checkerNothingFoundSupplementPair), findsOneWidget);
      expect(find.text(l10n.checkerNothingFoundSheetNote), findsOneWidget);
      // That note is the medicines', and there is no pair of medicines.
      expect(find.text(l10n.checkerNothingFoundNote), findsNothing);
    });

    testWidgets('is compared with each medicine and not with another herb', (
      tester,
    ) async {
      await check(
        tester,
        const <String>['ibuprofen.oral.otc'],
        herbs: const <String>['ginger', 'st-johns-wort'],
      );
      final l10n = l10nOf(tester);
      expect(find.byType(SupplementPairCard), findsNWidgets(2));
      expect(
        find.text(l10n.checkerPairTitle('Ginger', 'St. John’s Wort')),
        findsNothing,
      );
      await reveal(tester, find.text(l10n.checkerHerbsNotCompared));
      expect(find.text(l10n.checkerHerbsNotCompared), findsOneWidget);
    });

    testWidgets("carries NCCIH's disclaimer while a herb is listed", (
      tester,
    ) async {
      await check(
        tester,
        const <String>['ibuprofen.oral.otc'],
        herbs: const <String>['ginger'],
      );
      await reveal(tester, find.text(fixtureSupplementsDisclaimer));
      expect(find.text(fixtureSupplementsDisclaimer), findsOneWidget);
    });

    testWidgets('and a medicine can be looked up online together', (
      tester,
    ) async {
      await check(
        tester,
        const <String>['aspirin.oral.otc'],
        herbs: const <String>['ginger'],
      );
      final l10n = l10nOf(tester);
      await reveal(tester, find.text(l10n.checkerSearchOnline));
      await tester.tap(find.text(l10n.checkerSearchOnline));
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.lookupLeavingWithTermBody('ginger and aspirin interaction'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
    });
  });
}
