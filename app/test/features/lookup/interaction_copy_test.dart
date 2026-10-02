// The interaction checker's and the conflict flags' wording (ADR-0014).
//
// The checker reads label text and nothing else, so it has no basis for two
// kinds of sentence, and this file fails the build on either:
//
//   * reassurance. "No interactions found" reads as "safe together", and a
//     pair the labels say nothing about can still be dangerous: labels leave
//     interactions out, and name many medicines only by a group the matching
//     cannot see.
//   * instruction. A flag informs, at the owner's direction. Telling somebody
//     to stop or change a medicine is a pharmacist's call, made knowing things
//     this app does not.
//
// Scanned over the ARB file, where every user-facing string lives.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The checker's strings and the conflict flags', by key.
Map<String, String> _copy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if ((entry.key.startsWith('checker') ||
              entry.key.startsWith('conditionsConflict') ||
              entry.key.startsWith('conditionsMedicine')) &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

/// Phrases that say, or let a reader conclude, that a pair is fine.
const List<String> _reassuring = <String>[
  'no interaction',
  'no known interaction',
  'no conflict',
  'no risk',
  'compatible',
  'all clear',
  'nothing to worry',
  'fine to take',
  'ok to take',
  'okay to take',
  'harmless',
  'safe to take',
  'you can take',
];

/// Phrases that tell the reader what to do about a medicine.
const List<String> _directive = <String>[
  'stop taking',
  'you should',
  'do not take',
  "don't take",
  'must not take',
  'switch to',
];

void main() {
  test('there is wording to check', () {
    // The tests below pass trivially over nothing.
    expect(_copy().keys, containsAll(<String>['checkerNothingFoundNote']));
    expect(
      _copy().keys.where((key) => key.startsWith('conditionsConflict')),
      isNotEmpty,
    );
  });

  test('never reassures', () {
    final offences = <String>[
      for (final MapEntry(:key, :value) in _copy().entries)
        for (final phrase in _reassuring)
          if (value.toLowerCase().contains(phrase)) '$key: "$phrase"',
    ];
    expect(offences, isEmpty);
  });

  test('says "safe" only to say it cannot be said', () {
    final offences = <String>[
      for (final MapEntry(:key, :value) in _copy().entries)
        if (value.toLowerCase().contains('safe') &&
            !value.contains('does not mean') &&
            !value.contains('cannot tell you'))
          key,
    ];
    expect(offences, isEmpty);
  });

  test('never tells the reader what to do about a medicine', () {
    final offences = <String>[
      for (final MapEntry(:key, :value) in _copy().entries)
        for (final phrase in _directive)
          if (value.toLowerCase().contains(phrase)) '$key: "$phrase"',
    ];
    expect(offences, isEmpty);
  });

  test('says a pair with nothing found is not thereby safe together', () {
    expect(
      _copy()['checkerNothingFoundNote'],
      contains('does not mean they are safe together'),
    );
  });
}
