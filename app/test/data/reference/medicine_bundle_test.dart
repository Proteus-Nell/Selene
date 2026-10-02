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
