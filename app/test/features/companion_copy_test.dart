// The companion's register, machine-enforced (AND-37, PLAN 6.3).
//
// A character is the feature that walks into every failure 6.3 names. It is
// the thing a well-meaning edit makes friendlier, and "friendlier" here means
// euphemism, forced positivity, and congratulating somebody for having
// remembered to record their own bleeding. The distinctions the whole feature
// rests on:
//
//   "Cramps are recorded for today"
//                     — a statement about what was logged. Fine.
//   "Feeling rough? That time of the month can be tough!"
//                     — a euphemism, a guess about how somebody feels, and an
//                       exclamation mark. Three failures in nine words, and it
//                       is exactly the sentence this feature attracts.
//   "Nice work, that's five days logged in a row"
//                     — praise for logging, and a streak. A gap in logging may
//                       be pregnancy, loss, illness, or simply not wanting to
//                       think about it (PLAN 2.4.1), and a streak turns every
//                       one of those into a broken score.
//
// Five guards. The vocabulary lists run over the whole ARB, for the reason
// `movement_copy_test.dart` gives — a euphemism is wrong on any screen, not
// only this one. The three absolutes are scoped to `companion*`, where they
// can be absolute:
//
//   * **No digit.** A number here is a streak, a count of days, or a score.
//     There is no fourth kind of number this thing could want.
//   * **No second person, at all.** Not "your cramps", not "how you are
//     feeling". This is the guard that makes "it must never imply it knows how
//     the user feels" mechanical rather than a matter of taste: it knows what
//     was logged, and a sentence that addresses the reader is one edit from
//     claiming more.
//   * **No exclamation mark and no emoji.** Charm is the job of the drawing
//     and the motion. The words do not get to be excited.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cutesy euphemism, banned wherever it appears in the app.
///
/// PLAN 6.3 asks for plain language — "period", "bleeding", "cramps" — and
/// every entry here is a way of not saying one of them.
const List<String> _euphemism = <String>[
  'time of the month',
  'that time of',
  'shark week',
  'aunt flo',
  'auntie flo',
  'lady time',
  'lady days',
  'monthly visitor',
  'monthly friend',
  'on the rag',
  'moon time',
  'moon cycle',
  'red wave',
  'crimson',
  "women's troubles",
  'down there',
  'special time',
  'girl problems',
];

/// Forced positivity, banned wherever it appears in the app.
///
/// Not a tone preference. Telling somebody to look on the bright side is a
/// claim about how their day is going, made by software that knows only which
/// boxes were ticked.
const List<String> _forcedPositivity = <String>[
  'cheer up',
  'stay positive',
  'bright side',
  'chin up',
  'you got this',
  "you've got this",
  'be kind to yourself',
  'treat yourself',
  'you deserve',
  'stay strong',
  'hang in there',
  'it will pass',
  'everything will be',
  'look on the',
  'self-care',
  'self care',
];

/// Praise for logging, banned wherever it appears in the app.
///
/// Including the streak vocabulary, which is the same mistake with arithmetic
/// attached.
const List<String> _praise = <String>[
  'well done',
  'good job',
  'nice work',
  'great work',
  'keep it up',
  'keep going',
  'streak',
  'proud of you',
  'doing great',
  'doing well',
  'thanks for logging',
  'way to go',
  'congrat',
];

/// Claims about how the reader feels, banned wherever they appear in the app.
///
/// The companion knows what was logged. That is not the same as knowing how
/// anybody feels, and each of these closes the gap without any new information.
const List<String> _mindReading = <String>[
  'i know how',
  'you must be',
  'you probably',
  'you seem',
  'you might be feeling',
  'feeling rough',
  'how you feel',
  'how are you feeling',
  'sounds like',
];

/// Guesses at pregnancy, loss or sexual activity, banned everywhere.
///
/// PLAN 6.3 is explicit, and the companion is the surface most likely to break
/// it: a late period plus a friendly voice is how an app ends up asking. The
/// recorded forms stay writable — the app already has a pregnancy *condition*
/// the user enters themselves — so only the speculation is banned.
const List<String> _speculation = <String>[
  'you may be pregnant',
  'might be pregnant',
  'could be pregnant',
  'are you pregnant',
  'take a pregnancy test',
  'miscarriage',
  'chance of pregnancy',
  'trying to conceive',
  'had sex',
  'sexually active',
];

/// Second person, in any spelling, as whole words.
final RegExp _secondPerson = RegExp(
  r"\b(you|your|yours|yourself|you're|youre)\b",
);

/// Any digit.
final RegExp _digit = RegExp(r'\d');

/// An exclamation mark, or anything outside the Latin text this app is written
/// in — which in practice means an emoji.
final RegExp _excitement = RegExp(
  r'[!\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
);

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

Map<String, String> _companionCopy() => <String, String>{
  for (final entry in _copy().entries)
    if (entry.key.startsWith('companion')) entry.key: entry.value,
};

List<String> _offences(Map<String, String> copy, List<String> banned) {
  final found = <String>[];
  copy.forEach((key, value) {
    final text = value.toLowerCase();
    for (final phrase in banned) {
      if (text.contains(phrase)) found.add('$key: "$phrase"');
    }
  });
  return found;
}

void main() {
  test('the companion exists to be checked', () {
    // Every guard below is a scan over a set, and an empty set passes all of
    // them. The set is asserted first.
    expect(
      _companionCopy(),
      isNotEmpty,
      reason:
          'no companion* strings in the ARB. If the feature was renamed, '
          'rename the guards with it rather than leaving them scanning '
          'nothing.',
    );
  });

  // Applied to the whole ARB rather than only the companion keys. 6.3 is a rule
  // about the app: a euphemism is wrong on the calendar too, and a guard scoped
  // to one feature is a guard that misses the day somebody moves the sentence.
  group('nothing anywhere in the app', () {
    test('reaches for a euphemism instead of the word', () {
      final offences = _offences(_copy(), _euphemism);
      expect(
        offences,
        isEmpty,
        reason:
            'PLAN 6.3 asks for plain language: "period", "bleeding", "cramps". '
            'Every one of these is a way of not saying one of '
            'them.\n${offences.join("\n")}',
      );
    });

    test('tells anyone to cheer up', () {
      final offences = _offences(_copy(), _forcedPositivity);
      expect(
        offences,
        isEmpty,
        reason:
            "Forced positivity is a claim about how somebody's day is going, "
            'made by software that knows which boxes were '
            'ticked.\n${offences.join("\n")}',
      );
    });

    test('congratulates anyone for logging', () {
      final offences = _offences(_copy(), _praise);
      expect(
        offences,
        isEmpty,
        reason:
            'Logging is not an achievement and a gap is not a failure. A '
            'streak turns pregnancy, loss, illness and not wanting to think '
            'about it into a broken score.\n${offences.join("\n")}',
      );
    });

    test('claims to know how the reader feels', () {
      final offences = _offences(_copy(), _mindReading);
      expect(
        offences,
        isEmpty,
        reason:
            'This app knows what was logged. Nothing in it may write a '
            'sentence that only makes sense if it knew more than '
            'that.\n${offences.join("\n")}',
      );
    });

    test('guesses at pregnancy, loss or sex', () {
      final offences = _offences(_copy(), _speculation);
      expect(
        offences,
        isEmpty,
        reason:
            'PLAN 6.3 forbids this outright. A missed period has many causes '
            "and none of them are the app's to raise."
            '\n${offences.join("\n")}',
      );
    });
  });

  group('the companion itself', () {
    test('never addresses the reader', () {
      final offences = <String>[];
      _companionCopy().forEach((key, value) {
        final match = _secondPerson.firstMatch(value.toLowerCase());
        if (match != null) offences.add('$key: "${match[0]}" — "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'A sentence from a character that addresses the reader is one edit '
            'from claiming to know something about them. Every line here is '
            'about what was logged, about what guidance says, or about what '
            'this app is doing — none of which needs a "you".\n'
            '${offences.join("\n")}',
      );
    });

    test('contains no number of any kind', () {
      final offences = <String>[];
      _companionCopy().forEach((key, value) {
        if (_digit.hasMatch(value)) offences.add('$key: "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'A figure here is a streak, a count of days, or a score. "A few '
            'days" is the honest form and it needs no digit.\n'
            '${offences.join("\n")}',
      );
    });

    test('is never excited', () {
      final offences = <String>[];
      _companionCopy().forEach((key, value) {
        if (_excitement.hasMatch(value)) offences.add('$key: "$value"');
      });
      expect(
        offences,
        isEmpty,
        reason:
            'An exclamation mark or an emoji. Warm is allowed and chirpy is '
            'not; the charm of this feature is the drawing and the motion, and '
            'the words stay level.\n${offences.join("\n")}',
      );
    });

    test('says cramps, and period, in those words', () {
      final copy = _companionCopy();
      expect(
        copy['companionLineCramps']!.toLowerCase(),
        contains('cramps'),
        reason: 'the cramps line no longer says cramps',
      );
      expect(
        copy.values.any((line) => line.toLowerCase().contains('period')),
        isTrue,
        reason: 'nothing the companion says uses the word "period" any more',
      );
    });

    test('mentions a pregnancy only as something already recorded', () {
      // The one line that may name it does so because the user entered it on
      // the conditions screen. Anything else is an inference.
      _companionCopy().forEach((key, value) {
        final text = value.toLowerCase();
        if (!text.contains('pregnan')) return;
        expect(
          text,
          contains('recorded'),
          reason:
              '$key names a pregnancy without saying it was recorded, which '
              'makes it a guess: "$value"',
        );
      });
    });

    test('treats a passed window as a data state and stops there', () {
      final line = _companionCopy()['companionLineOverdue']!.toLowerCase();
      expect(
        line,
        contains('data state'),
        reason:
            'the overdue line no longer says outright that this is a data '
            'state, which is the sentence that stops it being a comment on '
            "somebody's life",
      );
      for (final speculation in <String>[
        'late',
        'missed',
        'delayed',
        'worry',
        'worried',
      ]) {
        expect(
          line,
          isNot(contains(speculation)),
          reason: 'the overdue line has started interpreting: "$speculation"',
        );
      }
    });

    test('says what it is, and what it is not, wherever it speaks', () {
      final blurb = _companionCopy()['companionHowItWorks']!.toLowerCase();
      expect(
        blurb.contains('fixed set') || blurb.contains('finite'),
        isTrue,
        reason:
            'the blurb no longer says the lines are a fixed set, which is the '
            'one thing a reader needs in order not to mistake this for a model',
      );
      expect(
        blurb,
        contains('logged'),
        reason: 'the blurb no longer says it reads what was logged',
      );
      expect(
        blurb,
        contains('feels'),
        reason:
            'the blurb no longer says that reading a log is not the same as '
            'knowing how anyone feels, which is the distinction this whole '
            'feature is at risk of losing',
      );
    });

    test('the guards above would actually catch one', () {
      // A check that cannot fail is not a check. These pin the detectors.
      expect(_secondPerson.hasMatch('how are your cramps'), isTrue);
      expect(_secondPerson.hasMatch('a young person'), isFalse);
      expect(_digit.hasMatch('3 days logged in a row'), isTrue);
      expect(_digit.hasMatch('nothing for a few days'), isFalse);
      expect(_excitement.hasMatch('nice one!'), isTrue);
      expect(_excitement.hasMatch('a level sentence.'), isFalse);
      expect(
        _offences(<String, String>{'k': 'Shark week again'}, _euphemism),
        <String>['k: "shark week"'],
      );
      expect(
        _offences(<String, String>{'k': 'Look on the bright side'}, _praise),
        isEmpty,
      );
      expect(
        _offences(
          <String, String>{'k': 'Look on the bright side'},
          _forcedPositivity,
        ),
        isNotEmpty,
      );
      expect(
        _offences(<String, String>{'k': 'Well done, five in a row'}, _praise),
        <String>['k: "well done"'],
      );
      expect(
        _offences(<String, String>{'k': 'You may be pregnant'}, _speculation),
        <String>['k: "you may be pregnant"'],
      );
      expect(
        _offences(<String, String>{
          'k': 'A pregnancy is recorded',
        }, _speculation),
        isEmpty,
      );
    });
  });
}
