// A herb's page (ADR-0023): NCCIH's fact sheet, as NCCIH wrote it.
//
// What is pinned here is what the page has to say besides the sheet, because
// each is something a reader would otherwise assume: whose words these are
// and how old, that the photograph on NCCIH's page is missing on purpose, and
// where the original is. And that the sheet's lists keep their nesting, since
// a list of medicines under the line that says why they are listed reads
// differently from one that is not.
//
// The herbs are supplement_fixture.dart's, written for these tests in NCCIH's
// shape. supplements_test.dart covers the real reference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';
import 'package:period_tracker/features/lookup/list_mark.dart';
import 'package:period_tracker/features/lookup/supplement_screen.dart';

import '../../data/reference/medicine_fixture.dart';
import '../../data/reference/supplement_fixture.dart';
import '../harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, String key) async {
    await tester.pumpWidget(
      harness(
        SupplementScreen(supplement: fixtureHerb(key)),
        database: db,
        overrides: <Override>[
          medicineBundleProvider.overrideWith(
            (ref) => fixtureBundle(fixtureDrugs),
          ),
          supplementAssetsProvider.overrideWithValue(
            fixtureSupplementAssets(),
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

  testWidgets('names the herb as NCCIH does, and says whose sheet it is', (
    tester,
  ) async {
    await open(tester, 'st-johns-wort');
    final l10n = l10nOf(tester);
    expect(find.text('St. John’s Wort'), findsOneWidget);
    expect(
      find.text(l10n.supplementsCommonNames('St. John’s wort, hypericum')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.supplementsLatinNames('Hypericum perforatum')),
      findsOneWidget,
    );
    expect(find.text(l10n.supplementsSource('May 2025')), findsOneWidget);
  });

  testWidgets('shows its sections under their headings', (tester) async {
    await open(tester, 'st-johns-wort');
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('What Do We Know About Safety?'), findsOneWidget);
    await reveal(tester, find.text('Keep in Mind'));
    expect(find.text('Take charge of your health.'), findsOneWidget);
  });

  testWidgets('keeps the nesting of its lists, and the marks it draws', (
    tester,
  ) async {
    await open(tester, 'st-johns-wort');
    await reveal(tester, find.text('Warfarin'));
    // Drawn, a circle and two squares, each beside its own item: the bundled
    // font has neither glyph.
    final depths = tester
        .widgetList<ListMark>(find.byType(ListMark))
        .map((mark) => mark.depth);
    expect(depths.where((depth) => depth == 2), hasLength(1));
    expect(depths.where((depth) => depth == 3), hasLength(2));
    expect(find.text('◦'), findsNothing);
    expect(find.text('▪'), findsNothing);
    final top = tester.getTopLeft(find.text(fixtureLeadIn)).dx;
    final item = tester.getTopLeft(find.text('Birth control pills')).dx;
    expect(item, greaterThan(top), reason: 'an item sits inside its list');
  });

  testWidgets('a paragraph has no mark', (tester) async {
    await open(tester, 'st-johns-wort');
    final paragraph = find.text('Take charge of your health.');
    await reveal(tester, paragraph);
    // Flush with its heading, where an item would be indented by its mark.
    expect(
      tester.getTopLeft(paragraph).dx,
      tester.getTopLeft(find.text('Keep in Mind')).dx,
    );
  });

  testWidgets('says the photograph is left out, and where the page is', (
    tester,
  ) async {
    await open(tester, 'st-johns-wort');
    final l10n = l10nOf(tester);
    await reveal(tester, find.text(fixtureSupplementsDisclaimer));
    expect(find.text(l10n.supplementsPhoto), findsOneWidget);
    expect(
      find.text(
        l10n.supplementsAddress(
          'https://www.nccih.nih.gov/health/st-johns-wort',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(fixtureSupplementsDisclaimer), findsOneWidget);
  });

  testWidgets('opens the checker with the herb on its list', (tester) async {
    await open(tester, 'ginger');
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.supplementsCompare));
    await tester.pumpAndSettle();
    expect(find.byType(InteractionCheckerScreen), findsOneWidget);
    expect(find.text('Ginger'), findsOneWidget);
    expect(find.text(l10n.checkerSupplementKind), findsOneWidget);
    expect(find.text(l10n.checkerNeedMedicine), findsOneWidget);
  });

  testWidgets('survives a 200% text scale', (tester) async {
    await tester.pumpWidget(
      harness(
        SupplementScreen(supplement: fixtureHerb('st-johns-wort')),
        database: db,
        textScaler: const TextScaler.linear(2),
        overrides: <Override>[
          supplementAssetsProvider.overrideWithValue(
            fixtureSupplementAssets(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text(fixtureSupplementsDisclaimer));
    expect(tester.takeException(), isNull);
  });
}
