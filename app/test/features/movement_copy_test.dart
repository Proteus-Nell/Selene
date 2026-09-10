// Pain-and-movement copy describes a subject, never prescribes, and never
// addresses the reader (AND-36, PLAN 6.2).
//
// This is `weight_copy_test.dart`'s rule applied to the subject where the wrong
// version is the *popular* version. The distinctions the whole section rests
// on:
//
//   "Clinical guidance on period pain lists exercise among the measures that
//    may help with it"   — a statement about what a source says. Fine.
//   "Avoid exercising during your period"
//                        — an instruction, addressed to a reader this app
//                          cannot see, telling them to stop doing a thing the
//                          evidence says helps with cramps. This section was
//                          asked for in exactly those words and does not say
//                          them.
//   "Follow the follicular phase plan"
//                        — a prescription built on evidence its own systematic
//                          reviews call low quality. Worse than saying nothing,
//                          because a prescription survives being wrong and a
//                          caveat does not.
//   "Listen to your body"
//                        — the friendliest sentence in this subject area, and
//                          still an instruction about a body this app has never
//                          seen. Banned by the same rule as the rest.
//
// Four guards:
//
//   1. A banned vocabulary, over the whole ARB. The instruction forms of
//      "don't exercise", the furniture of a training plan, and the intensity
//      bands are not style preferences; each one is either a prohibition this
//      app has no basis for or a prescription it is not entitled to write.
//   2. No digit anywhere in the section's copy. A number here is either a
//      training figure or a pain score, and the section may hand out neither.
//   3. No second person at all in the section's copy. Not "your", not "you".
//      An absolute rather than a judgement call, for the reason AND-35 gives:
//      the judgement call is what a hurried edit gets wrong.
//   4. The training vocabulary, over the section's own copy. Scoped rather than
//      app-wide, and the reason is at _trainingVocabulary.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prohibitions and prescriptions, banned wherever they appear in the app.
///
/// The instruction forms only. A sentence *reporting* that no source recommends
/// stopping has to remain writable, because saying so is most of this section's
/// job — so "menstruation is not a reason to stop" passes and "do not exercise"
/// does not.
const List<String> _bannedAnywhere = <String>[
  'avoid exercise',
  'avoid exercising',
  'do not exercise',
  "don't exercise",
  'should not exercise',
  'must not exercise',
  'refrain from exercise',
  'no pain no gain',
  'push through the pain',
  'listen to your body',
  'rest day',
  'rest days',
  'training plan',
  'training programme',
  'training program',
  'training schedule',
  'training load',
  'heart rate',
  'times a week',
  'per week',
  'high intensity',
  'high-intensity',
  'moderate intensity',
  'moderate-intensity',
  'low intensity',
  'low-intensity',
  'vigorous intensity',
  'vigorous-intensity',
  'pain scale',
  'out of ten',
];

/// Prescriptive framing, banned wherever it appears in the app.
///
/// A description becomes an instruction at exactly these words. Overlaps
/// `weight_copy_test.dart` on purpose: each reference has to hold on its own,
/// because a guard that only works while another file exists is a guard with a
/// deletion date.
const List<String> _prescriptive = <String>[
  'you should',
  'you need to',
  'you must',
  'aim for',
  'we recommend',
  'is recommended',
  'make sure to',
  'be sure to',
];

/// Exercise-prescription vocabulary with no other everyday meaning.
///
/// Word boundaries rather than substrings: "rep" inside "Replaces" and
/// "repository" is not a repetition, and a substring ban would fail the build
/// on the app's own settings copy.
final Map<String, RegExp> _prescriptionWordsAnywhere = <String, RegExp>{
  'workout': RegExp(r'\bworkouts?\b'),
  'repetition': RegExp(r'\brepetitions?\b'),
  'rep': RegExp(r'\breps?\b'),
};

/// Training vocabulary, banned in the `movement*` strings only.
///
/// Every word here has an ordinary meaning outside exercise, and the app
/// already uses two of them correctly: `weightEnergyNotAScaleBody` says *"heavy
/// training, illness or sustained stress"*, which is a cause of functional
/// hypothalamic amenorrhoea and not a training plan, and
/// `settingsFlowSimplifiedSubtitle` offers to record bleeding *"rather than an
/// intensity"*, which is about flow. "Sets" is one edit away from the same
/// problem the first time a setting description says what it sets.
///
/// So this is the rule `nutrition_copy_test.dart` already had to draw once: a
/// ban that fails the build on the app's own correct copy is enforcing a
/// spelling rather than a rule. Scoped to the section where these words can
/// only mean a prescription, the ban is absolute — the movement reference has
/// no legitimate use for any of them, and needs none to say that phase-based
/// schemes are poorly supported.
final Map<String, RegExp> _trainingVocabulary = <String, RegExp>{
  'train': RegExp(r'\btrain\w*\b'),
  'intensity': RegExp(r'\bintensit\w*\b'),
  'set': RegExp(r'\bsets\b'),
};

/// Second person, in any spelling, as whole words.
///
/// Applied only to the `movement*` strings, and there it is absolute. Matched
/// on word boundaries so "young" and "your" are told apart, and so a rename
/// that buried "you" inside a longer word does not slip through.
final RegExp _secondPerson = RegExp(
  r"\b(you|your|yours|yourself|you're|youre)\b",
);

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

Map<String, String> _movementCopy() => <String, String>{
  for (final entry in _copy().entries)
    if (entry.key.startsWith('movement')) entry.key: entry.value,
};

void main() {
  test('the section exists to be checked', () {
    // Every guard below is a scan over a set. An empty set passes all of them,
    // so the set is asserted first.
    expect(
      _movementCopy(),
      isNotEmpty,
      reason:
          'no movement* strings in the ARB. If the section was renamed, rename '
          'the guards with it rather than leaving them scanning nothing.',
    );
  });

  // Applied to the whole ARB rather than only the movement keys. The rule is
  // about the app: a guard scoped to one screen is a guard that misses the day
  // someone puts the same sentence on a different one.
  group('nothing anywhere in the app', () {
    test('tells anyone to stop exercising, or hands out a plan', () {
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
            'Each of these is either a prohibition or a prescription. This app '
            'records no exercise and asks for none, so it has no basis for '
            'either — and on this subject the prohibition is the one that does '
            'harm, because exercise is among the better-evidenced things for '
            'menstrual cramps.\n${offences.join("\n")}',
      );
    });

    test('carries the furniture of an exercise prescription', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        _prescriptionWordsAnywhere.forEach((label, pattern) {
          final match = pattern.firstMatch(text);
          if (match != null) offences.add('$key: "${match[0]}" ($label)');
        });
      });
      expect(
        offences,
        isEmpty,
        reason:
            'These words have no meaning here except as part of a workout this '
            'app is not entitled to write.\n${offences.join("\n")}',
      );
    });

    test('tells the reader what to do about any of it', () {
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
            'A description becomes an instruction at exactly these words. '
            '"Listen to your body" and "you should rest" are as much '
            'instructions as "you should train", and this page is entitled to '
            'give none of them.\n${offences.join("\n")}',
      );
    });
  });

  group('the reference itself', () {
    test('never once addresses the reader', () {
      // The single most important constraint on this section. There is nothing
      // on this page that needs a second person: it is reference text about
      // pain, movement and the state of the evidence, shown to somebody
      // tracking a cycle. The moment it says "you", it is making a claim about
      // a body it has never seen — and on this subject the friendliest phrasing
      // ("listen to your body", "rest when you need to") is exactly the one
      // that does it.
      final offences = <String>[];
      _movementCopy().forEach((key, value) {
        final match = _secondPerson.firstMatch(value.toLowerCase());
        if (match != null) offences.add('$key: "${match[0]}" — "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'A sentence about pain or exertion that addresses the reader is a '
            'claim about their body, or an instruction to it. This section '
            'describes a subject and is not allowed to describe '
            'anyone.\n${offences.join("\n")}',
      );
    });

    test('contains no number of any kind', () {
      // A digit here is one of two things and neither is allowed: a training
      // figure, or a pain score. There is no third kind of number this section
      // could want.
      final offences = <String>[];
      _movementCopy().forEach((key, value) {
        if (_digit.hasMatch(value)) offences.add('$key: "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'There is a figure in the pain-and-movement copy. A duration or a '
            'count is a prescription; a pain rating is a score to be argued '
            'down by. If a number is genuinely unavoidable, that is a decision '
            'to make deliberately and to record in docs/MOVEMENT_SOURCES.md, '
            'not one to make in an edit.\n${offences.join("\n")}',
      );
    });

    test('never reaches for the training vocabulary', () {
      final offences = <String>[];
      _movementCopy().forEach((key, value) {
        final text = value.toLowerCase();
        _trainingVocabulary.forEach((label, pattern) {
          final match = pattern.firstMatch(text);
          if (match != null) offences.add('$key: "${match[0]}" ($label)');
        });
      });
      expect(
        offences,
        isEmpty,
        reason:
            'This section can say that phase-based schemes are poorly '
            'supported without ever using the vocabulary of one. Reaching for '
            'it is how a page that describes the evidence turns into a page '
            'that applies it.\n${offences.join("\n")}',
      );
    });

    test('the guards above would actually catch one', () {
      // A check that cannot fail is not a check. These pin the detectors.
      expect(_secondPerson.hasMatch('listen to your body'), isTrue);
      expect(_secondPerson.hasMatch('rest when you need to'), isTrue);
      expect(
        _secondPerson.hasMatch('exercise may reduce menstrual pain'),
        isFalse,
      );
      expect(_secondPerson.hasMatch('a young person'), isFalse);
      expect(_digit.hasMatch('30 minutes of light cardio'), isTrue);
      expect(_digit.hasMatch('how hard a given effort seems'), isFalse);
      expect(_trainingVocabulary['train']!.hasMatch('train harder'), isTrue);
      expect(_trainingVocabulary['train']!.hasMatch('a restraint'), isFalse);
      expect(_trainingVocabulary['set']!.hasMatch('three sets'), isTrue);
      expect(_trainingVocabulary['set']!.hasMatch('this setting'), isFalse);
      expect(_prescriptionWordsAnywhere['rep']!.hasMatch('eight reps'), isTrue);
      expect(
        _prescriptionWordsAnywhere['rep']!.hasMatch('the repository'),
        isFalse,
      );
    });
  });

  group('the claims that stop the section becoming advice', () {
    test('the intro disclaims advice and disclaims the reader own data', () {
      final intro = _movementCopy()['movementIntro']!.toLowerCase();
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

    test('says up front that there is no plan here', () {
      // The first thing a reader who came looking for a schedule should learn,
      // because the popular version of this subject is nothing but schedules.
      final body = _movementCopy()['movementNothingToFollowBody']!
          .toLowerCase();
      expect(
        body,
        contains('nothing to enter'),
        reason: 'the section no longer says there is nothing to fill in',
      );
      expect(
        body.contains('no plan') || body.contains('to follow'),
        isTrue,
        reason:
            'the section no longer says there is no plan on the page, which is '
            'what separates a reference from a programme',
      );
    });

    test('says that a period is not a reason to stop', () {
      // The correction this whole section exists for. It was requested as
      // "avoid exercising during menstruation"; the evidence runs the other
      // way, and a cycle app repeating the popular version would be telling
      // people to stop doing something that helps them.
      final body = _movementCopy()['movementNotAvoidedBody']!.toLowerCase();
      expect(
        body.contains('not named') || body.contains('reason to stop'),
        isTrue,
        reason:
            'the section no longer says that no source names menstruation as a '
            'reason to stop, which is the claim it was written to make',
      );
      // The "and guidance says exercise may help" half of this used to be
      // asserted here too. M1 and M2 were dropped from the sources file at the
      // owner's direction, so the section makes no positive claim left to
      // check: what it says now is that no source names menstruation as a
      // reason to stop, and nothing beyond that.
    });

    test('rest is offered as a permission and not as an instruction', () {
      // "Rest when you need to" is the honest line and it is banned by the
      // rule above, correctly: it is an instruction about a body this app
      // cannot see. What survives is the same permission in the third person.
      final body = _movementCopy()['movementRestBody']!.toLowerCase();
      expect(
        body,
        contains('permission'),
        reason:
            'the rest paragraph no longer says outright that it is a '
            'permission rather than an instruction, which is the only thing '
            'that stops "do less" being a prescription in a softer voice',
      );
      expect(
        body.contains('not a lapse') || body.contains('reasonable choice'),
        isTrue,
        reason:
            'the rest paragraph no longer says that doing less is a reasonable '
            'choice, so the permission has gone and only the framing is left',
      );
    });

    test('the phase-based claims are called weak, out loud', () {
      // Declining to build a plan is not the same as saying why. A page that
      // quietly omits the phase-based programme leaves the reader to find one
      // elsewhere; this one says what the evidence under it is worth.
      final body = _movementCopy()['movementPhaseClaimsBody']!.toLowerCase();
      expect(
        body.contains('weak') || body.contains('low quality'),
        isTrue,
        reason:
            'the phase section no longer says the evidence is weak. Omitting '
            'the claim is not the same as answering it',
      );
      expect(
        body,
        contains('injury'),
        reason:
            'the phase section no longer addresses the injury-risk claim, '
            'which is the half of this subject that sounds most like safety '
            'advice and is no better supported',
      );
    });

    test('hormonal contraception is given as a reason not to prescribe', () {
      final body = _movementCopy()['movementContraceptionBody']!.toLowerCase();
      expect(body, contains('ovulation'));
      expect(
        body.contains('phase') || body.contains('scheme'),
        isTrue,
        reason:
            'the contraception paragraph no longer connects to the phase '
            'claims, so it is now a stray fact about contraception on a page '
            'about movement',
      );
    });

    test('the stop signals are reasons to be checked, not to push on', () {
      final body = _movementCopy()['movementStopSignalsBody']!.toLowerCase();
      for (final signal in <String>['faint', 'breathlessness', 'chest pain']) {
        expect(
          body,
          contains(signal),
          reason:
              'the stop-signal paragraph no longer names "$signal". These are '
              'the things that are genuinely worth stopping for, and the '
              'section that says a period is not a reason to stop has to say '
              'what is',
        );
      }
    });

    test('the harder-than-usual day is explained without blaming the cycle', () {
      // The mechanism is the nutrition reference's, borrowed: heavy bleeding
      // is a recognised cause of iron deficiency anaemia, whose commonly listed
      // symptoms include breathlessness. That is why exertion can feel harder
      // around a heavy period, and it points at a blood test rather than at a
      // rule about cycles.
      final body = _movementCopy()['movementAnaemiaBody']!.toLowerCase();
      expect(body, contains('iron deficiency anaemia'));
      expect(
        body,
        contains('blood test'),
        reason:
            'the anaemia paragraph no longer says a blood test is what settles '
            'it, so it now reads as something the reader can conclude from a '
            'hard day',
      );
      expect(
        body.contains('doctor') || body.contains('nurse'),
        isTrue,
        reason:
            'the anaemia paragraph no longer points at a person, which turns a '
            'recognised cause into a diagnosis to be self-applied',
      );
    });

    test('the last word points at a person, with no threshold and no scale', () {
      // Everything above it describes a subject, and a page of description with
      // no exit is an invitation to self-assess.
      final body = _movementCopy()['movementSeeSomeoneBody']!.toLowerCase();
      expect(
        body.contains('doctor') || body.contains('nurse'),
        isTrue,
        reason:
            'the closing text no longer refers the reader to anyone. Without '
            'that it is a list of warning signs with an implied conclusion, '
            'which is the worst of both',
      );
      expect(
        body.contains('severe') && body.contains('worse'),
        isTrue,
        reason:
            'the closing text no longer names severe or worsening pain, which '
            'is what it is for',
      );
      expect(
        body,
        contains('scale'),
        reason:
            'the closing text no longer says that no scale is offered. Saying '
            'so is what stops the omission looking like an oversight and '
            'invites nobody to supply one',
      );
    });
  });
}
