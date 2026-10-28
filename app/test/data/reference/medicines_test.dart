// The bundled medicines reference, as committed (AND-31, ADR-0012, ADR-0013).
//
// The bundle is built by `tools/scripts/gen_medicines.py` on a developer
// machine or in CI, committed, and shipped as assets. **The phone never makes a
// request** — the app has no INTERNET permission at all, and
// assert_no_network.sh fails the build if that changes (ADR-0004, ADR-0009).
//
// What this file covers is the Dart side of that contract, over the real
// bundle: that the app reads every drug the generator wrote, that each drug's
// text is its own, that no dosing ships, and that searching all of it stays
// quick. The generator itself is tested in research/tests/test_gen_medicines.py.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

import 'medicine_fixture.dart';

File _repoFile(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError('could not find $relativePath');
}

/// The bundle's files, the index first and then the chunks in order: the
/// order gen_medicines.py hashes them in.
List<File> _bundleFiles() {
  final index = _repoFile('app/assets/medicines/index.json.zlib');
  final chunks =
      index.parent
          .listSync()
          .whereType<File>()
          .where(
            (file) => RegExp(
              r'labels-\d{3}\.jsonl\.zlib$',
            ).hasMatch(file.uri.pathSegments.last),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return <File>[index, ...chunks];
}

/// The section names gen_medicines.py may carry, from RX_SECTIONS and
/// OTC_SECTIONS. None of them is dosing.
const Set<String> _carried = <String>{
  'boxed_warning',
  'indications_and_usage',
  'contraindications',
  'warnings_and_cautions',
  'warnings',
  'precautions',
  'drug_interactions',
  'use_in_specific_populations',
  'pregnancy',
  'nursing_mothers',
  'purpose',
  'do_not_use',
  'ask_doctor',
  'ask_doctor_or_pharmacist',
  'when_using',
  'stop_use',
  'pregnancy_or_breast_feeding',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the generated Dart matches the bundle', () {
    // The same drift guard `gen_medicines.py --check` runs in CI, asserted
    // here too so a developer sees it before pushing rather than after. A
    // rebuilt bundle that nobody regenerated the Dart from would show the
    // previous export's date and count over the new export's text.
    final bytes = BytesBuilder(copy: false);
    for (final file in _bundleFiles()) {
      final content = file.readAsBytesSync();
      final name = file.uri.pathSegments.last;
      bytes
        ..add('$name\u0000${content.length}\u0000'.codeUnits)
        ..add(content);
    }
    expect(
      sha256.convert(bytes.takeBytes()).toString(),
      medicinesBundleSha256,
      reason:
          'medicines_bundled.dart was generated from a different bundle than '
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

  test('the bundle stays inside its size budget', () {
    // ADR-0013 budgets the bundle at 16 MB of APK for every drug's safety
    // sections; it is about 13, with the Medication Guides of ADR-0022. A
    // bundle that outgrows it has started
    // carrying something it was not meant to, or compressing worse.
    const budget = 16 * 1024 * 1024;
    final size = _bundleFiles().fold<int>(
      0,
      (sum, file) => sum + file.lengthSync(),
    );
    expect(size, lessThan(budget), reason: 'the bundle is $size bytes');
  });

  group('read the way the app reads it', () {
    late MedicineIndex index;

    setUpAll(() async {
      // Through rootBundle, which serves only what pubspec.yaml declares,
      // and through a real isolate, which refuses anything that cannot be
      // sent to one.
      index = await MedicineBundle(rootBundle).index();
    });

    test('holds what the generated Dart says it holds', () {
      expect(index.entries, hasLength(medicinesCount));
      expect(index.chunkCount, medicinesChunkCount);
      expect(index.exportDate, medicinesSnapshotDate);
      expect(index.jurisdiction, medicinesJurisdiction);
      expect(index.disclaimer, medicinesDisclaimer);
    });

    test("every drug's text is its own, and none of it is dosing", () async {
      // An entry with no sections renders as a heading and nothing else,
      // which reads as a broken screen rather than as an absent label. And a
      // dose read off a US label and applied to a box bought elsewhere is the
      // harm this feature exists to avoid rather than cause.
      final bundle = MedicineBundle(rootBundle, run: inPlace);
      for (final entry in index.entries) {
        final sections = await bundle.sections(entry);
        expect(sections, isNotEmpty, reason: '${entry.key} has no sections');
        for (final section in sections) {
          expect(
            _carried,
            contains(section.name),
            reason: '${entry.key} carries ${section.name}',
          );
          expect(section.text.trim(), isNotEmpty);
        }
      }
    });

    test('every section the bundle carries has a heading', () async {
      // The screen falls back to openFDA's field name, which is visible but
      // is not a heading anybody should read.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final name in _carried) {
        expect(medicineSectionHeading(l10n, name), isNot(name));
      }
    });

    test('search stays quick over every drug', () {
      // The condition the whole A-Z was taken on: every drug, provided search
      // stays quick (ADR-0013). This is a pass over every name a drug can be
      // found by, on every keystroke, on the UI thread. A few milliseconds on
      // a development machine; the budget leaves room for a slow CI runner
      // and still fails a search that has started doing ten times the work.
      const queries = <String>[
        'i',
        'ib',
        'ibuprofen',
        'advil',
        'plan b',
        'levonorgestrel ethinyl',
        'tranexamic acid',
        'zinc',
        'xyzzy',
      ];
      queries.forEach(index.search);
      final watch = Stopwatch()..start();
      const rounds = 5;
      for (var round = 0; round < rounds; round++) {
        queries.forEach(index.search);
      }
      final each = watch.elapsedMicroseconds / (rounds * queries.length);
      expect(
        each,
        lessThan(40000),
        reason: 'a search took ${(each / 1000).toStringAsFixed(1)} ms',
      );
    });

    test('has every drug in its A to Z exactly once', () {
      // A drug left out of the A to Z can still be searched for, so nothing
      // else would notice it missing.
      final listed = <String>[
        for (final letter in MedicineIndex.letters)
          for (final name in index.browse(letter))
            for (final entry in name.entries) entry.key,
      ];
      expect(listed, hasLength(index.entries.length));
      expect(
        listed.toSet(),
        index.entries.map((entry) => entry.key).toSet(),
      );
    });

    test('connects the pairs whose labels are known to', () async {
      // The examples the checker was built from (ADR-0014): a change to the
      // matching, or a refresh, that loses one of them fails here rather
      // than in front of somebody taking both.
      final bundle = MedicineBundle(rootBundle, run: inPlace);
      Future<InteractionPair> compare(String first, String second) async =>
          (await bundle.interactions(<MedicineEntry>[
            index.byKey(first)!,
            index.byKey(second)!,
          ])).single;

      // The pill's label names rifampin among the drugs that weaken it.
      final pill = await compare(
        'ethinyl-estradiol+levonorgestrel.oral.rx',
        'rifampin.oral.rx',
      );
      expect(
        pill.firstMentions.map((mention) => mention.name),
        contains('rifampin'),
      );
      // Two NSAIDs, by the FDA's class, though the shop's ibuprofen label
      // carries no class of its own.
      final nsaids = await compare('ibuprofen.oral.otc', 'naproxen.oral.rx');
      expect(
        nsaids.sharedClasses,
        contains('Nonsteroidal Anti-inflammatory Drug'),
      );
      // Levothyroxine's label names estrogens, the pill's class.
      final thyroid = await compare(
        'levothyroxine-sodium.oral.rx',
        'ethinyl-estradiol+levonorgestrel.oral.rx',
      );
      expect(
        thyroid.firstMentions.map((mention) => mention.name),
        contains('Estrogen'),
      );
    });

    test(
      'connects the pairs whose labels name each other by a group',
      () async {
        // The gap the group table was written to close (ADR-0021): each of
        // these labels names the other medicine only by a group.
        final bundle = MedicineBundle(rootBundle, run: inPlace);
        Future<InteractionPair> compare(String first, String second) async =>
            (await bundle.interactions(<MedicineEntry>[
              index.byKey(first)!,
              index.byKey(second)!,
            ])).single;
        Iterable<String?> groupsIn(List<LabelMention> mentions) =>
            mentions.map((mention) => mention.group?.name);

        // Tranexamic acid contraindicates "combined hormonal contraceptives".
        final tranexamic = await compare(
          'tranexamic-acid.oral.rx',
          'drospirenone+ethinyl-estradiol.oral.rx',
        );
        expect(
          groupsIn(tranexamic.firstMentions),
          contains('combined hormonal contraceptives'),
        );
        // Rifampin's label warns of "systemic hormonal contraceptives".
        final rifampin = await compare(
          'rifampin.oral.rx',
          'drospirenone+ethinyl-estradiol.oral.rx',
        );
        expect(
          groupsIn(rifampin.firstMentions),
          contains('hormonal contraceptives'),
        );
        // Lamotrigine's names "estrogen-containing oral contraceptives".
        final lamotrigine = await compare(
          'lamotrigine.oral.rx',
          'drospirenone+ethinyl-estradiol.oral.rx',
        );
        expect(
          groupsIn(lamotrigine.firstMentions),
          contains('combined oral contraceptives'),
        );
        // Tramadol's names the antidepressants by their classes' abbreviations.
        final tramadol = await compare(
          'tramadol-hydrochloride.oral.rx',
          'sertraline-hydrochloride.oral.rx',
        );
        expect(groupsIn(tramadol.firstMentions), contains('SSRIs'));
        // Two combined pills are said to be so, once.
        final pills = await compare(
          'drospirenone+ethinyl-estradiol.oral.rx',
          'ethinyl-estradiol+norgestimate.oral.rx',
        );
        expect(pills.sharedGroups.map((group) => group.name), <String>[
          'combined oral contraceptives',
        ]);
      },
    );

    test('compares a recorded kind of contraception as its products', () async {
      final bundle = MedicineBundle(rootBundle, run: inPlace);
      final kinds = bundle.groups.conditions;
      Future<ConditionPair> compare(Condition condition, String key) async =>
          (await bundle.conditions(
            <ConditionKind>[
              kinds[condition]!,
            ],
            <MedicineEntry>[index.byKey(key)!],
          )).single;

      // A recorded combined pill, with tranexamic acid.
      final pill = await compare(
        Condition.hormonalContraceptionCombined,
        'tranexamic-acid.oral.rx',
      );
      expect(
        pill.mentions.map((mention) => mention.group?.name),
        contains('combined hormonal contraceptives'),
      );
      // And with rifampin, the owner's example.
      final rifampin = await compare(
        Condition.hormonalContraceptionCombined,
        'rifampin.oral.rx',
      );
      expect(rifampin.connected, isTrue);
      // A hormonal IUD and an emergency pill share levonorgestrel.
      final iud = await compare(
        Condition.hormonalIud,
        'levonorgestrel.oral.otc',
      );
      expect(iud.sharedSubstances, <String>['levonorgestrel']);
    });

    test('carries Medication Guides, their safety sections first', () async {
      // ADR-0022: only the safety sections, the most important information
      // first, and never how to take the medicine.
      expect(medicinesGuideCount, greaterThan(0));
      final bundle = MedicineBundle(rootBundle, run: inPlace);
      final sertraline = index.entries.firstWhere(
        (entry) => entry.key.startsWith('sertraline'),
      );
      final guide = await bundle.guide(sertraline);
      expect(guide, isNotEmpty);
      expect(
        guide.first.heading,
        startsWith('What is the most important information'),
      );
      expect(
        guide.map((section) => section.heading.toLowerCase()),
        everyElement(isNot(contains('how should i take'))),
      );
    });

    test('matches nothing on a name that is only a word', () {
      // Names read off a kit's title, "DAY" or "COLD", would be found in
      // nearly every label; gen_medicines.py keeps them out of the terms.
      final terms = <String>{
        for (final entry in index.entries) ...entry.terms,
      };
      expect(terms, isNot(contains('day')));
      expect(terms, isNot(contains('cold')));
      expect(terms.where((term) => RegExp(r'^\d+$').hasMatch(term)), isEmpty);
    });

    test('finds the drugs the first version got wrong', () {
      // ADR-0012: a text search on the generic name answered emergency
      // contraception with a combined pill and zinc with a diaper cream.
      String first(String query) => index.search(query).matches.first.entry.key;
      expect(first('plan b'), 'levonorgestrel.oral.otc');
      expect(first('levonorgestrel'), 'levonorgestrel.oral.otc');
      expect(first('zinc'), 'zinc.oral.otc');
      expect(first('norethindrone'), 'norethindrone.oral.rx');
      expect(
        index.search('tranexamic').matches.map((match) => match.entry.key),
        contains('tranexamic-acid.oral.rx'),
      );
    });
  });

  group('the fetched state', () {
    test('is reported rather than looking like an empty result', () {
      // Until someone runs `--fetch`, a repository has no bundle at all.
      // Recorded in the constants so the screen can explain itself instead
      // of rendering an empty list, which reads as a bug.
      final built = File(
        '${_repoFile('app/pubspec.yaml').parent.path}'
        '/assets/medicines/index.json.zlib',
      ).existsSync();
      expect(medicinesFetched, built);
      if (built) {
        expect(medicinesSnapshotDate, isNotNull);
        expect(medicinesCount, greaterThan(0));
      } else {
        expect(medicinesSnapshotDate, isNull);
        expect(medicinesCount, 0);
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
