// Small medicines bundles, built in memory in the format
// tools/scripts/gen_medicines.py writes.
//
// The real bundle is several thousand drugs and 12 MB. The screen and search
// tests use a handful of drugs written out here instead, so that a refresh of
// openFDA's export cannot change what they assert. medicines_test.dart covers
// the real bundle.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';

/// One drug for a test bundle, as a row of the generator's selection.
typedef FixtureDrug = ({
  String key,
  String name,
  List<String> brands,
  List<String> substances,
  List<String> routes,
  String type,
  int labels,
  List<List<String>> sections,
});

/// Describe a drug for a test bundle.
///
/// Its substances default to its name, and its sections to one purpose line.
FixtureDrug fixtureDrug(
  String key, {
  required String name,
  List<String> brands = const <String>[],
  List<String>? substances,
  List<String> routes = const <String>['ORAL'],
  String type = 'otc',
  int labels = 1,
  List<List<String>>? sections,
}) => (
  key: key,
  name: name,
  brands: brands,
  substances: substances ?? <String>[name],
  routes: routes,
  type: type,
  labels: labels,
  sections:
      sections ??
      <List<String>>[
        <String>['purpose', 'Purpose of $name.'],
      ],
);

/// Interactions written in two paragraphs, as a label breaks them.
const String _interactions =
    'Anticoagulants: increased risk of bleeding.\n\n'
    'Aspirin: not generally recommended.';

/// A few drugs with the shapes the lookup has to tell apart: one name in
/// three forms, a drug found by a brand, and a boxed warning.
final List<FixtureDrug> fixtureDrugs = <FixtureDrug>[
  fixtureDrug(
    'ibuprofen.intravenous.rx',
    name: 'IBUPROFEN',
    brands: <String>['Caldolor'],
    routes: <String>['INTRAVENOUS'],
    type: 'rx',
    labels: 4,
    sections: <List<String>>[
      <String>['indications_and_usage', 'Management of pain in adults.'],
    ],
  ),
  fixtureDrug(
    'ibuprofen.oral.otc',
    name: 'IBUPROFEN',
    brands: <String>['Advil', 'Midol Cramps', 'Motrin IB'],
    labels: 300,
    sections: <List<String>>[
      <String>['purpose', 'Pain reliever/fever reducer'],
      <String>['warnings', 'Allergy alert: Ibuprofen may cause hives.'],
    ],
  ),
  fixtureDrug(
    'ibuprofen.oral.rx',
    name: 'IBUPROFEN',
    type: 'rx',
    labels: 40,
    sections: <List<String>>[
      <String>[
        'boxed_warning',
        'WARNING: RISK OF SERIOUS CARDIOVASCULAR AND GASTROINTESTINAL EVENTS',
      ],
      <String>['indications_and_usage', 'Relief of the signs of arthritis.'],
      <String>['drug_interactions', _interactions],
    ],
  ),
  fixtureDrug(
    'levonorgestrel.oral.otc',
    name: 'LEVONORGESTREL',
    brands: <String>['My Way', 'Plan B One-Step', 'Take Action'],
    labels: 53,
    sections: <List<String>>[
      <String>['purpose', 'Emergency contraceptive'],
      <String>[
        'indications_and_usage',
        'Reduces chance of pregnancy after unprotected sex.',
      ],
    ],
  ),
  fixtureDrug(
    'tranexamic-acid.oral.rx',
    name: 'TRANEXAMIC ACID',
    brands: <String>['Lysteda'],
    type: 'rx',
    labels: 15,
    sections: <List<String>>[
      <String>['contraindications', 'Active thromboembolic disease.'],
    ],
  ),
];

/// The index the generator would write for [drugs], before compression.
///
/// Args:
///     drugs (`List<FixtureDrug>`): The drugs, in key order.
///     perChunk (int): How many drugs each text chunk holds.
Map<String, Object?> fixtureIndexJson(
  List<FixtureDrug> drugs, {
  int perChunk = 2,
}) => <String, Object?>{
  'chunks': (drugs.length / perChunk).ceil(),
  'disclaimer': 'Data from openFDA.',
  'entries': <Map<String, Object?>>[
    for (final (i, drug) in drugs.indexed)
      <String, Object?>{
        'brands': drug.brands,
        'chunk': i ~/ perChunk,
        'key': drug.key,
        'label': <String, Object?>{
          'effective_time': '20250929',
          'manufacturer': 'Maker of ${drug.name}',
          'set_id': 'set-${drug.key}',
        },
        'labels': drug.labels,
        'line': i % perChunk,
        'name': drug.name,
        'routes': drug.routes,
        'substances': drug.substances,
        'type': drug.type,
      },
  ],
  'export_date': '2026-10-02',
  'jurisdiction': 'US',
  'schema_version': medicinesBundleSchemaVersion,
};

/// An index ready to search, built from [drugs].
MedicineIndex fixtureIndex(List<FixtureDrug> drugs) =>
    MedicineIndex.fromJson(fixtureIndexJson(drugs));

/// The files the generator would write for [drugs], by asset key.
///
/// Args:
///     drugs (`List<FixtureDrug>`): The drugs, in key order.
///     perChunk (int): How many drugs each text chunk holds.
///     records (`List<FixtureDrug>?`): Whose text to write into the chunks, in
///         place of [drugs]'s own. For a bundle whose index and text disagree.
Map<String, Uint8List> fixtureFiles(
  List<FixtureDrug> drugs, {
  int perChunk = 2,
  List<FixtureDrug>? records,
}) {
  final text = records ?? drugs;
  final files = <String, Uint8List>{
    'assets/medicines/index.json.zlib': _compress(
      jsonEncode(fixtureIndexJson(drugs, perChunk: perChunk)),
    ),
  };
  for (var start = 0; start < text.length; start += perChunk) {
    final lines = <String>[
      for (final drug in text.skip(start).take(perChunk))
        jsonEncode(<String, Object?>{
          'key': drug.key,
          'sections': drug.sections,
        }),
    ];
    final name = (start ~/ perChunk).toString().padLeft(3, '0');
    files['assets/medicines/labels-$name.jsonl.zlib'] = _compress(
      lines.join('\n'),
    );
  }
  return files;
}

/// [drugs] with each one's text moved one place along: what the chunks would
/// hold if the index and the text came from two different builds.
List<FixtureDrug> shifted(List<FixtureDrug> drugs) => <FixtureDrug>[
  ...drugs.skip(1),
  drugs.first,
];

/// A bundle over [drugs] that decodes in place, for a widget test.
MedicineBundle fixtureBundle(List<FixtureDrug> drugs, {int perChunk = 2}) =>
    MedicineBundle(
      MemoryAssets(fixtureFiles(drugs, perChunk: perChunk)),
      run: inPlace,
    );

/// Run a task where it is, rather than in another isolate.
///
/// A widget test's clock is fake, and never sees another isolate finish.
Future<T> inPlace<T>(FutureOr<T> Function() task) => Future<T>.sync(task);

/// An asset bundle over files held in memory, counting what is loaded.
class MemoryAssets extends AssetBundle {
  /// Creates a bundle over [files], by asset key.
  MemoryAssets(this.files);

  /// The files, by asset key.
  final Map<String, Uint8List> files;

  /// Every key loaded, in order, including those that failed.
  final List<String> loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    final bytes = files[key];
    if (bytes == null) throw StateError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

Uint8List _compress(String text) =>
    Uint8List.fromList(zlib.encode(utf8.encode(text)));
