// The bundled medicines artifact (AND-31).
//
// The data is fetched by `tools/scripts/gen_medicines.py` on a developer
// machine or in CI, committed, and compiled in. **The phone never makes a
// request** — the app has no INTERNET permission at all, and
// assert_no_network.sh fails the build if that changes (ADR-0004, ADR-0009).
//
// What this file covers is the Dart side of that contract: that the constants
// exist, that the things the screen must say are present to say, and that the
// artifact stays inside its size budget. The generator itself is tested in
// research/tests/test_gen_medicines.py.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';

File _repoFile(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError('could not find $relativePath');
}

void main() {
  final artifact = _repoFile('artifacts/medicines/medicines_v1.json');
  final generated = _repoFile('app/lib/data/reference/medicines_bundled.dart');

  test('the generated Dart matches the committed artifact', () {
    // The same drift guard `gen_medicines.py --check` runs in CI, asserted
    // here too so a developer sees it before pushing rather than after. A
    // re-fetched snapshot that nobody regenerated the Dart from would ship
    // the previous snapshot with the new snapshot's date on it.
    expect(
      medicinesArtifactSha256,
      sha256.convert(artifact.readAsBytesSync()).toString(),
      reason:
          'medicines_bundled.dart was generated from a different artifact than '
          'the one committed. Run tools/scripts/gen_medicines.py and commit '
          'the result.',
    );
  });

  test('the jurisdiction is stated, and it is US', () {
    // Strengths, brand names, available formulations and warnings differ in
    // every other country. A reader applying US warnings to a box bought
    // elsewhere is being quietly misinformed, so the screen has to say it and
    // the constant has to be there to say.
    expect(medicinesJurisdiction, 'US');
  });

  test("openFDA's disclaimer travels with the data", () {
    expect(medicinesDisclaimer, contains('openFDA'));
    expect(
      medicinesDisclaimer.toLowerCase(),
      contains('not a substitute'),
      reason:
          'the disclaimer no longer says this is not a substitute for advice '
          'from a doctor or pharmacist',
    );
  });

  test('the artifact stays inside its size budget', () {
    // AND-31 budgets the medicines data at under a megabyte of added APK. The
    // artifact and its generated Dart are the input we control and can
    // measure; CI records the real per-ABI APK sizes as a backstop, because a
    // true growth assertion would need a build both with and without.
    const budget = 1024 * 1024;
    expect(
      artifact.lengthSync(),
      lessThan(budget),
      reason: 'the medicines artifact is over a megabyte',
    );
    expect(
      generated.lengthSync(),
      lessThan(budget),
      reason: 'the generated medicines Dart is over a megabyte',
    );
  });

  test('every bundled entry carries something worth showing', () {
    // An entry with no sections renders as a heading and nothing else, which
    // reads as a broken screen rather than as an absent label.
    for (final medicine in bundledMedicines) {
      expect(
        medicine.sections,
        isNotEmpty,
        reason: '${medicine.key} has no label sections',
      );
      expect(medicine.genericName, isNotEmpty);
    }
  });

  test('no bundled entry carries dosing', () {
    // Deliberate, and enforced here rather than trusted to the generator: a
    // dose read off a US label and applied to a box bought elsewhere is the
    // harm this feature exists to avoid rather than cause.
    for (final medicine in bundledMedicines) {
      for (final section in medicine.sections.keys) {
        expect(
          section.toLowerCase(),
          isNot(contains('dosage')),
          reason: '${medicine.key} carries a dosing section',
        );
      }
    }
  });

  group('the fetched state', () {
    test('is reported rather than looking like an empty result', () {
      // Until someone runs `--fetch`, this repository has an artifact with no
      // entries. Recorded in the constants so the screen can explain itself
      // instead of rendering an empty list, which reads as a bug.
      final payload =
          jsonDecode(artifact.readAsStringSync()) as Map<String, dynamic>;
      final fetched = payload['snapshot_status'] == 'fetched';
      expect(medicinesFetched, fetched);
      if (fetched) {
        expect(medicinesSnapshotDate, isNotNull);
        expect(bundledMedicines, isNotEmpty);
      } else {
        expect(medicinesSnapshotDate, isNull);
        expect(bundledMedicines, isEmpty);
      }
    });

    test('and the release checklist knows about it', () {
      // Shipping an empty reference section silently would be worse than not
      // having one. RELEASE.md carries the gate; this is what stops the gate
      // being quietly deleted.
      final release = _repoFile('docs/RELEASE.md').readAsStringSync();
      expect(
        release,
        contains('gen_medicines.py'),
        reason:
            'RELEASE.md no longer mentions the medicines fetch, so an empty '
            'reference section could ship without anyone noticing',
      );
    });
  });
}
