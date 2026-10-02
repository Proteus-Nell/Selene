// What medicines' labels say about each other (ADR-0014).
//
// The checker reports three things and nothing else: an ingredient two
// medicines share, an FDA class they share, and a passage where one label
// names the other. Most of what is pinned here is what does not count as a
// mention, because a false one tells somebody their medicines conflict.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';

import 'medicine_fixture.dart';

const String _nsaid = 'Nonsteroidal Anti-inflammatory Drug';

/// The one drug in an index built from [drug].
MedicineEntry _entry(FixtureDrug drug) =>
    fixtureIndex(<FixtureDrug>[drug]).entries.single;

/// Compare [first] and [second], with [first]'s label made of [sections].
InteractionPair _compare(
  FixtureDrug first,
  FixtureDrug second, {
  Map<String, String> sections = const <String, String>{},
  Map<String, String> secondSections = const <String, String>{},
}) => comparePair(
  _entry(first),
  _entry(second),
  firstSections: <MedicineSection>[
    for (final MapEntry(:key, :value) in sections.entries)
      MedicineSection(name: key, text: value),
  ],
  secondSections: <MedicineSection>[
    for (final MapEntry(:key, :value) in secondSections.entries)
      MedicineSection(name: key, text: value),
  ],
);

final FixtureDrug _ibuprofen = fixtureDrug(
  'ibuprofen.oral.otc',
  name: 'IBUPROFEN',
  classes: <String>[_nsaid],
);

final FixtureDrug _naproxen = fixtureDrug(
  'naproxen-sodium.oral.otc',
  name: 'NAPROXEN SODIUM',
  terms: <String>['naproxen', 'naproxen sodium'],
);

final FixtureDrug _estradiol = fixtureDrug(
  'estradiol.oral.rx',
  name: 'ESTRADIOL',
  type: 'rx',
  classes: <String>['Estrogen'],
);

final FixtureDrug _pill = fixtureDrug(
  'ethinyl-estradiol+levonorgestrel.oral.rx',
  name: 'LEVONORGESTREL AND ETHINYL ESTRADIOL',
  substances: <String>['ETHINYL ESTRADIOL', 'LEVONORGESTREL'],
  type: 'rx',
  classes: <String>['Estrogen', 'Progestin'],
);

final FixtureDrug _rifampin = fixtureDrug(
  'rifampin.oral.rx',
  name: 'RIFAMPIN',
  type: 'rx',
);

void main() {
  group('what two medicines share', () {
    test('an ingredient, by the name a label would use', () {
      final pair = _compare(
        _naproxen,
        fixtureDrug('naproxen.oral.rx', name: 'NAPROXEN', type: 'rx'),
      );
      expect(pair.sharedSubstances, <String>['naproxen']);
      expect(pair.connected, isTrue);
    });

    test('once, by its fullest name', () {
      final pair = _compare(
        _naproxen,
        fixtureDrug(
          'naproxen-sodium.oral.rx',
          name: 'NAPROXEN SODIUM',
          type: 'rx',
          terms: <String>['naproxen', 'naproxen sodium'],
        ),
      );
      expect(pair.sharedSubstances, <String>['naproxen sodium']);
    });

    test('an ingredient no other label could name', () {
      // A drug with no match terms still contains what it contains.
      final pair = _compare(
        fixtureDrug('a.oral.otc', name: 'GUAR GUM', terms: <String>[]),
        fixtureDrug('b.oral.otc', name: 'Guar gum', terms: <String>[]),
      );
      expect(pair.sharedSubstances, <String>['guar gum']);
    });

    test('an FDA class', () {
      final pair = _compare(
        _ibuprofen,
        fixtureDrug('naproxen.oral.rx', name: 'NAPROXEN', classes: [_nsaid]),
      );
      expect(pair.sharedClasses, <String>[_nsaid]);
    });

    test('nothing, and nothing is claimed', () {
      final pair = _compare(_ibuprofen, _rifampin);
      expect(pair.sharedSubstances, isEmpty);
      expect(pair.sharedClasses, isEmpty);
      expect(pair.connected, isFalse);
    });
  });

  group('a label naming the other medicine', () {
    test('by one of its names, quoting the sentence', () {
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'drug_interactions':
              'Consult the labeling. Rifampin may reduce the effect of the '
              'pill. Use a back-up method.',
        },
      );
      final mention = pair.firstMentions.single;
      expect(mention.section, 'drug_interactions');
      expect(mention.name, 'rifampin');
      expect(mention.isClass, isFalse);
      expect(mention.passage, 'Rifampin may reduce the effect of the pill.');
      expect(
        mention.passage.substring(mention.start, mention.end),
        'Rifampin',
      );
      expect(pair.secondMentions, isEmpty);
    });

    test('in either direction', () {
      final pair = _compare(
        _rifampin,
        _pill,
        secondSections: <String, String>{
          'drug_interactions': 'Rifampin lowers ethinyl estradiol levels.',
        },
      );
      expect(pair.firstMentions, isEmpty);
      expect(pair.secondMentions.single.name, 'rifampin');
    });

    test('by its name without its salt', () {
      final pair = _compare(
        _ibuprofen,
        _naproxen,
        sections: <String, String>{
          'ask_doctor_or_pharmacist': 'You are taking naproxen.',
        },
      );
      expect(pair.firstMentions.single.name, 'naproxen');
    });

    test('by its class, in the plural', () {
      final pair = _compare(
        _rifampin,
        _ibuprofen,
        sections: <String, String>{
          'warnings':
              'Avoid nonsteroidal anti-inflammatory drugs (NSAIDs) with this.',
        },
      );
      final mention = pair.firstMentions.single;
      expect(mention.isClass, isTrue);
      expect(mention.name, _nsaid);
      expect(
        mention.passage.substring(mention.start, mention.end),
        'nonsteroidal anti-inflammatory drugs',
      );
    });

    test('however the label capitalises or punctuates it', () {
      final pair = _compare(
        _ibuprofen,
        _naproxen,
        sections: <String, String>{
          'warnings': 'NAPROXEN-containing products, and Naproxen\nsodium.',
        },
      );
      final found = <String, String>{
        for (final mention in pair.firstMentions)
          mention.name: mention.passage.substring(mention.start, mention.end),
      };
      expect(found, <String, String>{
        'naproxen': 'NAPROXEN',
        'naproxen sodium': 'Naproxen\nsodium',
      });
    });

    test('only as a whole word', () {
      final pair = _compare(
        _ibuprofen,
        fixtureDrug('iron.oral.otc', name: 'IRON'),
        sections: <String, String>{
          'warnings': 'Irons, ironing and environmental factors.',
        },
      );
      expect(pair.firstMentions, isEmpty);
    });

    test('from the most telling section it is in', () {
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'warnings': 'Rifampin is mentioned among the warnings.',
          'drug_interactions': 'Rifampin reduces efficacy.',
        },
      );
      expect(pair.firstMentions.single.section, 'drug_interactions');
    });

    test('and only from a safety section', () {
      // "Indicated for use with" is not a warning.
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'indications_and_usage': 'For use with rifampin.',
          'purpose': 'Rifampin helper',
        },
      );
      expect(pair.firstMentions, isEmpty);
    });

    test('once for each name, however often it is named', () {
      final pair = _compare(
        _ibuprofen,
        _naproxen,
        sections: <String, String>{
          'warnings': 'Naproxen. Naproxen sodium. Naproxen again.',
          'do_not_use': 'With naproxen.',
        },
      );
      expect(pair.firstMentions.map((mention) => mention.name), <String>[
        'naproxen',
        'naproxen sodium',
      ]);
    });
  });

  group('what is not a mention', () {
    test('a label talking about its own ingredient', () {
      // The pill's label says "ethinyl estradiol" throughout. That is the
      // pill describing itself, not a warning about estradiol.
      final pair = _compare(
        _pill,
        _estradiol,
        sections: <String, String>{
          'warnings': 'Ethinyl estradiol may raise blood pressure.',
        },
      );
      expect(pair.firstMentions, isEmpty);
    });

    test('though the same word on its own still is', () {
      final pair = _compare(
        _pill,
        _estradiol,
        sections: <String, String>{
          'warnings':
              'Ethinyl estradiol may raise blood pressure. Do not combine '
              'with estradiol.',
        },
      );
      expect(pair.firstMentions.single.name, 'estradiol');
      expect(
        pair.firstMentions.single.passage,
        'Do not combine with estradiol.',
      );
    });

    test('an ingredient both contain', () {
      // Said once, as shared, rather than quoted from every paragraph of a
      // label about its own ingredient.
      final pair = _compare(
        fixtureDrug(
          'famotidine+ibuprofen.oral.otc',
          name: 'IBUPROFEN AND FAMOTIDINE',
          substances: <String>['FAMOTIDINE', 'IBUPROFEN'],
        ),
        _ibuprofen,
        sections: <String, String>{'warnings': 'Ibuprofen may cause hives.'},
      );
      expect(pair.sharedSubstances, <String>['ibuprofen']);
      expect(pair.firstMentions, isEmpty);
    });

    test('a class both are in', () {
      final pair = _compare(
        _pill,
        _estradiol,
        sections: <String, String>{
          'boxed_warning': 'Estrogens increase the risk of endometrial cancer.',
        },
      );
      expect(pair.sharedClasses, <String>['Estrogen']);
      expect(pair.firstMentions, isEmpty);
    });

    test('a name with no words in it', () {
      // It would match the empty string, and so every label there is.
      final pair = _compare(
        _ibuprofen,
        fixtureDrug('odd.oral.otc', name: 'ODD', classes: <String>['  -  ']),
        sections: <String, String>{'warnings': 'Anything at all.'},
      );
      expect(pair.firstMentions, isEmpty);
    });
  });

  group('the passage', () {
    test('is cut short where a sentence runs on, between words', () {
      final filler = List<String>.filled(80, 'word').join(' ');
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'drug_interactions': '$filler rifampin $filler',
        },
      );
      final mention = pair.firstMentions.single;
      expect(mention.passage, startsWith('…word'));
      expect(mention.passage, endsWith('word…'));
      expect(mention.passage.length, lessThan(440));
      expect(
        mention.passage.substring(mention.start, mention.end),
        'rifampin',
      );
    });

    test('runs on past an abbreviation', () {
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'drug_interactions':
              "Avoid rifampin and products containing St. John's wort, e.g. "
              'teas. Next sentence.',
        },
      );
      expect(
        pair.firstMentions.single.passage,
        "Avoid rifampin and products containing St. John's wort, e.g. teas.",
      );
    });

    test('stops at a line break', () {
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{
          'drug_interactions': 'Table 2\nRifampin: reduced efficacy\nNext',
        },
      );
      expect(pair.firstMentions.single.passage, 'Rifampin: reduced efficacy');
    });
  });

  group('a list of medicines', () {
    test('is compared a pair at a time, in the order they were added', () {
      final medicines = <MedicineEntry>[
        _entry(_pill),
        _entry(_rifampin),
        _entry(_ibuprofen),
      ];
      final pairs = checkInteractions(
        medicines,
        <String, List<MedicineSection>>{
          _pill.key: const <MedicineSection>[
            MedicineSection(
              name: 'drug_interactions',
              text: 'Rifampin reduces efficacy.',
            ),
          ],
        },
      );
      expect(
        pairs.map((pair) => '${pair.first.key} ${pair.second.key}'),
        <String>[
          '${_pill.key} ${_rifampin.key}',
          '${_pill.key} ${_ibuprofen.key}',
          '${_rifampin.key} ${_ibuprofen.key}',
        ],
      );
      expect(pairs.map((pair) => pair.connected), <bool>[true, false, false]);
    });

    test('of one has no pairs', () {
      expect(
        checkInteractions(<MedicineEntry>[
          _entry(_pill),
        ], const <String, List<MedicineSection>>{}),
        isEmpty,
      );
    });
  });
}
