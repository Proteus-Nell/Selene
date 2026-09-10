// Every pain-and-movement claim on screen is traceable to a committed source
// (AND-36).
//
// The guard `nutrition_sources_test.dart` and `weight_sources_test.dart` put on
// their references, pointed at the subject where the popular version of the
// content is most confident and least supported. "Avoid exercising during your
// period" is the sort of claim that arrives fully formed, sounds caring, and
// has nothing behind it — so on this screen the citation is not a formality,
// it is the thing that decides what may be said at all.
//
// The convention is the one PLAN.md already uses: a claim is marked [VERIFY]
// until someone has opened the source and checked that it says what the claim
// says. Three of the claims here are *absence* claims — they say a named body
// does not recommend something — and those are checked the same way, by reading
// the source and finding nothing in it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourcesPath = '../docs/MOVEMENT_SOURCES.md';
const String _nutritionSourcesPath = '../docs/NUTRITION_SOURCES.md';
const String _releasePath = '../docs/RELEASE.md';
const String _screenPath = 'lib/features/movement/movement_screen.dart';

/// The strings shown on the pain-and-movement reference screen.
///
/// Keyed by prefix rather than listed, so a claim added later is covered
/// without anyone remembering to add it here — which is the case where a guard
/// like this usually fails.
Map<String, String> _movementCopy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') &&
          entry.key.startsWith('movement') &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

String _sources() => File(_sourcesPath).readAsStringSync();

/// The substantive subjects the reference is allowed to raise.
///
/// Matched on subjects rather than on sentences: the copy is written for a
/// reader and the sources file for a checker, so they will never share
/// phrasing. What has to hold is that nothing appears on screen whose subject
/// is absent from the sources file entirely.
const List<String> _subjects = <String>[
  'dysmenorrhoea',
  'period pain',
  'prostaglandin',
  'cramping',
  'cramps',
  'endometriosis',
  'adenomyosis',
  'fibroids',
  'physical activity',
  'cochrane',
  'exercise',
  'exertion',
  'systematic review',
  'cycle phase',
  'injury',
  'hormonal contraception',
  'ovulation',
  'oestrogen',
  'progesterone',
  'faint',
  'light-headed',
  'breathlessness',
  'shortness of breath',
  'chest pain',
  'heavy menstrual bleeding',
  'iron deficiency',
  'anaemia',
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
          'docs/MOVEMENT_SOURCES.md is missing. Every factual claim on the '
          'pain-and-movement screen has to be traceable to something committed '
          'here.',
    );
  });

  test('the screen has something to check in the first place', () {
    // A prefix-keyed scan passes trivially over an empty set, so the set is
    // asserted to be non-empty before anything is asserted about it.
    expect(
      _movementCopy(),
      isNotEmpty,
      reason:
          'no movement* strings in the ARB. Either the section was deleted or '
          'its keys were renamed, and either way every guard in this file and '
          'in movement_copy_test.dart has stopped covering anything.',
    );
  });

  test('every claim in the reference is backed by a listed source', () {
    final missing = _uncited(_movementCopy(), _sources());
    expect(
      missing,
      isEmpty,
      reason:
          'The screen makes a claim about something the sources file does not '
          'cover. Add the claim and its source to docs/MOVEMENT_SOURCES.md '
          'rather than removing this test.\n${missing.join("\n")}',
    );
  });

  test('the scan would actually catch one', () {
    // A check that cannot fail is not a check. Every subject above is in the
    // committed sources file by construction, so the detector is pinned here
    // against a sources file that is missing one.
    const copy = <String, String>{
      'movementEvidenceBody': 'A Cochrane review of exercise for period pain.',
    };
    expect(_uncited(copy, 'cochrane, exercise and period pain'), isEmpty);
    const uncited =
        'movementEvidenceBody mentions "cochrane", which the sources do not';
    expect(
      _uncited(copy, 'exercise for period pain, cited to nobody'),
      <String>[uncited],
    );
  });

  test('the screen renders nothing from outside the audited set', () {
    // The scan above audits every ARB key beginning with `movement`, which is
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
            .where((key) => !key.startsWith('movement'))
            .toSet();
    expect(
      foreign,
      isEmpty,
      reason:
          'The pain-and-movement screen reads a string that this file does not '
          'audit, because the prefix scan only covers movement*. Move the copy '
          'to a movement* key and cite it, or the claim ships uncited.\n'
          '${foreign.join("\n")}',
    );
  });

  test('every listed claim carries a status', () {
    // Either [VERIFY] or a dated verification. A row with neither has been
    // half-edited, and a half-edited citation is worse than an absent one
    // because it looks finished.
    final unmarked = <String>[];
    for (final line in _sources().split('\n')) {
      // Claim rows are table rows whose first cell is an identifier like E2.
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

  test('the claims that stop this becoming a prescription are all cited', () {
    // Each of these is load-bearing, and each is the kind of row a tidying pass
    // removes because the section reads fine without it. It does not: without
    // them the page is either an instruction to exercise or an instruction to
    // rest, and it is not allowed to be either.
    //
    // M1 and M2 were on this list and are not any more. They were the two
    // positive claims — that guidance lists exercise among the measures that
    // may help, and the Cochrane review stated at its real strength — and both
    // were dropped from the sources file at the owner's direction. A row that
    // no longer exists cannot be guarded, so they come off the list rather
    // than fail it. What that costs is worth writing down: the page no longer
    // says exercise helps, only that nothing tells anyone to stop.
    final sources = _sources();
    const why = <String, String>{
      'M3': 'no source in the register names menstruation as a reason to stop',
      'E1':
          'the evidence behind phase-based schemes is low quality and '
          'inconsistent — the claim that stops this page building a plan',
      'E2': 'no guidance recommends planning exercise by cycle phase',
      'E3': 'no guidance says injury risk varies by cycle phase',
      'H1':
          'hormonal contraception suppresses the cycle the phase claims rest '
          'on, which is a second reason not to prescribe by phase',
      'S1':
          'faintness, disproportionate breathlessness and chest pain are '
          'reasons to stop and be checked',
      'C1':
          'severe, worsening or life-interrupting pain is a reason to see '
          'someone — with no threshold and no scale',
    };
    for (final claim in why.keys) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(sources),
        isTrue,
        reason:
            'claim $claim is gone from docs/MOVEMENT_SOURCES.md: $claim is '
            '${why[claim]}. It may not be dropped for brevity.',
      );
    }
  });

  test('the shared iron claim still exists where it is shared from', () {
    // S2, S3 and S4 are the nutrition reference's iron claims, borrowed rather
    // than re-derived, and attributed to the same sources so the two files
    // cannot drift into citing one fact to two different places. That only
    // works while the other end of the cross-reference is still there.
    final movement = _sources();
    expect(
      movement,
      contains('NUTRITION_SOURCES.md'),
      reason:
          'docs/MOVEMENT_SOURCES.md no longer says its iron and anaemia claims '
          'are shared with the nutrition reference. Unmarked, the two files '
          'will drift and nobody will notice which one moved.',
    );

    final nutrition = File(_nutritionSourcesPath).readAsStringSync();
    expect(
      nutrition.toLowerCase(),
      contains('iron deficiency anaemia'),
      reason:
          'docs/NUTRITION_SOURCES.md no longer carries the iron deficiency '
          'anaemia link, which is what the movement section borrows to explain '
          'why exertion can feel harder around a heavy period. Either restore '
          'it there or cite it independently here.',
    );
    for (final claim in <String>['I3', 'I4', 'I5']) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(nutrition),
        isTrue,
        reason:
            'nutrition claim $claim is gone, and docs/MOVEMENT_SOURCES.md S2, '
            'S3 and S4 name it as the claim they share. Update both files '
            'together or they stop agreeing.',
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
          ? 'All pain-and-movement claims are verified.'
          : '$outstanding pain-and-movement claim(s) still marked [VERIFY]. '
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
      contains('MOVEMENT_SOURCES.md'),
      reason:
          'RELEASE.md no longer names docs/MOVEMENT_SOURCES.md, so a reference '
          'section full of [VERIFY] claims could ship without anyone being '
          'asked about it. Nutrition, hygiene and body composition are gated '
          'there; this is too.',
    );
  });

  test('the screen points the reader at the sources file', () {
    // Otherwise "cited" means "cited somewhere the user cannot get to".
    final note = _movementCopy()['movementSourcesNote'];
    expect(note, isNotNull);
    expect(note!.toUpperCase(), contains('MOVEMENT_SOURCES'));
  });
}
