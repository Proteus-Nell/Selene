// What medicines' labels say about each other (ADR-0014, ADR-0021), and what
// a herb's fact sheet and a medicine's label say (ADR-0023).
//
// The checker reports four things and nothing else: an ingredient two
// medicines share, an FDA class they share, a group they are both in, and a
// passage where one label names the other, by name, class or group. Most of
// what is pinned here is what does not count as a mention, because a false
// one tells somebody their medicines conflict.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/domain/models/condition.dart';

import 'medicine_fixture.dart';
import 'supplement_fixture.dart';

const String _nsaid = 'Nonsteroidal Anti-inflammatory Drug';

/// The one drug in an index built from [drug].
MedicineEntry _entry(FixtureDrug drug) =>
    fixtureIndex(<FixtureDrug>[drug]).entries.single;

/// [sections] as a label's.
List<MedicineSection> _label(Map<String, String> sections) => <MedicineSection>[
  for (final MapEntry(:key, :value) in sections.entries)
    MedicineSection(name: key, text: value),
];

/// Compare [first] and [second], with [first]'s label made of [sections].
///
/// With no group table unless [groups] gives one, so that what a name or a
/// class alone finds is pinned apart from the groups.
InteractionPair _compare(
  FixtureDrug first,
  FixtureDrug second, {
  Map<String, String> sections = const <String, String>{},
  Map<String, String> secondSections = const <String, String>{},
  MedicineGroups groups = MedicineGroups.none,
}) => comparePair(
  _entry(first),
  _entry(second),
  firstSections: _label(sections),
  secondSections: _label(secondSections),
  groups: groups,
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
        groups: MedicineGroups.none,
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
        checkInteractions(
          <MedicineEntry>[_entry(_pill)],
          const <String, List<MedicineSection>>{},
          groups: MedicineGroups.none,
        ),
        isEmpty,
      );
    });
  });

  group('a group name', () {
    test('names every drug the group covers', () {
      // Tranexamic acid's label names the pill only as a group.
      final pair = _compare(
        _tranexamic,
        _pill,
        sections: <String, String>{
          'contraindications':
              'Concomitant use of combined hormonal contraceptives.',
        },
        groups: _groups,
      );
      final mention = pair.firstMentions.single;
      expect(mention.group, _chc);
      expect(mention.name, 'combined hormonal contraceptives');
      expect(mention.isClass, isFalse);
      expect(
        mention.passage.substring(mention.start, mention.end),
        'combined hormonal contraceptives',
      );
      expect(pair.connected, isTrue);
    });

    test('by an abbreviation the FDA class is never printed as', () {
      final pair = _compare(
        _rifampin,
        _aspirin,
        sections: <String, String>{'warnings': 'Avoid other NSAIDs.'},
        groups: _groups,
      );
      expect(pair.firstMentions.single.group, _nsaids);
    });

    test('but not a group the other medicine is not in', () {
      final pair = _compare(
        _pill,
        _rifampin,
        sections: <String, String>{'warnings': 'Avoid NSAIDs.'},
        groups: _groups,
      );
      expect(pair.firstMentions, isEmpty);
      expect(pair.connected, isFalse);
    });

    test('nor one straight after "non"', () {
      final pair = _compare(
        _rifampin,
        _iud,
        sections: <String, String>{
          'precautions':
              'Advise a non-hormonal contraceptive. Use a non hormonal '
              'method.',
        },
        groups: _groups,
      );
      expect(pair.firstMentions, isEmpty);
    });

    test('though the group on its own still is', () {
      final pair = _compare(
        _rifampin,
        _iud,
        sections: <String, String>{
          'precautions':
              'Advise a non-hormonal contraceptive. Systemic hormonal '
              'contraceptives may be less effective.',
        },
        groups: _groups,
      );
      expect(
        pair.firstMentions.single.passage,
        'Systemic hormonal contraceptives may be less effective.',
      );
    });

    test('nor one inside a longer group phrase', () {
      // "Combined hormonal contraceptives" are the combined ones. The IUD is
      // a hormonal contraceptive, and not one of these.
      final pair = _compare(
        _tranexamic,
        _iud,
        sections: <String, String>{
          'contraindications':
              'Concomitant use of combined hormonal contraceptives.',
        },
        groups: _groups,
      );
      expect(pair.firstMentions, isEmpty);
    });

    test('nor one in a sentence its FDA class has already been quoted from', () {
      final pair = _compare(
        _rifampin,
        _ibuprofen,
        sections: <String, String>{
          'warnings':
              'Avoid nonsteroidal anti-inflammatory drugs (NSAIDs) with this.',
        },
        groups: _groups,
      );
      final mention = pair.firstMentions.single;
      expect(mention.isClass, isTrue);
      expect(mention.group, isNull);
    });

    test('once, from the most telling section it is in', () {
      final pair = _compare(
        _rifampin,
        _aspirin,
        sections: <String, String>{
          'warnings': 'NSAIDs, said in the warnings.',
          'drug_interactions': 'NSAIDs: increased bleeding. More NSAIDs.',
        },
        groups: _groups,
      );
      final mention = pair.firstMentions.single;
      expect(mention.section, 'drug_interactions');
      expect(mention.passage, 'NSAIDs: increased bleeding.');
    });

    test('a label talking about its own group is not a mention', () {
      // Both are NSAIDs, which is said once, as shared.
      final pair = _compare(
        _aspirin,
        _ibuprofen,
        sections: <String, String>{'warnings': 'NSAIDs may cause bleeding.'},
        groups: _groups,
      );
      expect(pair.sharedGroups, <MedicineGroup>[_nsaids]);
      expect(pair.firstMentions, isEmpty);
      expect(pair.connected, isTrue);
    });

    test('shared, is said in its narrowest form', () {
      // A pill and a ring are combined hormonal contraceptives, and hormonal
      // ones too, which adds nothing.
      final pair = _compare(_pill, _ring, groups: _groups);
      expect(pair.sharedGroups, <MedicineGroup>[_chc]);
    });

    test('shared, is not said again where an FDA class has said it', () {
      final pair = _compare(
        _ibuprofen,
        fixtureDrug('naproxen.oral.rx', name: 'NAPROXEN', classes: [_nsaid]),
        groups: _groups,
      );
      expect(pair.sharedClasses, <String>[_nsaid]);
      expect(pair.sharedGroups, isEmpty);
    });
  });

  group('a recorded kind of contraception', () {
    test('counts as the ingredient all its products contain', () {
      final pair = compareCondition(
        _iudKind,
        _entry(_rifampin),
        sections: _label(<String, String>{
          'drug_interactions': 'Levonorgestrel levels may fall.',
        }),
        groups: _groups,
      );
      expect(pair.mentions.single.name, 'levonorgestrel');
      expect(pair.mentions.single.group, isNull);
      expect(pair.connected, isTrue);
    });

    test('and as the groups they are all in', () {
      final pair = compareCondition(
        _iudKind,
        _entry(_rifampin),
        sections: _label(<String, String>{
          'precautions': 'Hormonal contraceptives may be less effective.',
        }),
        groups: _groups,
      );
      expect(pair.mentions.single.group, _hormonal);
    });

    test('shares what a medicine shares with its products', () {
      final pair = compareCondition(
        _iudKind,
        _entry(_planB),
        sections: const <MedicineSection>[],
        groups: _groups,
      );
      expect(pair.sharedSubstances, <String>['levonorgestrel']);
      expect(pair.sharedGroups, <MedicineGroup>[_hormonal]);
    });

    test('says nothing where the label does not', () {
      final pair = compareCondition(
        _iudKind,
        _entry(_ibuprofen),
        sections: _label(<String, String>{'warnings': 'May cause hives.'}),
        groups: _groups,
      );
      expect(pair.connected, isFalse);
    });

    test('is compared with every medicine, kind by kind', () {
      final pairs = checkConditions(
        <ConditionKind>[_iudKind],
        <MedicineEntry>[_entry(_rifampin), _entry(_ibuprofen)],
        const <String, List<MedicineSection>>{},
        groups: _groups,
      );
      expect(pairs.map((pair) => pair.medicine.key), <String>[
        _rifampin.key,
        _ibuprofen.key,
      ]);
    });

    test('is left out where one of its products is recorded', () {
      // Somebody who records the hormonal IUD and the IUD itself has
      // recorded one thing twice. The medicine, with its own label, stands
      // for it.
      final pairs = checkConditions(
        <ConditionKind>[_iudKind],
        <MedicineEntry>[_entry(_rifampin), _entry(_iud)],
        const <String, List<MedicineSection>>{},
        groups: _groups,
      );
      expect(pairs, isEmpty);
    });
  });

  group('a herb and a medicine', () {
    final stJohnsWort = fixtureHerb('st-johns-wort');
    final ginger = fixtureHerb('ginger');

    SupplementPair compareHerb(
      Supplement herb,
      FixtureDrug drug, {
      Map<String, String> label = const <String, String>{},
      MedicineGroups groups = MedicineGroups.none,
    }) => compareSupplement(
      herb,
      _entry(drug),
      sections: _label(label),
      groups: groups,
    );

    /// A herb whose safety section is [safety], one block a line.
    Supplement herbSaying(List<String> safety) => Supplement(
      key: 'st-johns-wort',
      name: 'St. John’s Wort',
      commonNames: const <String>['St. John’s wort'],
      latinNames: const <String>['Hypericum perforatum'],
      terms: const <String>['hypericum perforatum', "st. john's wort"],
      sections: <SupplementSection>[
        SupplementSection(
          heading: supplementSafetyHeading,
          blocks: <SupplementBlock>[
            for (final block in safety) SupplementBlock.parse(block),
          ],
        ),
      ],
      updated: 'May 2025',
      url: 'https://www.nccih.nih.gov/health/st-johns-wort',
    );

    test('is found on a label by any of its names, and once', () {
      final pair = compareHerb(
        stJohnsWort,
        _rifampin,
        label: <String, String>{
          'drug_interactions':
              "Avoid St. John's Wort (Hypericum perforatum) with rifampin.",
        },
      );
      final mention = pair.labelMentions.single;
      expect(mention.name, 'St. John’s Wort');
      expect(
        mention.passage.substring(mention.start, mention.end),
        "St. John's Wort",
      );
      expect(pair.connected, isTrue);
    });

    test('is found where a label leaves out the apostrophe', () {
      final pair = compareHerb(
        stJohnsWort,
        _rifampin,
        label: <String, String>{'warnings': 'St. Johns Wort lowers levels.'},
      );
      expect(pair.labelMentions, hasLength(1));
    });

    test('is not found inside another word', () {
      final pair = compareHerb(
        ginger,
        _aspirin,
        label: <String, String>{'warnings': 'Contains gingerbread flavour.'},
      );
      expect(pair.labelMentions, isEmpty);
      expect(pair.connected, isFalse);
    });

    test('is not looked for outside the sections a label is read in', () {
      final pair = compareHerb(
        ginger,
        _aspirin,
        label: <String, String>{'purpose': 'With ginger for flavour.'},
      );
      expect(pair.labelMentions, isEmpty);
    });

    test("whose sheet names the medicine is quoted from the sheet's safety "
        'section, under the line its list hangs from', () {
      final pair = compareHerb(stJohnsWort, _warfarin);
      final mention = pair.sheetMentions.single;
      expect(mention.section, supplementSafetyHeading);
      expect(mention.name, 'warfarin');
      expect(mention.passage, 'Warfarin');
      expect(mention.leadIn, fixtureLeadIn);
      expect(pair.labelMentions, isEmpty);
    });

    test('whose sheet names a group the medicine is in says so', () {
      final oral = MedicineGroup(
        name: 'oral contraceptives',
        phrases: const <String>['oral contraceptive', 'birth control pill'],
        members: <String>{_pill.key},
      );
      final pair = compareHerb(
        stJohnsWort,
        _pill,
        groups: MedicineGroups(<MedicineGroup>[oral]),
      );
      final mention = pair.sheetMentions.single;
      expect(mention.group, oral);
      expect(mention.passage, 'Birth control pills');
      expect(mention.leadIn, fixtureLeadIn);
    });

    test('whose sheet names a class the medicine is in says so', () {
      final herb = herbSaying(<String>[
        '• Nonsteroidal anti-inflammatory drugs may add to the risk.',
      ]);
      final mention = compareHerb(herb, _ibuprofen).sheetMentions.single;
      expect(mention.isClass, isTrue);
      expect(mention.name, _nsaid);
      expect(mention.leadIn, isNull);
    });

    test('in a medicine that contains it is said to be in it, and its '
        'label is not said to name it', () {
      final remedy = fixtureDrug(
        'hypericum-perforatum.oral.otc',
        name: 'HYPERICUM PERFORATUM',
      );
      final pair = compareHerb(
        herbSaying(<String>['• Hypericum perforatum can cause sun rashes.']),
        remedy,
        label: <String, String>{'warnings': 'Hypericum perforatum, 30C.'},
      );
      expect(pair.ingredients, <String>['hypericum perforatum']);
      // The label talks about itself, and the sheet about the herb: neither
      // names the other.
      expect(pair.labelMentions, isEmpty);
      expect(pair.sheetMentions, isEmpty);
      expect(pair.connected, isTrue);
    });

    test('is in a medicine whose ingredient starts with one of its names', () {
      final tea = fixtureDrug(
        'hypericum-perforatum-flowering-top.oral.otc',
        name: 'HYPERICUM PERFORATUM FLOWERING TOP',
      );
      expect(compareHerb(stJohnsWort, tea).ingredients, <String>[
        'hypericum perforatum flowering top',
      ]);
      // A name inside a longer word is not one of its names.
      final other = fixtureDrug('hypericin.oral.otc', name: 'HYPERICIN');
      expect(compareHerb(stJohnsWort, other).ingredients, isEmpty);
    });

    test('is compared with every medicine, herb by herb', () {
      final pairs = checkSupplements(
        <Supplement>[ginger, stJohnsWort],
        <MedicineEntry>[_entry(_aspirin), _entry(_warfarin)],
        const <String, List<MedicineSection>>{},
        groups: MedicineGroups.none,
      );
      expect(
        pairs.map((pair) => '${pair.supplement.key} ${pair.medicine.key}'),
        <String>[
          'ginger aspirin.oral.otc',
          'ginger warfarin-sodium.oral.rx',
          'st-johns-wort aspirin.oral.otc',
          'st-johns-wort warfarin-sodium.oral.rx',
        ],
      );
      expect(pairs.where((pair) => pair.connected), hasLength(1));
    });
  });
}

final FixtureDrug _warfarin = fixtureDrug(
  'warfarin-sodium.oral.rx',
  name: 'WARFARIN SODIUM',
  type: 'rx',
  terms: <String>['warfarin', 'warfarin sodium'],
);

final FixtureDrug _tranexamic = fixtureDrug(
  'tranexamic-acid.oral.rx',
  name: 'TRANEXAMIC ACID',
  type: 'rx',
);

final FixtureDrug _aspirin = fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN');

final FixtureDrug _ring = fixtureDrug(
  'ethinyl-estradiol+etonogestrel.vaginal.rx',
  name: 'ETONOGESTREL AND ETHINYL ESTRADIOL',
  substances: <String>['ETHINYL ESTRADIOL', 'ETONOGESTREL'],
  routes: <String>['VAGINAL'],
  type: 'rx',
);

final FixtureDrug _iud = fixtureDrug(
  'levonorgestrel.intrauterine.rx',
  name: 'LEVONORGESTREL',
  routes: <String>['INTRAUTERINE'],
  type: 'rx',
);

final FixtureDrug _planB = fixtureDrug(
  'levonorgestrel.oral.otc',
  name: 'LEVONORGESTREL',
);

final MedicineGroup _nsaids = MedicineGroup(
  name: 'NSAIDs',
  phrases: const <String>['NSAID', 'nonsteroidal anti-inflammatory drug'],
  classes: const <String>[_nsaid],
  members: <String>{_ibuprofen.key, _aspirin.key, 'naproxen.oral.rx'},
);

final MedicineGroup _chc = MedicineGroup(
  name: 'combined hormonal contraceptives',
  phrases: const <String>['combined hormonal contraceptive'],
  members: <String>{_pill.key, _ring.key},
);

final MedicineGroup _hormonal = MedicineGroup(
  name: 'hormonal contraceptives',
  phrases: const <String>['hormonal contraceptive'],
  members: <String>{_pill.key, _ring.key, _iud.key, _planB.key},
);

final ConditionKind _iudKind = ConditionKind(
  condition: Condition.hormonalIud,
  kind: <String>{_iud.key},
  names: const <String>['levonorgestrel'],
  groups: <MedicineGroup>[_hormonal],
  source: const GroupSource(
    title: 'Birth Control',
    publisher: 'FDA',
    url: 'https://www.fda.gov/',
    retrieved: '2026-10-28',
  ),
);

final MedicineGroups _groups = MedicineGroups(
  <MedicineGroup>[_nsaids, _chc, _hormonal],
  conditions: <Condition, ConditionKind>{Condition.hormonalIud: _iudKind},
);
