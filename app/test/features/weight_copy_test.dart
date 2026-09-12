// Body-composition copy explains a mechanism and never addresses the reader
// (AND-35, PLAN 6.2).
//
// This is `nutrition_copy_test.dart`'s rule applied to the subject where it
// matters most, and tightened, because weight content in a cycle-tracking app
// carries a real risk of harm around disordered eating. The distinction the
// whole section rests on:
//
//   "Adipose tissue expresses aromatase, which converts androgens into
//    oestrogens"       — a statement about physiology. Fine.
//   "Your body fat is raising your oestrogen"
//                      — a claim about a person, from data this app does not
//                        have and never asks for. Not fine anywhere.
//   "Losing weight would regulate your cycle"
//                      — an instruction, wearing a mechanism's clothes. The
//                        worst sentence this app could contain.
//
// Three guards, and the second and third are stricter than anything else in the
// app:
//
//   1. A banned vocabulary, over the whole ARB. "lose weight", "bmi",
//      "healthy weight" and the rest are not style preferences; each one is
//      either a target or a judgement, and this app has neither to offer.
//   2. No digits anywhere in the section's copy. A threshold, a range or a
//      calorie figure is something to measure a body against, and the safest
//      number of numbers here is none.
//   3. No second person at all in the section's copy. Not "your", not "you".
//      An absolute rather than a judgement call, because the judgement call is
//      exactly what a hurried edit gets wrong, and "your weight may be
//      affecting your cycle" is one careless sentence away at all times.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Targets and judgements, banned wherever they appear in the app.
///
/// The list AND-35 names, plus the inflections that would walk straight past a
/// substring match on the base form.
const List<String> _bannedAnywhere = <String>[
  'lose weight',
  'losing weight',
  'gain weight',
  'gaining weight',
  'weight loss',
  'weight gain',
  'your weight',
  'overweight',
  'obese',
  'obesity',
  'ideal weight',
  'healthy weight',
  'normal weight',
  'target weight',
  'bmi',
  'body mass index',
  'calorie',
  'kcal',
];

/// Prescriptive framing, banned wherever it appears in the app.
///
/// A mechanism becomes an instruction at exactly these words.
const List<String> _prescriptive = <String>[
  'you should',
  'you need to',
  'you must',
  'aim for',
  'try to lose',
  'try to gain',
  'we recommend',
  'is recommended',
];

/// Second-person risk framing, banned wherever it appears in the app.
///
/// Each of these turns a population statement into a statement about the
/// person holding the phone.
const List<String> _riskFraming = <String>[
  'your risk',
  'puts you at risk',
  'you are at risk',
  "you're at risk",
  'your body fat',
  'your hormones',
  'your oestrogen',
  'your estrogen',
  'your insulin',
  'your thyroid',
  'affecting your cycle',
  'affect your cycle',
];

/// Second person, in any spelling, as whole words.
///
/// Applied only to the `weight*` strings, and there it is absolute. Matched on
/// word boundaries so "young" and "your" are told apart, and so a rename that
/// buried "you" inside a longer word does not slip through.

/// Any digit.
final RegExp _digit = RegExp(r'\d');

Map<String, String> _copy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      // @-metadata is written for translators and is never shown, so a
      // description explaining *why* a word is banned would trip this test.
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Map<String, String> _weightCopy() => <String, String>{
  for (final entry in _copy().entries)
    if (entry.key.startsWith('weight')) entry.key: entry.value,
};

void main() {
  test('the section exists to be checked', () {
    // Every guard below is a scan over a set. An empty set passes all of them,
    // so the set is asserted first.
    expect(
      _weightCopy(),
      isNotEmpty,
      reason:
          'no weight* strings in the ARB. If the section was renamed, rename '
          'the guards with it rather than leaving them scanning nothing.',
    );
  });

  // Applied to the whole ARB rather than only the weight keys. The rule is
  // about the app: a guard scoped to one screen is a guard that misses the day
  // someone puts the same sentence on a different one.
  group('nothing anywhere in the app', () {
    test('offers a weight target or a judgement about a body', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        for (final phrase in _bannedAnywhere) {
          if (text.contains(phrase)) offences.add('$key: "$phrase"');
        }
      });
      expect(
        offences,
        isEmpty,
        reason:
            'Each of these is a target or a judgement. This app records no '
            'body weight, computes no BMI and asks for neither, so it has no '
            'basis for any of them — and on this subject a number the reader '
            'can measure themselves against is the harm.\n'
            '${offences.join("\n")}',
      );
    });

    test('tells the reader to do something about it', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        for (final phrase in _prescriptive) {
          if (text.contains(phrase)) offences.add('$key: "$phrase"');
        }
      });
      expect(
        offences,
        isEmpty,
        reason:
            'A mechanism becomes an instruction at exactly these words. '
            '"Losing weight would regulate your cycle" is the sentence this '
            'guard exists to make impossible.\n${offences.join("\n")}',
      );
    });

    test('frames a risk in the second person', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        for (final phrase in _riskFraming) {
          if (text.contains(phrase)) offences.add('$key: "$phrase"');
        }
      });
      expect(
        offences,
        isEmpty,
        reason:
            'This turns a population statement into a statement about the '
            'person holding the phone. The app cannot see their body fat, '
            'their insulin or their thyroid, and it does not ask.\n'
            '${offences.join("\n")}',
      );
    });
  });

  group('the reference itself', () {
    // A test here banned the word "you" from every string in this section,
    // absolutely. It was dropped at the owner's direction, because the
    // impersonal voice it enforced is most of what made this copy read like a
    // leaflet rather than like a person.
    //
    // What it was protecting is still protected, by a narrower guard that
    // survives: `_mindReading` and `_speculation` run over the whole ARB and
    // still fail the build on "how you feel", "you might be feeling", "how are
    // you feeling" and the rest. The hazard was never the pronoun, it was the
    // claim; "if you want to do less" claims nothing about anybody.

    test('contains no number of any kind', () {
      // No BMI threshold, no weight range, no calorie figure, no day count.
      // Every one of them is something to measure a body against, and this app
      // has no basis for a single one.
      final offences = <String>[];
      _weightCopy().forEach((key, value) {
        if (_digit.hasMatch(value)) offences.add('$key: "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'There is a figure in the body-composition copy. Even a threshold '
            'meant kindly reads as a target here. If a number is genuinely '
            'unavoidable, that is a decision to make deliberately and to '
            'record in docs/WEIGHT_SOURCES.md, not one to make in an '
            'edit.\n${offences.join("\n")}',
      );
    });

    test('the guards above would actually catch one', () {
      // A check that cannot fail is not a check. These pin the detectors.
      expect(_digit.hasMatch('a bmi over 30'), isTrue);
      expect(_digit.hasMatch('across the whole weight spectrum'), isFalse);
    });
  });

  group('the claims that stop the section reading as advice', () {
    test('says up front that the app asks for nothing', () {
      // The first thing a reader who opened this warily should learn.
      final body = _weightCopy()['weightNothingToEnterBody']!.toLowerCase();
      expect(
        body.contains('records no body weight') || body.contains('asks for'),
        isTrue,
        reason:
            'the section no longer says the app wants nothing from the reader, '
            'which is what separates a reference page from a food diary',
      );
      expect(
        body,
        contains('nothing to enter'),
        reason: 'the section no longer says there is nothing to fill in',
      );
    });

    test('the intro disclaims advice and disclaims the reader own data', () {
      final intro = _weightCopy()['weightIntro']!.toLowerCase();
      expect(
        intro,
        contains('not advice'),
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

    test('energy availability is not a number on a scale', () {
      // The claim most likely to be dropped for brevity, and the one that stops
      // this section reading as a statement about body weight. Functional
      // hypothalamic amenorrhoea is about energy, and it happens to people
      // whose weight is unremarkable.
      final body = _weightCopy()['weightEnergyNotAScaleBody']!.toLowerCase();
      expect(
        body.contains('scale'),
        isTrue,
        reason:
            'the energy section no longer says this is not a reading from a '
            'scale, which is the sentence the whole section turns on',
      );
      expect(
        body.contains('unremarkable') || body.contains('no fall in body'),
        isTrue,
        reason:
            'the energy section no longer says it occurs without any fall in '
            'body weight, so it now reads as a claim about being thin',
      );
    });

    test('PCOS is said to occur across the whole weight spectrum', () {
      // The opposite impression is both widespread and false, and a reference
      // that named PCOS in a section about body composition while leaving this
      // out would be reinforcing the error rather than correcting it.
      final body = _weightCopy()['weightPcosSpectrumBody']!.toLowerCase();
      expect(body, contains('whole weight spectrum'));
      expect(
        body,
        contains('thin'),
        reason:
            'the spectrum claim no longer says PCOS occurs in people who are '
            'thin, which is the half of it that gets forgotten',
      );
    });

    test('both directions of the adipose mechanism are given', () {
      // Too little body fat and too much both reach the cycle. Presenting one
      // of them is how this subject does harm.
      final body = _weightCopy()['weightOestrogenBalanceBody']!.toLowerCase();
      expect(body, contains('both directions'));
      expect(
        body.contains('very little'),
        isTrue,
        reason:
            'the balance claim no longer covers the low end, so the section '
            'now argues in one direction',
      );
    });

    test('the last word points at a person rather than at this app', () {
      // Everything above it describes mechanisms, and a page of mechanisms with
      // no exit is an invitation to pick one.
      final body = _weightCopy()['weightChangeBody']!.toLowerCase();
      expect(
        body.contains('doctor') || body.contains('nurse'),
        isTrue,
        reason:
            'the closing text no longer refers the reader to anyone. Without '
            'that it is a list of causes with an implied conclusion, which is '
            'the worst of both',
      );
      expect(
        body.contains('cannot') || body.contains('nothing in this app'),
        isTrue,
        reason:
            'the closing text no longer says the app cannot tell these apart, '
            'which is what stops the page reading as a menu to choose from',
      );
    });
  });
}
