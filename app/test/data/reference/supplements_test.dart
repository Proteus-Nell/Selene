// The herbal supplements reference (ADR-0023): NCCIH's Herbs at a Glance
// fact sheets, in the public domain, carried in the app's assets.
//
// `tools/scripts/gen_supplements.py` reads the pages, and
// research/tests/test_gen_supplements.py tests that. What is pinned here is
// the Dart side: that the app reads every herb the generator wrote, as the
// generator wrote it; that a search finds a herb by any of its names; and,
// over the real medicines bundle, that the herbs a period tracker is asked
// about are found where their fact sheets and the labels say they are.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/data/reference/supplements_bundled.dart';

import 'supplement_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a fact sheet', () {
    test('reads a list item by the mark the page draws for it', () {
      expect(
        SupplementBlock.parse('• one'),
        const SupplementBlock(text: 'one', depth: 1),
      );
      expect(SupplementBlock.parse('◦ two').depth, 2);
      expect(SupplementBlock.parse('▪ three').depth, 3);
      expect(
        SupplementBlock.parse('A paragraph.'),
        const SupplementBlock(text: 'A paragraph.'),
      );
    });

    test('is read a line a block, without the marks', () {
      final safety = fixtureHerb('st-johns-wort').safety!;
      expect(
        safety.text,
        'If you take any type of medicine, talk with your health care '
        'provider.\n$fixtureLeadIn\nBirth control pills\nWarfarin',
      );
    });

    test('says which line a list item hangs from', () {
      final safety = fixtureHerb('st-johns-wort').safety!;
      final text = safety.text;
      expect(safety.leadIn(text.indexOf('Birth')), fixtureLeadIn);
      expect(safety.leadIn(text.indexOf('Warfarin')), fixtureLeadIn);
      // Its own parent ends with a full stop, not a colon: nothing hangs
      // from it.
      expect(safety.leadIn(text.indexOf('For example')), isNull);
      expect(safety.leadIn(0), isNull);
      expect(safety.leadIn(text.length + 5), isNull);
    });

    test('a paragraph hangs from nothing', () {
      const section = SupplementSection(
        heading: 'Keep in Mind',
        blocks: <SupplementBlock>[
          SupplementBlock(text: 'These include:'),
          SupplementBlock(text: 'A paragraph after it.'),
          SupplementBlock(text: 'An item under it', depth: 1),
        ],
      );
      expect(section.leadIn(section.text.indexOf('A paragraph')), isNull);
      expect(
        section.leadIn(section.text.indexOf('An item')),
        isNull,
        reason: 'the nearest line above it is the paragraph, not the colon',
      );
    });
  });

  group('the reference', () {
    test('refuses one in a format it does not know', () {
      expect(
        () => SupplementReference.decode('{"schema_version": 99}'),
        throwsFormatException,
      );
    });

    test('lists the herbs A to Z by title', () {
      final names = fixtureSupplements().herbs.map((herb) => herb.name);
      expect(names, <String>['Ginger', 'St. John’s Wort']);
    });

    test('finds a herb by its title, whatever the apostrophe', () {
      final reference = fixtureSupplements();
      for (final query in <String>["st john's", 'St. John’s', 'st johns']) {
        final found = reference.search(query);
        expect(found.map((match) => match.supplement.key), <String>[
          'st-johns-wort',
        ], reason: query);
        expect(found.single.alias, isNull);
      }
    });

    test('finds a herb by another name, and says which', () {
      final found = fixtureSupplements().search('hyperic');
      expect(found.single.supplement.key, 'st-johns-wort');
      expect(found.single.alias, 'hypericum');
    });

    test('finds a herb by a word inside a name', () {
      final found = fixtureSupplements().search('officinale');
      expect(found.single.supplement.key, 'ginger');
      expect(found.single.alias, 'Zingiber officinale');
    });

    test('finds nothing for nothing, or for a word no name starts', () {
      final reference = fixtureSupplements();
      expect(reference.search(''), isEmpty);
      expect(reference.search('  - '), isEmpty);
      expect(reference.search('inger'), isEmpty);
    });
  });

  group('the reference the app ships', () {
    late SupplementReference reference;

    setUpAll(() async => reference = await loadSupplements(rootBundle));

    test('is the one the generated Dart was made from', () {
      // The drift guard `gen_supplements.py --check` runs in CI, here too so
      // that it fails before a push rather than after.
      final bytes = File(supplementsAsset).readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        supplementsAssetSha256,
        reason:
            'supplements_bundled.dart was generated from another asset. Run '
            'tools/scripts/gen_supplements.py and commit the result.',
      );
    });

    test('holds what the generated Dart says it holds', () {
      expect(reference.herbs, hasLength(supplementsCount));
      expect(reference.fetched, supplementsFetchedDate);
      // Shown as a date on the A to Z, so it has to be one.
      expect(() => CivilDate.parseIso8601(reference.fetched), returnsNormally);
    });

    test("says whose it is, and carries NCCIH's own words about it", () {
      expect(reference.source, startsWith('National Center for Complementary'));
      expect(reference.publicDomain, contains('in the public domain'));
      expect(reference.disclaimer, startsWith('NCCIH has provided'));
    });

    test('every herb has a safety section, names, a date and its page', () {
      for (final herb in reference.herbs) {
        expect(herb.safety, isNotNull, reason: herb.key);
        expect(herb.safety!.blocks, isNotEmpty, reason: herb.key);
        expect(herb.terms, isNotEmpty, reason: herb.key);
        expect(herb.commonNames, isNotEmpty, reason: herb.key);
        expect(herb.latinNames, isNotEmpty, reason: herb.key);
        expect(herb.updated, isNotEmpty, reason: herb.key);
        expect(
          herb.url,
          'https://www.nccih.nih.gov/health/${herb.key}',
          reason: herb.key,
        );
      }
    });

    test('has the herbs a period tracker is asked about', () {
      for (final key in <String>[
        'black-cohosh',
        'chasteberry',
        'evening-primrose-oil',
        'red-clover',
        'st-johns-wort',
      ]) {
        expect(reference.byKey(key), isNotNull, reason: key);
      }
    });

    test('finds St. John’s wort the ways it is written', () {
      for (final query in <String>["St John's wort", 'hypericum', 'klamath']) {
        expect(
          reference.search(query).first.supplement.key,
          'st-johns-wort',
          reason: query,
        );
      }
    });

    test('puts a herb found by its title before one found by another name', () {
      // Ashwagandha is also called Indian ginseng.
      final found = reference.search('ginseng').map((m) => m.supplement.key);
      expect(found.first, 'asian-ginseng');
      expect(found, contains('ashwagandha'));
    });
  });

  group('compared with the medicines the app ships', () {
    late SupplementReference herbs;
    late MedicineBundle bundle;
    late MedicineIndex index;

    setUpAll(() async {
      herbs = await loadSupplements(rootBundle);
      bundle = MedicineBundle(rootBundle, run: <T>(task) async => task());
      index = await bundle.index();
    });

    Future<SupplementPair> compare(String herb, String medicine) async =>
        (await bundle.supplements(
          <Supplement>[herbs.byKey(herb)!],
          <MedicineEntry>[index.byKey(medicine)!],
        )).single;

    test(
      'St. John’s wort and a combined pill, each naming the other',
      () async {
        final pair = await compare(
          'st-johns-wort',
          'drospirenone+ethinyl-estradiol.oral.rx',
        );
        // The pill's label lists the herb among what makes it less effective.
        expect(pair.labelMentions.single.section, 'drug_interactions');
        expect(pair.labelMentions.single.name, 'St. John’s Wort');
        // And the herb's sheet lists "birth control pills", a group the pill
        // is in, under the line that says why.
        final sheet = pair.sheetMentions.single;
        expect(sheet.section, supplementSafetyHeading);
        expect(sheet.group?.name, 'oral contraceptives');
        expect(sheet.passage, 'Birth control pills');
        expect(sheet.leadIn, contains('can weaken the effects of many'));
      },
    );

    test('St. John’s wort and warfarin, by name both ways', () async {
      final pair = await compare('st-johns-wort', 'warfarin-sodium.oral.rx');
      expect(pair.labelMentions, hasLength(1));
      final sheet = pair.sheetMentions.single;
      expect(sheet.name, 'warfarin');
      expect(sheet.group, isNull);
      expect(sheet.passage, startsWith('Warfarin'));
    });

    test('goldenseal and metformin, by the sheet', () async {
      final pair = await compare(
        'goldenseal',
        'metformin-hydrochloride.oral.rx',
      );
      expect(pair.sheetMentions.single.name, 'metformin');
      expect(pair.sheetMentions.single.leadIn, isNull);
    });

    test('a remedy that lists the herb contains it, and is not said to name '
        'it', () async {
      final pair = await compare(
        'st-johns-wort',
        'equisetum-arvense-top+horse-chestnut+sphagnum-squarrosum-peat+'
            'st-john-s-wort.oral.otc',
      );
      expect(pair.ingredients, <String>["st. john's wort"]);
      expect(pair.labelMentions, isEmpty);
      expect(pair.connected, isTrue);
    });

    test('a herb and a medicine neither names are not connected', () async {
      final pair = await compare('chasteberry', 'ibuprofen.oral.otc');
      expect(pair.connected, isFalse);
    });
  });
}
