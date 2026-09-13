// Nutrition copy is reference text, not a diagnosis (AND-27, PLAN 6.2).
//
// The distinction the whole feature rests on, and the reason it is enforced
// rather than reviewed:
//
//   "Heavy menstrual bleeding is a recognised cause of iron deficiency
//    anaemia"          — a statement about physiology. Fine.
//   "You are low in iron"
//                      — a diagnosis of a person, from two logged symptoms
//                        that cannot support one. Not fine anywhere.
//
// The second sentence is one hurried edit away from the first at all times: it
// is shorter, it feels more helpful, and it is the version a well-meaning
// person writes when asked to make the screen friendlier. So the vocabulary is
// a build failure.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Diagnostic assertions, banned wherever they appear.
const List<String> _diagnostic = <String>[
  'you are deficient',
  "you're deficient",
  'you may be deficient',
  'you are low in',
  "you're low in",
  'you have a deficiency',
  'you have anaemia',
  'you have anemia',
  'you should take',
  'you need to take',
  'you should supplement',
  'your levels',
];

/// Second-person framing, banned only in a sentence that is about health.
///
/// AND-27 asks for `"you have"` to be forbidden. Taken literally that is the
/// wrong rule and this test refused to compile with it: the app already says
/// *"once you have logged three cycles"*, *"you have a pregnancy recorded"*,
/// and — the one that makes the point — *"this app is not a diagnostic tool"*.
/// A ban that fails the build on its own disclaimer is not enforcing the rule,
/// it is enforcing a spelling.
///
/// What AND-27 is actually protecting against is the app telling the reader
/// something about their body. So these are banned in any string that also
/// mentions a nutrient or a deficiency, and permitted elsewhere. *"You have
/// logged three cycles"* passes; *"you have low iron"* does not.
const List<String> _secondPerson = <String>['you have', 'you are', 'your'];

/// Words that make a sentence one about the reader's health.
const List<String> _healthTerms = <String>[
  'iron',
  'magnesium',
  'zinc',
  'vitamin',
  'deficien',
  'anaemia',
  'anemia',
  'haemoglobin',
  'hemoglobin',
];

/// Banned unless the same string negates it.
///
/// The disclaimer this app is built around is *"not a diagnostic tool"*, so the
/// word has to be sayable in order to be disclaimed. The rule is that it may
/// only ever appear in a denial.
const List<String> _needsNegation = <String>['diagnos'];

const List<String> _negations = <String>[
  'not ',
  'cannot',
  'does not',
  'do not',
  'never',
  "n't",
];

Map<String, String> _copy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

void main() {
  // Applied to the whole ARB rather than only the nutrition keys. The rule is
  // about the app, and a guard scoped to one screen is a guard that misses the
  // day someone puts the same sentence on a different one.
  test('no copy anywhere asserts a deficiency or recommends a supplement', () {
    final offences = <String>[];
    _copy().forEach((key, value) {
      final text = value.toLowerCase();
      for (final phrase in _diagnostic) {
        if (text.contains(phrase)) offences.add('$key: "$phrase"');
      }
    });
    expect(
      offences,
      isEmpty,
      reason:
          'This addresses a claim to the reader that the app has no way to '
          'establish. Iron deficiency is confirmed by a blood test; two logged '
          'symptoms are not one.\n${offences.join("\n")}',
    );
  });

  test('no copy tells the reader something about their own nutrients', () {
    final offences = <String>[];
    _copy().forEach((key, value) {
      final text = value.toLowerCase();
      if (!_healthTerms.any(text.contains)) return;
      for (final phrase in _secondPerson) {
        if (text.contains(phrase)) offences.add('$key: "$phrase" — "$value"');
      }
    });
    expect(
      offences,
      isEmpty,
      reason:
          'A sentence that names a nutrient and addresses the reader is a '
          'claim about their body. The reference text is allowed to describe '
          'physiology; it is not allowed to describe them.\n'
          '${offences.join("\n")}',
    );
  });

  test('"diagnos-" appears only where it is being denied', () {
    // The word has to be sayable in order to be disclaimed: this app's own
    // onboarding says it is not a diagnostic tool. The rule is that every
    // appearance is a denial.
    final offences = <String>[];
    _copy().forEach((key, value) {
      final text = value.toLowerCase();
      if (!_needsNegation.any(text.contains)) return;
      if (_negations.any(text.contains)) return;
      offences.add('$key: "$value"');
    });
    expect(
      offences,
      isEmpty,
      reason:
          'This uses diagnostic language without denying it. PLAN 6.2 forbids '
          'diagnostic framing outright.\n${offences.join("\n")}',
    );
  });

  test('the hint is pinned word for word', () {
    // Pinned rather than pattern-matched. Every clause here is load-bearing:
    // what it observes, that the observation came from the user, who to talk
    // to, and — by omission — no nutrient, no deficiency, no supplement, and no
    // statement of what the pattern means.
    expect(
      _copy()['nutritionHintBody'],
      'On several days recently you logged heavy flow and fatigue together. '
      'That pattern is worth raising with a doctor or nurse, who can look into '
      'it properly.',
      reason:
          'The hint wording changed. It is pinned because every clause is '
          'doing work: it names only what the user logged, it points at a '
          'human, and it does not say what the pattern means. If this needs to '
          'change, change it deliberately and update the pin.',
    );
  });

  test('the hint names no nutrient, deficiency or supplement', () {
    // The pin above would catch any of these, but stating them separately means
    // a future rewrite gets told *why* it failed rather than only that it did.
    final hint = _copy()['nutritionHintBody']!.toLowerCase();
    for (final word in <String>[
      'iron',
      'magnesium',
      'zinc',
      'vitamin',
      'deficien',
      'supplement',
      'anaemia',
      'anemia',
    ]) {
      expect(
        hint,
        isNot(contains(word)),
        reason:
            'the hint says "$word". It observes two logged symptoms and points '
            'at a clinician; naming a cause is the diagnosis it must not make',
      );
    }
  });

  test('the hint points at a person rather than an action', () {
    final hint = _copy()['nutritionHintBody']!.toLowerCase();
    expect(
      hint.contains('doctor') || hint.contains('nurse'),
      isTrue,
      reason:
          'the hint no longer refers the user to anyone. Without that it is an '
          'observation with an implied conclusion, which is the worst of both',
    );
  });

  group('the claims that stop sections reading as advice', () {
    test('iron says a blood test is what establishes deficiency', () {
      final note = _copy()['nutritionIronDiagnosisNote']!.toLowerCase();
      expect(note, contains('blood test'));
      expect(
        note.contains('cannot') || note.contains('symptoms alone'),
        isTrue,
        reason:
            'the note no longer says symptoms cannot establish it, which is '
            'the sentence that stops the section reading as a checklist',
      );
    });

    // The magnesium section no longer qualifies its own evidence, and the test
    // that required it to went with the sentence, at the owner's direction.
    // What is gone: that trials of magnesium for cramps report limited and
    // inconclusive evidence, that absorption through unbroken skin is minimal,
    // and that no clinical guidance names magnesium as a treatment for period
    // pain. The section now says magnesium is widely taken for cramps, which
    // oral forms absorb best, and that creams are sold for the same purpose.
    //
    // The guards that remain still hold: nothing here asserts a deficiency,
    // recommends a supplement, tells the reader about their own nutrients, or
    // uses diagnostic framing, and the intro still says the page is not advice.

    test('the intro says the page is not about the reader', () {
      final intro = _copy()['nutritionIntro']!.toLowerCase();
      expect(
        intro.contains('not advice') || intro.contains('not advice about'),
        isTrue,
        reason: 'the framing sentence no longer disclaims advice',
      );
      expect(
        intro,
        contains('logged'),
        reason:
            'the intro no longer says the page is unrelated to what the user '
            'logged, which is what stops the reference text reading as a '
            'response to their data',
      );
    });
  });
}
