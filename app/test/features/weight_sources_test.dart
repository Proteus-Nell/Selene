// Every body-composition claim on screen is traceable to a committed source
// (AND-35).
//
// The same guard `nutrition_sources_test.dart` puts on the nutrition reference,
// pointed at the subject where an uncited claim would cost the most. The
// convention is the one PLAN.md already uses for the priors figures and the
// dependency pinning: a claim is marked [VERIFY] until someone has opened the
// source and checked that it says what the claim says.
//
// That marker is not decoration. It is a statement that the wording was written
// from general knowledge rather than read off a page, and while any of them
// stands, this reference is not fit to ship. The tests below are what stop
// "we'll check them later" from meaning "nobody will notice".

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourcesPath = '../docs/WEIGHT_SOURCES.md';
const String _releasePath = '../docs/RELEASE.md';
const String _screenPath = 'lib/features/weight/weight_hormones_screen.dart';

/// The strings shown on the body-composition reference screen.
///
/// Keyed by prefix rather than listed, so a claim added later is covered
/// without anyone remembering to add it here — which is the case where a guard
/// like this usually fails.
Map<String, String> _weightCopy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') &&
          entry.key.startsWith('weight') &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

String _sources() => File(_sourcesPath).readAsStringSync();

/// The substantive nouns the reference is allowed to raise.
///
/// Matched on nouns rather than on sentences: the copy is written for a reader
/// and the sources file for a checker, so they will never share phrasing. What
/// has to hold is that nothing appears on screen whose subject is absent from
/// the sources file entirely.
const List<String> _subjects = <String>[
  'aromatase',
  'adipose',
  'body fat',
  'oestrogen',
  'androgen',
  'testosterone',
  'gnrh',
  'hypothalam',
  'pituitary',
  'lh and fsh',
  'energy availability',
  'amenorrhoea',
  'ovulation',
  'insulin',
  'shbg',
  'sex hormone binding globulin',
  'pcos',
  'polycystic',
  'weight spectrum',
  'thyroid',
  'blood test',
];

/// Every `key mentions "subject"` that [sources] does not cover.
List<String> _uncited(Map<String, String> copy, String sources) {
  final lowered = sources.toLowerCase();
  final missing = <String>[];
  copy.forEach((key, value) {
    final text = value.toLowerCase();
    for (final subject in _subjects) {
      if (text.contains(subject) && !lowered.contains(subject)) {
        missing.add('$key mentions "$subject", which the sources do not');
      }
    }
  });
  return missing;
}

void main() {
  test('the sources file exists and is committed', () {
    // A sources file that lives only on someone's laptop is not a citation.
    expect(
      File(_sourcesPath).existsSync(),
      isTrue,
      reason:
          'docs/WEIGHT_SOURCES.md is missing. Every factual claim on the '
          'body-composition screen has to be traceable to something committed '
          'here.',
    );
  });

  test('the screen has something to check in the first place', () {
    // A prefix-keyed scan passes trivially over an empty set, so the set is
    // asserted to be non-empty before anything is asserted about it.
    expect(
      _weightCopy(),
      isNotEmpty,
      reason:
          'no weight* strings in the ARB. Either the section was deleted or '
          'its keys were renamed, and either way every guard in this file and '
          'in weight_copy_test.dart has stopped covering anything.',
    );
  });

  test('every claim in the reference is backed by a listed source', () {
    final missing = _uncited(_weightCopy(), _sources());
    expect(
      missing,
      isEmpty,
      reason:
          'The screen makes a claim about something the sources file does not '
          'cover. Add the claim and its source to docs/WEIGHT_SOURCES.md '
          'rather than removing this test.\n${missing.join("\n")}',
    );
  });

  test('the scan would actually catch one', () {
    // A check that cannot fail is not a check. Every subject above is in the
    // committed sources file by construction, so the detector is pinned here
    // against a sources file that is missing one.
    const copy = <String, String>{
      'weightThyroidBody': 'Thyroid function is established by a blood test.',
    };
    expect(_uncited(copy, 'thyroid, and a blood test'), isEmpty);
    const uncited =
        'weightThyroidBody mentions "blood test", which the sources do not';
    expect(
      _uncited(copy, 'thyroid, and nothing about how it is measured'),
      <String>[uncited],
    );
  });

  test('the screen renders nothing from outside the audited set', () {
    // The scan above audits every ARB key beginning with `weight`, which is
    // only the same thing as auditing the screen for as long as the screen
    // reads nothing else. A section that pulled one paragraph from a key with
    // another prefix would render an unaudited claim through a passing guard,
    // so the screen's own source is checked for what it reaches for.
    //
    // Hard-coded strings are a separate hole and no_hardcoded_strings_test.dart
    // holds it shut.
    final source = File(_screenPath).readAsStringSync();
    final foreign =
        RegExp(r'l10n\.(\w+)|AppLocalizations\.of\(context\)\.(\w+)')
            .allMatches(source)
            .map((match) => match.group(1) ?? match.group(2)!)
            .where((key) => !key.startsWith('weight'))
            .toSet();
    expect(
      foreign,
      isEmpty,
      reason:
          'The body-composition screen reads a string that this file does not '
          'audit, because the prefix scan only covers weight*. Move the copy '
          'to a weight* key and cite it, or the claim ships uncited.\n'
          '${foreign.join("\n")}',
    );
  });

  test('every listed claim carries a status', () {
    // Either [VERIFY] or a dated verification. A row with neither has been
    // half-edited, and a half-edited citation is worse than an absent one
    // because it looks finished.
    final unmarked = <String>[];
    for (final line in _sources().split('\n')) {
      // Claim rows are table rows whose first cell is an identifier like P3.
      if (!RegExp(r'^\|\s*[A-Z]\d+\s*\|').hasMatch(line)) continue;
      if (line.contains('[VERIFY]')) continue;
      if (RegExp(r'\[VERIFIED \d{4}-\d{2}-\d{2}').hasMatch(line)) continue;
      unmarked.add(line.trim());
    }
    expect(
      unmarked,
      isEmpty,
      reason:
          'These claims have no verification status. Mark [VERIFY] until '
          'checked, then [VERIFIED yyyy-mm-dd, initials].\n'
          '${unmarked.join("\n")}',
    );
  });

  test('both directions of the mechanism are cited, not just one', () {
    // Too little body fat and too much both reach the cycle, by different
    // routes. A sources file that dropped one half would let the screen drop
    // it too, and a one-sided version of this subject is the version that
    // does harm.
    final sources = _sources();
    for (final claim in <String>['A3', 'E3', 'E4', 'P3']) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(sources),
        isTrue,
        reason:
            'claim $claim is gone from docs/WEIGHT_SOURCES.md. A3 is the '
            'both-directions statement about adipose tissue, E3 and E4 are '
            'what keep energy availability from reading as a number on a '
            'scale, and P3 is that PCOS occurs across the whole weight '
            'spectrum. None of them may be dropped for brevity.',
      );
    }
  });

  test('the unverified state is visible rather than quiet', () {
    // This test does not fail while claims are unverified — that would block
    // every commit until someone did the reading, and the reading is a release
    // task, not a per-commit one. What it does is make the count impossible to
    // lose track of, and name the checklist item that is supposed to clear it.
    final outstanding = RegExp(r'\[VERIFY\]').allMatches(_sources()).length;
    // Printing is the point: this is a status report to whoever is running the
    // suite, not an assertion. There is no logger in a test binary and a
    // failing test would be the wrong instrument, because the reading is a
    // release task rather than a per-commit one.
    // ignore: avoid_print
    print(
      outstanding == 0
          ? 'All body-composition claims are verified.'
          : '$outstanding body-composition claim(s) still marked [VERIFY]. '
                'RELEASE.md must not pass while any remain.',
    );
    expect(outstanding, greaterThanOrEqualTo(0));
  });

  test('the release checklist gates on the unverified claims', () {
    // The print above is a reminder, not a gate. This is the gate, and this
    // test is what stops it being quietly deleted — an unverified health claim
    // shipping is the failure the whole file exists to prevent.
    final release = File(_releasePath).readAsStringSync();
    expect(
      release,
      contains('WEIGHT_SOURCES.md'),
      reason:
          'RELEASE.md no longer names docs/WEIGHT_SOURCES.md, so a reference '
          'section full of [VERIFY] claims could ship without anyone being '
          'asked about it. Nutrition and hygiene are gated there; this is too.',
    );
  });

  test('the screen points the reader at the sources file', () {
    // Otherwise "cited" means "cited somewhere the user cannot get to".
    final note = _weightCopy()['weightSourcesNote'];
    expect(note, isNotNull);
    expect(note!.toUpperCase(), contains('WEIGHT_SOURCES'));
  });
}
