// Searching the medicines reference (ADR-0012).
//
// Several thousand drugs, searched on every keystroke, by people who know a
// brand, a generic name, or half of either. Most of what is pinned here is the
// order: a search that finds the right drug and lists it fortieth has not
// found it.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/reference/medicine.dart';

import 'medicine_fixture.dart';

/// The keys of what [index] finds for [query], best first.
List<String> _keys(MedicineIndex index, String query, {int limit = 25}) => [
  for (final match in index.search(query, limit: limit).matches)
    match.entry.key,
];

void main() {
  group('folding', () {
    test('ignores case and punctuation', () {
      expect(foldForSearch('ADVIL-PM'), 'advil pm');
      expect(foldForSearch('  Advil   PM. '), 'advil pm');
    });

    test('reads a combination however its label punctuates it', () {
      // One combination is "X AND Y" on one label, "X/Y" on the next and
      // "X, Y" on a third. Read differently, the same pill ranks differently
      // depending on which maker's label stands for it.
      for (final name in <String>[
        'LEVONORGESTREL AND ETHINYL ESTRADIOL',
        'LEVONORGESTREL/ETHINYL ESTRADIOL',
        'Levonorgestrel, ethinyl estradiol',
      ]) {
        expect(foldForSearch(name), 'levonorgestrel ethinyl estradiol');
      }
    });

    test('keeps "and" inside a word', () {
      expect(foldForSearch('SANDOZ'), 'sandoz');
    });

    test('leaves nothing of punctuation alone', () {
      expect(foldForSearch(' - / , '), isEmpty);
    });
  });

  group('what matches', () {
    test('nothing, for nothing typed', () {
      final index = fixtureIndex(fixtureDrugs);
      expect(index.search('').total, 0);
      expect(index.search(' -- ').total, 0);
    });

    test('a brand, and the result says which one', () {
      // Searching "plan b" and getting LEVONORGESTREL back reassures nobody
      // unless the brand is shown with it.
      final found = fixtureIndex(fixtureDrugs).search('plan b');
      expect(found.matches.single.entry.key, 'levonorgestrel.oral.otc');
      expect(found.matches.single.brand, 'Plan B One-Step');
    });

    test('names no brand when the drug was found by its own name', () {
      final found = fixtureIndex(fixtureDrugs).search('levonorgestrel');
      expect(found.matches.single.brand, isNull);
    });

    test('part of a word, once three letters are typed', () {
      final index = fixtureIndex(fixtureDrugs);
      expect(_keys(index, 'profen'), contains('ibuprofen.oral.otc'));
      // Two letters from inside a word match nearly every drug there is.
      expect(_keys(index, 'pr'), isEmpty);
    });

    test('several words, each starting a word somewhere in the drug', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug(
          'ethinyl-estradiol+levonorgestrel.oral.rx',
          name: 'LEVONORGESTREL AND ETHINYL ESTRADIOL',
          substances: <String>['ETHINYL ESTRADIOL', 'LEVONORGESTREL'],
        ),
      ]);
      expect(_keys(index, 'ethinyl levonorgestrel'), <String>[
        'ethinyl-estradiol+levonorgestrel.oral.rx',
      ]);
    });

    test('a word of one letter only as a whole word', () {
      // Otherwise "plan b" also finds every plantain extract whose maker's
      // name has a word starting with b.
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug(
          'levonorgestrel.oral.otc',
          name: 'LEVONORGESTREL',
          brands: <String>['Plan B One-Step'],
        ),
        fixtureDrug(
          'plantago.oral.otc',
          name: 'PLANTAGO MAJOR',
          brands: <String>['Bee Balm'],
        ),
      ]);
      expect(_keys(index, 'plan b'), <String>['levonorgestrel.oral.otc']);
    });

    test('counts every match, not just those it returns', () {
      final index = fixtureIndex(<FixtureDrug>[
        for (var i = 10; i < 40; i++)
          fixtureDrug('testamine-$i.oral.otc', name: 'TESTAMINE $i'),
      ]);
      final found = index.search('testamine');
      expect(found.matches, hasLength(25));
      expect(found.total, 30);
    });
  });

  group('the order', () {
    test('a whole name before one that starts with it', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('iron.oral.otc', name: 'IRON'),
        fixtureDrug(
          'iron-sucrose.intravenous.rx',
          name: 'IRON SUCROSE',
          labels: 50,
        ),
      ]);
      expect(_keys(index, 'iron').first, 'iron.oral.otc');
    });

    test('a name that starts with it before a word inside one', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN'),
        fixtureDrug(
          'aspirin+buffer.oral.otc',
          name: 'BUFFERED ASPIRIN',
          labels: 50,
        ),
      ]);
      expect(_keys(index, 'aspi'), <String>[
        'aspirin.oral.otc',
        'aspirin+buffer.oral.otc',
      ]);
    });

    test("a drug's own name, then what it contains, then a brand", () {
      // "zinc" has to list zinc before the multivitamins that contain it,
      // however many labels the multivitamins have.
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug(
          'calcium+zinc.oral.otc',
          name: 'MULTIVITAMIN',
          substances: <String>['CALCIUM', 'ZINC'],
          labels: 90,
        ),
        fixtureDrug(
          'menthol.topical.otc',
          name: 'MENTHOL',
          brands: <String>['Zinc Shield'],
          labels: 99,
        ),
        fixtureDrug('zinc.oral.otc', name: 'ZINC'),
      ]);
      expect(_keys(index, 'zinc'), <String>[
        'zinc.oral.otc',
        'calcium+zinc.oral.otc',
        'menthol.topical.otc',
      ]);
    });

    test("a start of any name before a word inside the drug's own", () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug(
          'aspirin+caffeine.oral.otc',
          name: 'PAIN RELIEF WITH ASPIRIN',
          substances: <String>['CAFFEINE', 'SALICYLATE'],
        ),
        fixtureDrug(
          'sodium-salicylate.oral.otc',
          name: 'SODIUM SALICYLATE',
          brands: <String>['Aspirin Free'],
        ),
      ]);
      expect(_keys(index, 'aspirin').first, 'sodium-salicylate.oral.otc');
    });

    test('the form most widely sold first', () {
      // Ibuprofen tablets from the shop shelf before ibuprofen by drip.
      expect(_keys(fixtureIndex(fixtureDrugs), 'ibuprofen'), <String>[
        'ibuprofen.oral.otc',
        'ibuprofen.oral.rx',
        'ibuprofen.intravenous.rx',
      ]);
    });

    test('then the shorter name, then the key', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('b.oral.otc', name: 'ACETAMINOPHEN'),
        fixtureDrug('a.oral.otc', name: 'ACETAMINOPHEN'),
        fixtureDrug('c.oral.otc', name: 'ACETAMINOPHEN EXTRA'),
      ]);
      expect(_keys(index, 'acet'), <String>[
        'a.oral.otc',
        'b.oral.otc',
        'c.oral.otc',
      ]);
    });
  });

  group('the A to Z', () {
    List<String> names(MedicineIndex index, String letter) => <String>[
      for (final name in index.browse(letter)) name.name,
    ];

    test('lists a name once, however its labels write it', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('ibuprofen.oral.otc', name: 'IBUPROFEN', labels: 300),
        fixtureDrug('ibuprofen.oral.rx', name: 'Ibuprofen', labels: 40),
        fixtureDrug(
          'ethinyl-estradiol+levonorgestrel.oral.rx',
          name: 'LEVONORGESTREL AND ETHINYL ESTRADIOL',
        ),
        fixtureDrug(
          'ethinyl-estradiol+levonorgestrel.transdermal.rx',
          name: 'LEVONORGESTREL/ETHINYL ESTRADIOL',
          routes: <String>['TRANSDERMAL'],
        ),
      ]);
      expect(index.browse('i').single.entries, hasLength(2));
      expect(index.browse('l').single.entries, hasLength(2));
    });

    test('names a row after the most widely sold of its medicines', () {
      // And lists that one first: ibuprofen from a shop shelf before the
      // prescription tablets and the injection.
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('ibuprofen.oral.rx', name: 'IBUPROFEN', labels: 40),
        fixtureDrug('ibuprofen.oral.otc', name: 'Ibuprofen', labels: 300),
      ]);
      final name = index.browse('i').single;
      expect(name.name, 'Ibuprofen');
      expect(name.entries.first.key, 'ibuprofen.oral.otc');
    });

    test('is in alphabetical order, whatever the case', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('c.oral.otc', name: 'aspirin'),
        fixtureDrug('a.oral.otc', name: 'ZINC'),
        fixtureDrug('b.oral.otc', name: 'ACETAMINOPHEN'),
        fixtureDrug('d.oral.otc', name: 'Allantoin'),
      ]);
      expect(names(index, 'a'), <String>[
        'ACETAMINOPHEN',
        'Allantoin',
        'aspirin',
      ]);
      expect(names(index, 'z'), <String>['ZINC']);
    });

    test('files a name that does not start with a letter under #', () {
      final index = fixtureIndex(<FixtureDrug>[
        fixtureDrug('a.topical.otc', name: '1,2-HEXANEDIOL'),
        fixtureDrug('b.topical.otc', name: '(+)-LIMONENE'),
      ]);
      expect(names(index, '#'), <String>['1,2-HEXANEDIOL']);
      expect(names(index, 'l'), <String>['(+)-LIMONENE']);
    });

    test('has every medicine in it exactly once', () {
      final index = fixtureIndex(fixtureDrugs);
      final listed = <String>[
        for (final letter in MedicineIndex.letters)
          for (final name in index.browse(letter))
            for (final entry in name.entries) entry.key,
      ];
      expect(listed, unorderedEquals(fixtureDrugs.map((drug) => drug.key)));
    });

    test('has nothing under a letter no name starts with', () {
      expect(fixtureIndex(fixtureDrugs).browse('q'), isEmpty);
    });
  });

  group('the index', () {
    test('refuses a schema it does not read', () {
      final json = fixtureIndexJson(fixtureDrugs)..['schema_version'] = 2;
      expect(
        () => MedicineIndex.fromJson(json),
        throwsA(isA<MedicineBundleException>()),
      );
    });

    test("reads a label's date, and only a real one", () {
      MedicineLabel label(String time) =>
          MedicineLabel(setId: 's', manufacturer: 'm', effectiveTime: time);
      expect(label('20250929').effectiveDate, CivilDate(2025, 9, 29));
      expect(label('20250230').effectiveDate, isNull);
      expect(label('2025').effectiveDate, isNull);
    });
  });
}
