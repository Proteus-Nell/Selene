// Reading the medicines bundle off the app's assets (ADR-0013).
//
// The index and the label text are separate files, and the index says where
// each drug's text is. If the two ever come from different builds, the text
// at that place belongs to another drug, and the one thing worse than no
// warnings is another medicine's warnings under this one's name.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';

import 'medicine_fixture.dart';

void main() {
  Future<MedicineEntry> entry(MedicineBundle bundle, String key) async =>
      (await bundle.index()).entries.firstWhere((entry) => entry.key == key);

  test("reads a drug's sections, in order and as written", () async {
    final bundle = fixtureBundle(fixtureDrugs);
    final sections = await bundle.sections(
      await entry(bundle, 'ibuprofen.oral.rx'),
    );
    expect(sections.map((section) => section.name), <String>[
      'boxed_warning',
      'indications_and_usage',
      'drug_interactions',
    ]);
    expect(sections.last.paragraphs, <String>[
      'Anticoagulants: increased risk of bleeding.',
      'Aspirin: not generally recommended.',
    ]);
  });

  test("reads a drug's Medication Guide, from the same line", () async {
    final bundle = fixtureBundle(fixtureDrugs);
    final guide = await bundle.guide(await entry(bundle, 'ibuprofen.oral.rx'));
    expect(guide.map((section) => section.heading), <String>[
      fixtureGuideImportant,
      'Who should not take ibuprofen tablets?',
    ]);
    // The bullets the guide printed, put back on lines of their own.
    expect(guide.first.parts, <String>[
      'Ibuprofen can cause serious side effects, including:',
      '• increased risk of a heart attack or stroke',
      '• stomach bleeding',
    ]);
  });

  test('reads none for a drug without one', () async {
    final bundle = fixtureBundle(fixtureDrugs);
    expect(
      await bundle.guide(await entry(bundle, 'ibuprofen.oral.otc')),
      isEmpty,
    );
  });

  test('refuses text that belongs to another drug', () async {
    final assets = MemoryAssets(
      fixtureFiles(fixtureDrugs, records: shifted(fixtureDrugs)),
    );
    final bundle = MedicineBundle(assets, run: inPlace);
    await expectLater(
      bundle.sections(await entry(bundle, 'ibuprofen.intravenous.rx')),
      throwsA(isA<MedicineBundleException>()),
    );
  });

  test('refuses a line past the end of its chunk', () async {
    final assets = MemoryAssets(
      fixtureFiles(fixtureDrugs, records: fixtureDrugs.take(1).toList()),
    );
    final bundle = MedicineBundle(assets, run: inPlace);
    await expectLater(
      bundle.sections(await entry(bundle, 'ibuprofen.oral.otc')),
      throwsA(isA<MedicineBundleException>()),
    );
  });

  test('opens a chunk once for the drugs that share it', () async {
    final assets = MemoryAssets(fixtureFiles(fixtureDrugs));
    final bundle = MedicineBundle(assets, run: inPlace);
    await bundle.sections(await entry(bundle, 'ibuprofen.intravenous.rx'));
    await bundle.sections(await entry(bundle, 'ibuprofen.oral.otc'));
    expect(
      assets.loaded.where((key) => key.endsWith('labels-000.jsonl.zlib')),
      hasLength(1),
    );
  });

  test('reads a chunk again after it failed to load', () async {
    // Kept, a failure would be repeated every time the drug was opened, for
    // as long as the app stayed open.
    final files = fixtureFiles(fixtureDrugs);
    const chunk = 'assets/medicines/labels-000.jsonl.zlib';
    final text = files.remove(chunk)!;
    final bundle = MedicineBundle(MemoryAssets(files), run: inPlace);
    final ibuprofen = await entry(bundle, 'ibuprofen.oral.otc');
    await expectLater(bundle.sections(ibuprofen), throwsA(anything));
    files[chunk] = text;
    expect(await bundle.sections(ibuprofen), isNotEmpty);
  });

  group('what several labels say about each other', () {
    // In key order, as the generator writes them.
    final drugs = <FixtureDrug>[
      fixtureDrug('aspirin.oral.otc', name: 'ASPIRIN'),
      fixtureDrugs.firstWhere((drug) => drug.key == 'ibuprofen.oral.rx'),
      fixtureDrugs.firstWhere((drug) => drug.key == 'tranexamic-acid.oral.rx'),
    ];

    Future<void> check(MedicineBundle bundle) async {
      final index = await bundle.index();
      final pairs = await bundle.interactions(<MedicineEntry>[
        index.byKey('ibuprofen.oral.rx')!,
        index.byKey('aspirin.oral.otc')!,
        index.byKey('tranexamic-acid.oral.rx')!,
      ]);
      expect(pairs, hasLength(3));
      final mention = pairs.first.firstMentions.single;
      expect(mention.name, 'aspirin');
      expect(mention.section, 'drug_interactions');
      expect(mention.passage, 'Aspirin: not generally recommended.');
      expect(pairs.skip(1).map((pair) => pair.connected), <bool>[
        false,
        false,
      ]);
    }

    test('reads each label and compares them', () async {
      await check(fixtureBundle(drugs, perChunk: 1));
    });

    test('in another isolate, unless told otherwise', () async {
      // The drugs, their labels and what is found all cross to the isolate
      // and back.
      await check(MedicineBundle(MemoryAssets(fixtureFiles(drugs))));
    });

    test('refuses a label that belongs to another drug', () async {
      final bundle = MedicineBundle(
        MemoryAssets(fixtureFiles(drugs, records: shifted(drugs))),
        run: inPlace,
      );
      final index = await bundle.index();
      await expectLater(
        bundle.interactions(index.entries),
        throwsA(isA<MedicineBundleException>()),
      );
    });
  });

  test('decodes in another isolate, unless told otherwise', () async {
    // Proves that what crosses to the isolate and back can: a closure that
    // carried the asset bundle along would fail here, and only at run time.
    final bundle = MedicineBundle(MemoryAssets(fixtureFiles(fixtureDrugs)));
    final sections = await bundle.sections(
      await entry(bundle, 'tranexamic-acid.oral.rx'),
    );
    expect(sections.single.name, 'contraindications');
  });
}
