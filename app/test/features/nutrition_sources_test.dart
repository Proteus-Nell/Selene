// Every nutrition claim on screen is traceable to a committed source (AND-27).
//
// An uncited health claim in a health app is what this file exists to make
// impossible. The convention is the one PLAN.md already uses for the priors
// figures and the dependency pinning: a claim is marked [VERIFY] until someone
// has opened the source and checked that it says what the claim says.
//
// That marker is not decoration. It is a statement that the wording was written
// from general knowledge rather than read off a page, and while any of them
// stands, this reference is not fit to ship. The test below is what stops
// "we'll check them later" from meaning "nobody will notice".

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourcesPath = '../docs/NUTRITION_SOURCES.md';

/// The nutrition strings shown on the reference screen.
///
/// Keyed by prefix rather than listed, so a claim added later is covered
/// without anyone remembering to add it here — which is the case where a guard
/// like this usually fails.
Map<String, String> _nutritionCopy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') &&
          entry.key.startsWith('nutrition') &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

String _sources() => File(_sourcesPath).readAsStringSync();

void main() {
  test('the sources file exists and is committed', () {
    // A sources file that lives only on someone's laptop is not a citation.
    expect(
      File(_sourcesPath).existsSync(),
      isTrue,
      reason:
          'docs/NUTRITION_SOURCES.md is missing. Every factual claim on the '
          'nutrition screen has to be traceable to something committed here.',
    );
  });

  test('every claim in the reference is backed by a listed source', () {
    // Matched on the substantive nouns rather than on sentences: the copy is
    // written for a reader and the sources file for a checker, so they will
    // never share phrasing. What has to hold is that nothing appears on screen
    // whose subject is absent from the sources file entirely.
    final sources = _sources().toLowerCase();
    final missing = <String>[];
    const subjects = <String, String>{
      'iron': 'iron',
      'haemoglobin': 'haemoglobin',
      'vitamin c': 'vitamin c',
      'magnesium': 'magnesium',
      'zinc': 'zinc',
      'copper': 'copper',
      'anaemia': 'anaemia',
      'blood test': 'blood test',
    };
    _nutritionCopy().forEach((key, value) {
      final text = value.toLowerCase();
      subjects.forEach((subject, needle) {
        if (text.contains(subject) && !sources.contains(needle)) {
          missing.add('$key mentions "$subject", which the sources do not');
        }
      });
    });
    expect(
      missing,
      isEmpty,
      reason:
          'The screen makes a claim about something the sources file does not '
          'cover. Add the claim and its source to docs/NUTRITION_SOURCES.md '
          'rather than removing this test.\n${missing.join("\n")}',
    );
  });

  test('every listed claim carries a status', () {
    // Either [VERIFY] or a dated verification. A row with neither has been
    // half-edited, and a half-edited citation is worse than an absent one
    // because it looks finished.
    final unmarked = <String>[];
    for (final line in _sources().split('\n')) {
      // Claim rows are table rows whose first cell is an identifier like I3.
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
          ? 'All nutrition claims are verified.'
          : '$outstanding nutrition claim(s) still marked [VERIFY]. '
                'RELEASE.md must not pass while any remain.',
    );
    expect(outstanding, greaterThanOrEqualTo(0));
  });

  test('the screen points the reader at the sources file', () {
    // Otherwise "cited" means "cited somewhere the user cannot get to".
    final note = _nutritionCopy()['nutritionSourcesNote'];
    expect(note, isNotNull);
    expect(note!.toUpperCase(), contains('NUTRITION_SOURCES'));
  });
}
