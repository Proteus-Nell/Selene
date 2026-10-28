// A small herbal supplements reference, built in memory in the format
// tools/scripts/gen_supplements.py writes.
//
// The real reference is NCCIH's fact sheets on several dozen herbs. The screen
// and checker tests use two written out here instead, so that a refresh of
// NCCIH's pages cannot change what they assert. supplements_test.dart covers
// the real reference.
//
// The sheets here are written for these tests in NCCIH's shape. They are not
// NCCIH's text, and say nothing true or false about either herb.

import 'dart:convert';
import 'dart:typed_data';

import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';

import 'medicine_fixture.dart';

/// The line the fixture St. John's wort's list hangs from.
const String fixtureLeadIn =
    'For example, it can weaken the effects of many medicines, such as:';

/// The line the fixture St. John's wort's list is nested in.
const String _talkFirst =
    'If you take any type of medicine, talk with your health care provider.';

/// NCCIH's disclaimer, as the fixture reference carries it.
const String fixtureSupplementsDisclaimer =
    'NCCIH has provided this material for your information.';

/// Two herbs, in key order as the generator writes them: one whose sheet
/// names medicines in a nested list, and one whose sheet names one in a
/// sentence.
final List<Map<String, Object?>> fixtureHerbs = <Map<String, Object?>>[
  <String, Object?>{
    'common_names': <String>['ginger'],
    'key': 'ginger',
    'latin_names': <String>['Zingiber officinale'],
    'match': <String>['ginger', 'zingiber officinale'],
    'name': 'Ginger',
    'sections': <Object?>[
      <Object?>[
        'Background',
        <String>['• Ginger is a tropical plant.'],
      ],
      <Object?>[
        supplementSafetyHeading,
        <String>[
          '• Taking ginger with ibuprofen may raise the risk of bleeding.',
        ],
      ],
    ],
    'updated': 'February 2025',
    'url': 'https://www.nccih.nih.gov/health/ginger',
  },
  <String, Object?>{
    'common_names': <String>['St. John’s wort', 'hypericum'],
    'key': 'st-johns-wort',
    'latin_names': <String>['Hypericum perforatum'],
    'match': <String>[
      'hypericum',
      'hypericum perforatum',
      "st. john's wort",
      'st. johns wort',
    ],
    'name': 'St. John’s Wort',
    'sections': <Object?>[
      <Object?>[
        'Background',
        <String>['• St. John’s wort is a plant with yellow flowers.'],
      ],
      <Object?>[
        supplementSafetyHeading,
        <String>[
          '• $_talkFirst',
          '◦ $fixtureLeadIn',
          '▪ Birth control pills',
          '▪ Warfarin',
        ],
      ],
      <Object?>[
        'Keep in Mind',
        <String>['Take charge of your health.'],
      ],
    ],
    'updated': 'May 2025',
    'url': 'https://www.nccih.nih.gov/health/st-johns-wort',
  },
];

/// The reference the generator would write for [herbs], before encoding.
Map<String, Object?> fixtureSupplementsJson([
  List<Map<String, Object?>>? herbs,
]) => <String, Object?>{
  'disclaimer': fixtureSupplementsDisclaimer,
  'fetched': '2026-10-28',
  'herbs': herbs ?? fixtureHerbs,
  'index_url': 'https://www.nccih.nih.gov/health/herbsataglance',
  'public_domain':
      'This publication is not copyrighted and is in the public domain.',
  'schema_version': supplementsSchemaVersion,
  'source':
      'National Center for Complementary and Integrative Health, Herbs at '
      'a Glance',
};

/// The fixture reference, decoded as the app decodes the real one.
SupplementReference fixtureSupplements() =>
    SupplementReference.decode(jsonEncode(fixtureSupplementsJson()));

/// The fixture herb with [key].
Supplement fixtureHerb(String key) => fixtureSupplements().byKey(key)!;

/// An asset bundle holding the fixture reference where the app reads it.
MemoryAssets fixtureSupplementAssets() => MemoryAssets(<String, Uint8List>{
  supplementsAsset: Uint8List.fromList(
    utf8.encode(jsonEncode(fixtureSupplementsJson())),
  ),
});
