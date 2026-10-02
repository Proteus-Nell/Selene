// The lookup screen (AND-32): every drug in openFDA's label export, searched on
// the phone (ADR-0012, ADR-0013).
//
// Most of what is tested here is what the screen has to say, because each is
// something a reader would otherwise assume wrongly: that what they type goes
// somewhere, that US labelling describes the box in their hand, and that a
// label which cannot be opened is a label with nothing in it.
//
// The medicines here are the handful in medicine_fixture.dart rather than the
// bundle the app ships, so that a refresh of openFDA's export cannot change
// what these tests see. medicines_test.dart covers the real bundle.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';
import 'package:period_tracker/features/lookup/medicine_browse.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';

import '../../data/reference/medicine_fixture.dart';
import '../harness.dart';

/// An asset bundle whose files never arrive.
class _NeverAssets extends AssetBundle {
  @override
  Future<ByteData> load(String key) => Completer<ByteData>().future;
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Widget screen({
    MedicineBundle? bundle,
    TextScaler textScaler = TextScaler.noScaling,
  }) => harness(
    const LookupScreen(),
    database: db,
    textScaler: textScaler,
    overrides: <Override>[
      medicineBundleProvider.overrideWith(
        (ref) => bundle ?? fixtureBundle(fixtureDrugs),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, {MedicineBundle? bundle}) async {
    await tester.pumpWidget(screen(bundle: bundle));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pumpAndSettle();
  }

  /// The tile for the medicine whose kind line reads [kind].
  Finder tile(String kind) =>
      find.ancestor(of: find.text(kind), matching: find.byType(ListTile));

  /// Scrolls the page — not the search field — until [finder] is on screen.
  ///
  /// The screen has two scrollables: the outer ListView and the TextField's
  /// own. `scrollUntilVisible` picks the wrong one by default and fails with a
  /// bare "Bad state: No element", which reads as a missing widget rather than
  /// as a mis-aimed scroll.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('says nothing typed here leaves the device', (tester) async {
      // A user typing a drug name into a search box has every reason to assume
      // it goes somewhere. Here it does not, and only the screen can say so.
      await pump(tester);
      final subtitle = l10nOf(tester).lookupSubtitle.toLowerCase();
      expect(find.text(l10nOf(tester).lookupSubtitle), findsOneWidget);
      expect(subtitle, contains('nothing you type here is sent anywhere'));
    });
  });

  group('searching', () {
    testWidgets('narrows to what matches', (tester) async {
      await pump(tester);
      await search(tester, 'tranexamic');
      expect(find.text('TRANEXAMIC ACID'), findsOneWidget);
      expect(find.text('IBUPROFEN'), findsNothing);
    });

    testWidgets('is case insensitive', (tester) async {
      await pump(tester);
      await search(tester, 'LeVoNoRgEsTrEl');
      expect(find.text('LEVONORGESTREL'), findsOneWidget);
    });

    testWidgets('offers the browser when nothing matches', (tester) async {
      // The point of the hand-off: having somewhere to go when it is not here.
      await pump(tester);
      await search(tester, 'something nobody bundled');
      final offer = find.text(l10nOf(tester).lookupSearchOnlineAction);
      await reveal(tester, offer);
      expect(offer, findsOneWidget);
    });
  });

  group('the medicines section', () {
    testWidgets('always says it is US labelling, or says why it is absent', (
      tester,
    ) async {
      // Always, not only when a US user is detected — the app has no way to
      // detect anything, and a reader applying US warnings to a box bought
      // elsewhere is being quietly misinformed.
      await pump(tester);
      final l10n = l10nOf(tester);
      final expected = medicinesFetched
          ? l10n.lookupMedicinesUsOnly
          : l10n.lookupMedicinesUnavailable;
      final finder = find.text(expected);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });

    testWidgets('explains itself when the bundle was never built', (
      tester,
    ) async {
      // The state a repository is in until someone runs --fetch. An empty
      // list would read as a broken screen.
      if (medicinesFetched) {
        markTestSkipped('the bundle has been built');
        return;
      }
      await pump(tester);

      // The rest of the screen still works, rather than the whole page
      // failing because the one section with data has none.
      expect(find.text(l10nOf(tester).lookupSubtitle), findsOneWidget);

      final finder = find.text(l10nOf(tester).lookupMedicinesUnavailable);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });

    testWidgets("carries openFDA's disclaimer", (tester) async {
      await pump(tester);
      final finder = find.text(medicinesDisclaimer);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });

    testWidgets('asks for a name rather than listing every medicine', (
      tester,
    ) async {
      // Several thousand medicines, unasked, would be a list nobody reads.
      await pump(tester);
      final prompt = find.text(
        l10nOf(tester).lookupMedicinesPrompt(fixtureDrugs.length),
      );
      await reveal(tester, prompt);
      expect(prompt, findsOneWidget);
      expect(find.text('IBUPROFEN'), findsNothing);
    });

    testWidgets('finds a medicine by a brand, and shows the brand', (
      tester,
    ) async {
      await pump(tester);
      await search(tester, 'plan b');
      expect(find.text('LEVONORGESTREL'), findsOneWidget);
      expect(find.textContaining('Plan B One-Step'), findsOneWidget);
    });

    testWidgets('tells the forms of one medicine apart', (tester) async {
      // Three medicines called IBUPROFEN, and a reader holding one box.
      await pump(tester);
      await search(tester, 'ibuprofen');
      final l10n = l10nOf(tester);
      expect(find.text('IBUPROFEN'), findsNWidgets(3));
      final shop = tile('Oral · ${l10n.lookupMedicineOverTheCounter}');
      final prescription = tile('Oral · ${l10n.lookupMedicinePrescription}');
      expect(shop, findsOneWidget);
      expect(prescription, findsOneWidget);
      expect(
        tile('Intravenous · ${l10n.lookupMedicinePrescription}'),
        findsOneWidget,
      );
      // The one on a shop shelf first: it has the most labels.
      expect(
        tester.getTopLeft(shop).dy,
        lessThan(tester.getTopLeft(prescription).dy),
      );
    });

    testWidgets('lists a page at a time', (tester) async {
      await pump(
        tester,
        bundle: fixtureBundle(<FixtureDrug>[
          for (var i = 10; i < 40; i++)
            fixtureDrug('testamine-$i.oral.otc', name: 'TESTAMINE $i'),
        ]),
      );
      await search(tester, 'testamine');
      final l10n = l10nOf(tester);
      final more = find.text(l10n.lookupMedicinesShowMore);
      await reveal(tester, more);
      expect(find.text(l10n.lookupMedicinesShowing(25, 30)), findsOneWidget);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text(l10n.lookupMedicinesShowMore), findsNothing);
      await reveal(tester, find.text('TESTAMINE 39'));
      expect(find.text('TESTAMINE 39'), findsOneWidget);
    });

    testWidgets('says so when the reference cannot be opened', (
      tester,
    ) async {
      await pump(
        tester,
        bundle: MedicineBundle(MemoryAssets({}), run: inPlace),
      );
      final failed = find.text(l10nOf(tester).lookupMedicinesFailed);
      await reveal(tester, failed);
      expect(failed, findsOneWidget);
    });

    testWidgets('shows that the reference is still opening', (tester) async {
      // Not settled: the bar animates until the index arrives, and here it
      // never does.
      await tester.pumpWidget(
        screen(bundle: MedicineBundle(_NeverAssets(), run: inPlace)),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(LinearProgressIndicator),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)).label,
        l10nOf(tester).lookupMedicinesLoading,
      );
    });
  });

  group("a medicine's page", () {
    Future<void> open(WidgetTester tester, {MedicineBundle? bundle}) async {
      await pump(tester, bundle: bundle);
      await search(tester, 'ibuprofen');
      final l10n = l10nOf(tester);
      await tester.tap(tile('Oral · ${l10n.lookupMedicinePrescription}'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineScreen), findsOneWidget);
    }

    testWidgets('shows the label as published, under its headings', (
      tester,
    ) async {
      await open(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.lookupSectionBoxedWarning), findsOneWidget);
      expect(find.text(l10n.lookupSectionUses), findsOneWidget);
      expect(
        find.text('Relief of the signs of arthritis.'),
        findsOneWidget,
      );
      final interactions = find.text(l10n.lookupSectionInteractions);
      await reveal(tester, interactions);
      // A paragraph each, as the label breaks them.
      expect(
        find.text('Anticoagulants: increased risk of bleeding.'),
        findsOneWidget,
      );
      expect(find.text('Aspirin: not generally recommended.'), findsOneWidget);
    });

    testWidgets('sets the boxed warning apart, and keeps it legible', (
      tester,
    ) async {
      // The FDA's most serious warning. Printed like the rest, it reads as
      // one more paragraph; printed in the body colour on the error
      // container, it is dark on dark and barely reads at all.
      await open(tester);
      final colours = Theme.of(
        tester.element(find.byType(MedicineScreen)),
      ).colorScheme;
      final card = tester.widget<Card>(
        find.ancestor(
          of: find.text(l10nOf(tester).lookupSectionBoxedWarning),
          matching: find.byType(Card),
        ),
      );
      expect(card.color, colours.errorContainer);
      for (final text in <String>[
        l10nOf(tester).lookupSectionBoxedWarning,
        'WARNING: RISK OF SERIOUS CARDIOVASCULAR AND GASTROINTESTINAL EVENTS',
      ]) {
        expect(
          tester.widget<Text>(find.text(text)).style?.color,
          colours.onErrorContainer,
          reason: '"$text" is not in the colour made for the container',
        );
      }
    });

    testWidgets('says which label it is, and that yours may differ', (
      tester,
    ) async {
      await open(tester);
      final l10n = l10nOf(tester);
      final date = CivilDate(
        2025,
        9,
        29,
      ).full(tester.element(find.byType(MedicineScreen)));
      expect(find.text(l10n.lookupMedicinesUsOnly), findsOneWidget);
      expect(
        find.text(l10n.lookupMedicineLabel('Maker of IBUPROFEN', date)),
        findsOneWidget,
      );
      expect(find.text(l10n.lookupMedicineOneLabel), findsOneWidget);
    });

    testWidgets('says so when the label cannot be opened', (tester) async {
      // The index and the text from two different builds. The page says it
      // cannot open the label rather than showing another drug's warnings.
      final files = fixtureFiles(fixtureDrugs, records: shifted(fixtureDrugs));
      await open(
        tester,
        bundle: MedicineBundle(MemoryAssets(files), run: inPlace),
      );
      expect(find.text(l10nOf(tester).lookupMedicineFailed), findsOneWidget);
      expect(
        find.text(l10nOf(tester).lookupSectionContraindications),
        findsNothing,
      );
    });
  });

  group('the A to Z', () {
    /// Scrolls to the letter's button and taps it.
    Future<void> openLetter(WidgetTester tester, String letter) async {
      final button = find.text(letter);
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(MedicineLetterScreen), findsOneWidget);
    }

    testWidgets('is offered while nothing is typed', (tester) async {
      await pump(tester);
      final heading = find.text(l10nOf(tester).lookupBrowseHeading);
      await reveal(tester, heading);
      expect(heading, findsOneWidget);
      expect(find.byType(MedicineLetters), findsOneWidget);
    });

    testWidgets('gives way to the results once something is', (tester) async {
      await pump(tester);
      await search(tester, 'ibuprofen');
      // To the foot of the page, past where the grid would be.
      await reveal(tester, find.text(l10nOf(tester).lookupSearchOnlineAction));
      expect(find.byType(MedicineLetters), findsNothing);
      expect(find.text(l10nOf(tester).lookupBrowseHeading), findsNothing);
    });

    testWidgets('greys out a letter no name starts with', (tester) async {
      // Every letter stays where it is. One with nothing under it is shown
      // and cannot be tapped, rather than left out.
      await pump(tester);
      await reveal(tester, find.text('Q'));
      final q = tester.widget<TextButton>(
        find.ancestor(of: find.text('Q'), matching: find.byType(TextButton)),
      );
      expect(q.onPressed, isNull);
      final i = tester.widget<TextButton>(
        find.ancestor(of: find.text('I'), matching: find.byType(TextButton)),
      );
      expect(i.onPressed, isNotNull);
    });

    testWidgets('says what each letter does to a screen reader', (
      tester,
    ) async {
      await pump(tester);
      await reveal(tester, find.text('I'));
      final l10n = l10nOf(tester);
      expect(find.bySemanticsLabel(l10n.lookupBrowseLetter('I')), findsOne);
      expect(find.bySemanticsLabel(l10n.lookupBrowseOther), findsOne);
    });

    testWidgets('lists the names under a letter', (tester) async {
      await pump(tester);
      await openLetter(tester, 'T');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.lookupBrowseTitle('T')), findsOneWidget);
      expect(find.text('TRANEXAMIC ACID'), findsOneWidget);
      expect(
        find.text('Oral · ${l10n.lookupMedicinePrescription}'),
        findsOneWidget,
      );
    });

    testWidgets('opens a name one medicine goes by onto its label', (
      tester,
    ) async {
      await pump(tester);
      await openLetter(tester, 'L');
      await tester.tap(find.text('LEVONORGESTREL'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineScreen), findsOneWidget);
      expect(find.text('Emergency contraceptive'), findsOneWidget);
    });

    testWidgets('tells apart the medicines that share a name', (tester) async {
      // Ibuprofen from a shop shelf, on prescription, and by injection: one
      // name in the A to Z, and the reader picks which one they mean rather
      // than being shown whichever came first.
      await pump(tester);
      await openLetter(tester, 'I');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.lookupBrowseShared(3)), findsOneWidget);

      await tester.tap(find.text('IBUPROFEN'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineNameScreen), findsOneWidget);
      expect(find.text(l10n.lookupBrowseSharedIntro), findsOneWidget);
      expect(find.byType(MedicineTile), findsNWidgets(3));

      final injection = find.text(
        'Intravenous · ${l10n.lookupMedicinePrescription}',
      );
      await tester.tap(injection);
      await tester.pumpAndSettle();
      expect(find.byType(MedicineScreen), findsOneWidget);
      expect(find.text('Management of pain in adults.'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('survives a 200% text scale', (tester) async {
      await tester.pumpWidget(
        screen(textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      await search(tester, 'ibuprofen');
      expect(tester.takeException(), isNull);
    });

    testWidgets("and so does a letter's page", (tester) async {
      await tester.pumpWidget(
        screen(textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      final letter = find.text('I');
      await reveal(tester, letter);
      await tester.tap(letter);
      await tester.pumpAndSettle();
      expect(find.byType(MedicineLetterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("and so does a medicine's page", (tester) async {
      await tester.pumpWidget(
        screen(textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      await search(tester, 'ibuprofen');
      final kind = find.text(
        'Oral · ${l10nOf(tester).lookupMedicineOverTheCounter}',
      );
      await reveal(tester, kind);
      await tester.tap(kind);
      await tester.pumpAndSettle();
      expect(find.byType(MedicineScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
