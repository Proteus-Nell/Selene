// The overclaiming rules, machine-enforced (AND-25, ADR-0007, PLAN 6.2).
//
// 6.2 is a rule, not a style guide. The distinction ADR-0007 drew is narrow and
// easy to lose in a hurry: naming a phase restates dates the user logged, while
// naming a fertile window infers ovulation, and only the second one carries
// safety and regulatory weight. A convention that narrow does not survive on
// review alone — it survives on a failing build.
//
// The banned phrases are not a vocabulary preference. Each one is a specific
// claim this app has no basis for:
//
//   "safe day", "safe window"  — contraceptive framing. The app cannot observe
//                                ovulation, so it cannot call any day safe, and
//                                a user who acts on it may become pregnant.
//   "you are ovulating"        — asserts an event, in the present tense, from
//                                cycle dates alone.
//   "fertile" (unqualified)    — the everyday form of the same claim. Permitted
//                                only in a sentence that says what it is not.
//
// Scanned over the ARB file, which is where every user-facing string in this
// app lives, and over the Dart sources as well, so that hard-coding a string
// rather than adding it to the ARB is not a way around this.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phrases that must not appear in anything the user can read.
const List<String> _banned = <String>[
  'safe day',
  'safe days',
  'safe window',
  'safe period',
  'you are ovulating',
  "you're ovulating",
  'ovulating now',
  'ovulation day',
  'fertility window',
];

/// Phrases that are allowed only alongside a disclaimer.
const List<String> _needQualifying = <String>['fertile', 'fertility'];

/// Any of these in the same string qualifies it.
///
/// Deliberately demanding: "cannot", "not accurate enough", "must not be used".
/// A softener like "roughly" does not qualify a fertility claim, and should not
/// be able to buy its way past this test.
const List<String> _qualifiers = <String>[
  'cannot',
  'can not',
  'not accurate enough',
  'must not be used',
  'not reliable',
  'do not use',
  'does not',
];

/// Every user-facing string in the app, keyed by where it came from.
Map<String, String> _copy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      // Skip @-metadata: it is written for translators, not shown to users, and
      // a description explaining *why* a word is banned would trip this test.
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

void main() {
  group('the app never', () {
    test('calls a day safe or asserts that ovulation is happening', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        for (final phrase in _banned) {
          if (text.contains(phrase)) offences.add('$key: "$phrase"');
        }
      });
      expect(
        offences,
        isEmpty,
        reason:
            'These say something the app has no way to know. It cannot observe '
            'ovulation — no temperature, no LH, no ultrasound — so it cannot '
            'call a day safe and cannot say one is happening.\n'
            '${offences.join("\n")}',
      );
    });

    test('uses "fertile" without saying what it is not', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        final mentions = _needQualifying.any(text.contains);
        if (!mentions) return;
        if (_qualifiers.any(text.contains)) return;
        offences.add('$key: "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'Fertility wording is allowed only in a sentence that says what the '
            'estimate is not. Unqualified, it is a contraceptive claim in '
            'everyday clothes.\n${offences.join("\n")}',
      );
    });

    test('smuggles the same wording past the ARB file', () {
      // The ARB is where copy belongs, and the test above only reads the ARB. A
      // hard-coded Text('...') would be invisible to it, so the sources are
      // scanned too. This file names the phrases itself, so it is excluded.
      final offences = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync().toLowerCase();
        for (final phrase in _banned) {
          if (source.contains("'$phrase") || source.contains('"$phrase')) {
            offences.add('${file.path}: "$phrase"');
          }
        }
      }
      expect(offences, isEmpty, reason: offences.join('\n'));
    });
  });

  group('the ovulation estimate', () {
    test('carries its caveat in the same string it is shown with', () {
      // Not behind a link, not in a help screen. This is the claim on the
      // calendar that carries safety weight, and a caveat the user has to
      // navigate to is a caveat they will not read.
      final copy = _copy();
      final caveat = copy['calendarOvulationCaveat'];
      expect(caveat, isNotNull, reason: 'the caveat string is gone');
      final text = caveat!.toLowerCase();
      expect(
        _qualifiers.any(text.contains),
        isTrue,
        reason:
            'the caveat no longer says what the estimate cannot do: $caveat',
      );
      expect(
        text,
        contains('pregnan'),
        reason:
            'the caveat has to name the thing it must not be used for; '
            'a vague "for information only" is not that',
      );
    });

    test('is described as a range rather than a day', () {
      final range = _copy()['calendarOvulationRange'];
      expect(range, isNotNull);
      expect(
        range!.toLowerCase(),
        contains('to '),
        reason:
            'a single-day estimate reads as a fact. This is a population '
            'average applied to someone whose ovulation the app cannot see.',
      );
    });
  });

  test('phase names are the clinical ones', () {
    // Inventing gentler synonyms would leave the user unable to look anything
    // up, which is its own kind of unhelpful. ADR-0007 chose the real names.
    final copy = _copy();
    expect(copy['calendarPhasePeriod'], 'Period');
    expect(copy['calendarPhaseFollicular'], 'Follicular');
    expect(copy['calendarPhaseLuteal'], 'Luteal');
  });
}
