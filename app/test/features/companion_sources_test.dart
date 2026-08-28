// Every health claim the companion makes is traceable to a committed source,
// and every line that makes none says so (AND-37).
//
// The guard `nutrition_sources_test.dart`, `weight_sources_test.dart` and
// `movement_sources_test.dart` put on their reference screens, pointed at a
// surface those three do not have: a character, appearing on every screen,
// saying one sentence at a time. A reference page is read as reference. A line
// from a companion that appeared *because* cramps were logged an hour ago is
// read as being about the reader, so the citation matters more here rather than
// less.
//
// This file also enforces the half of the arrangement the other three did not
// need. Most of what the companion says makes no health claim at all — an offer
// to open the log, a statement about what the app itself is doing — and those
// lines are listed in the sources file as claim-free, with the reason. An
// uncited line and an uncitable line look identical from the outside, so the
// distinction is written down and asserted rather than left to be inferred.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';

const String _sourcesPath = '../docs/COMPANION_SOURCES.md';
const String _nutritionSourcesPath = '../docs/NUTRITION_SOURCES.md';
const String _movementSourcesPath = '../docs/MOVEMENT_SOURCES.md';
const String _releasePath = '../docs/RELEASE.md';
const String _featureDirectory = 'lib/features/companion';

/// Everything the companion can put on screen.
///
/// Keyed by prefix rather than listed, so a line added later is covered without
/// anyone remembering to add it here — which is the case where a guard like
/// this usually fails.
Map<String, String> _companionCopy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') &&
          entry.key.startsWith('companion') &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

String _sources() => File(_sourcesPath).readAsStringSync();

/// The substantive subjects the companion is allowed to raise.
///
/// Matched on subjects rather than on sentences: the lines are written for
/// somebody glancing at a phone and the sources file for somebody checking a
/// citation, so they will never share phrasing. What has to hold is that
/// nothing appears on screen whose subject is absent from the sources file.
const List<String> _subjects = <String>[
  'period pain',
  'cramps',
  'menstruation',
  'menstrual',
  'heavy bleeding',
  'iron deficiency',
  'anaemia',
  'blood test',
  'exercise',
  'painkillers',
  'heat',
  'sleep',
  'tiredness',
  'pregnancy',
  'moving',
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
          'docs/COMPANION_SOURCES.md is missing. Every health claim the '
          'companion can make has to be traceable to something committed '
          'here.',
    );
  });

  test('the companion has something to check in the first place', () {
    // A prefix-keyed scan passes trivially over an empty set, so the set is
    // asserted to be non-empty before anything is asserted about it.
    expect(
      _companionCopy(),
      isNotEmpty,
      reason:
          'no companion* strings in the ARB. Either the feature was deleted or '
          'its keys were renamed, and either way every guard in this file and '
          'in companion_copy_test.dart has stopped covering anything.',
    );
  });

  test('every claim the companion can make is backed by a listed source', () {
    final missing = _uncited(_companionCopy(), _sources());
    expect(
      missing,
      isEmpty,
      reason:
          'The companion can say something about a subject the sources file '
          'does not cover. Add the claim and its source to '
          'docs/COMPANION_SOURCES.md rather than removing this '
          'test.\n${missing.join("\n")}',
    );
  });

  test('the scan would actually catch one', () {
    // A check that cannot fail is not a check. Every subject above is in the
    // committed sources file by construction, so the detector is pinned here
    // against a sources file that is missing one.
    const copy = <String, String>{
      'companionLineCramps': 'Cramps, and what may help with period pain.',
    };
    expect(_uncited(copy, 'cramps and period pain, cited'), isEmpty);
    const uncited =
        'companionLineCramps mentions "cramps", which the sources do not';
    expect(_uncited(copy, 'period pain, cited to nobody'), <String>[uncited]);
  });

  test('every claim-bearing line is named in the sources file', () {
    // Not "some source exists for the subject" but "this line, by key, is
    // accounted for". A line whose key nobody wrote down is a line nobody
    // checked.
    final sources = _sources();
    for (final line in CompanionLine.values.where(
      (line) => line.carriesHealthClaim,
    )) {
      expect(
        sources,
        contains(line.arbKey),
        reason:
            '${line.arbKey} claims something about bodies and '
            'docs/COMPANION_SOURCES.md does not mention it. Cite it or make '
            'the line claim-free — do not leave it in between.',
      );
    }
  });

  test('every claim-free line is recorded as claim-free, with a reason', () {
    // The other half, and the reason this file differs from the three that came
    // before it. Most of what the companion says makes no health claim, and an
    // uncited line and an uncitable line look identical from outside. The
    // sources file names each of these and says why it needs nothing.
    final sources = _sources();
    expect(
      sources,
      contains('The lines that carry no claim'),
      reason:
          'docs/COMPANION_SOURCES.md no longer has the section listing the '
          'lines that need no citation. Without it, the absence of a source '
          'stops being a decision and becomes an omission nobody can tell '
          'apart from a mistake.',
    );
    for (final line in CompanionLine.values.where(
      (line) => !line.carriesHealthClaim,
    )) {
      expect(
        sources,
        contains(line.arbKey),
        reason:
            '${line.arbKey} makes no health claim and the sources file does '
            'not say so. Add it to the claim-free table with the reason.',
      );
    }
  });

  test('the companion renders nothing from outside the audited set', () {
    // The scan above audits every ARB key beginning with `companion`, which is
    // only the same thing as auditing the feature for as long as the feature
    // reads nothing else. A line pulled from a key with another prefix would
    // put an unaudited claim on screen through a passing guard, so the
    // feature's own sources are checked for what they reach for.
    //
    // Hard-coded strings are a separate hole and no_hardcoded_strings_test.dart
    // holds it shut.
    final foreign = <String>{};
    for (final file
        in Directory(_featureDirectory)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      foreign.addAll(
        RegExp(r'l10n\.(\w+)|AppLocalizations\.of\(context\)\.(\w+)')
            .allMatches(source)
            .map((match) => match.group(1) ?? match.group(2)!)
            .where((key) => !key.startsWith('companion')),
      );
    }
    expect(
      foreign,
      isEmpty,
      reason:
          'The companion reads a string that this file does not audit, because '
          'the prefix scan only covers companion*. Move the copy to a '
          'companion* key and cite it, or the claim ships '
          'uncited.\n${foreign.join("\n")}',
    );
  });

  test('every listed claim carries a status', () {
    // Either [VERIFY] or a dated verification. A row with neither has been
    // half-edited, and a half-edited citation is worse than an absent one
    // because it looks finished.
    final unmarked = <String>[];
    for (final line in _sources().split('\n')) {
      // Claim rows are table rows whose first cell is an identifier like I1.
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

  test('the claims that keep each line honest are all cited', () {
    // Each of these is load-bearing, and each is the kind of row a tidying pass
    // removes because the line still reads fine without it.
    final sources = _sources();
    const why = <String, String>{
      'P1':
          'what guidance lists as measures that may help with period pain — '
          'the claim the cramps line reports rather than instructing',
      'M1':
          'no source in the register names menstruation as a reason to stop '
          'moving, which is what lets a line appear on a period day without '
          'telling anybody what to do',
      'S1': 'sleep problems are among the commonly reported symptoms',
      'S2': 'tiredness is among the commonly reported symptoms',
      'I1':
          'heavy menstrual bleeding is a recognised cause of iron '
          'deficiency anaemia',
      'I2':
          'a blood test rather than a symptom is what establishes iron '
          'deficiency — the half of the line that stops it forming an opinion',
    };
    for (final claim in why.keys) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(sources),
        isTrue,
        reason:
            'claim $claim is gone from docs/COMPANION_SOURCES.md: $claim is '
            '${why[claim]}. It may not be dropped for brevity.',
      );
    }
  });

  test('the shared claims still exist where they are shared from', () {
    // I1, I2 and S2 are the nutrition and movement references' claims,
    // borrowed rather than re-derived and attributed to the same sources, so
    // the files cannot drift into citing one fact three different ways. That
    // only works while the other ends of the cross-references are still there.
    final sources = _sources();
    for (final file in <String>[
      'NUTRITION_SOURCES.md',
      'MOVEMENT_SOURCES.md',
    ]) {
      expect(
        sources,
        contains(file),
        reason:
            'docs/COMPANION_SOURCES.md no longer says which of its claims are '
            'shared with $file. Unmarked, the copies drift and nobody notices '
            'which one moved.',
      );
    }

    final nutrition = File(_nutritionSourcesPath).readAsStringSync();
    for (final claim in <String>['I3', 'I5']) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(nutrition),
        isTrue,
        reason:
            'nutrition claim $claim is gone, and docs/COMPANION_SOURCES.md I1 '
            'and I2 name it as the claim they share. Update both files '
            'together or they stop agreeing.',
      );
    }

    final movement = File(_movementSourcesPath).readAsStringSync();
    for (final claim in <String>['M3', 'F1']) {
      expect(
        RegExp('^\\|\\s*$claim\\s*\\|', multiLine: true).hasMatch(movement),
        isTrue,
        reason:
            'movement claim $claim is gone, and docs/COMPANION_SOURCES.md M1 '
            'and S2 are the same claims borrowed from it. Update both files '
            'together or the companion is resting on a citation that no longer '
            'exists.',
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
          ? 'All companion claims are verified.'
          : '$outstanding companion claim(s) still marked [VERIFY]. '
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
      contains('COMPANION_SOURCES.md'),
      reason:
          'RELEASE.md no longer names docs/COMPANION_SOURCES.md, so a thing '
          'that speaks on every screen could ship full of [VERIFY] claims '
          'without anyone being asked about it. Nutrition, hygiene, body '
          'composition and movement are gated there; this is too.',
    );
  });

  test('the suggestion points the reader at the sources file', () {
    // Otherwise "cited" means "cited somewhere the user cannot get to".
    final note = _companionCopy()['companionSourcesNote'];
    expect(note, isNotNull);
    expect(note!.toUpperCase(), contains('COMPANION_SOURCES'));
  });
}
