// Curated hygiene copy is reference text, not a diagnosis (AND-32, PLAN 6.2).
//
// The TSS entry is the hardest piece of copy in this app to get right, because
// it has to be urgent without being a diagnosis. The line it walks:
//
//   "If you have a sudden high fever ... remove it and get urgent medical
//    help."   — a description of symptoms and an instruction. Correct.
//   "You have toxic shock syndrome."
//                — a diagnosis of a person, which nothing in this app can
//                  support, and which would be wrong far more often than right.
//
// The second is not a hypothetical. It is shorter, it feels more decisive, and
// it is what a well-meaning edit produces when asked to make the warning
// stronger. So the wording is pinned and the vocabulary is a build failure.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/hygiene.dart';

Map<String, String> _copy() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') &&
          entry.key.startsWith('hygiene') &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

void main() {
  group('the TSS warning', () {
    test('is pinned word for word', () {
      // Every clause is doing work: which symptoms, in what circumstance, and
      // the two actions in the order they should happen. If this needs to
      // change, change it deliberately and update the pin.
      expect(
        _copy()['hygieneTssUrgent'],
        'If you have a sudden high fever, a sunburn-like rash, vomiting, '
        'diarrhoea, muscle aches, dizziness or confusion while using a tampon '
        'or a menstrual cup: remove it and get urgent medical help.',
      );
    });

    test('describes symptoms rather than naming a condition', () {
      final warning = _copy()['hygieneTssUrgent']!.toLowerCase();
      for (final diagnosis in <String>[
        'you have toxic',
        'you may have toxic',
        'this is toxic shock',
        'you are in shock',
      ]) {
        expect(
          warning,
          isNot(contains(diagnosis)),
          reason: 'the warning diagnoses rather than describes: "$diagnosis"',
        );
      }
    });

    test('says what to do, and says it urgently', () {
      // Two actions, in order: remove it, then get help. A warning that only
      // said "see a doctor" would leave the thing still in.
      final warning = _copy()['hygieneTssUrgent']!.toLowerCase();
      expect(warning, contains('remove it'));
      expect(warning, contains('urgent'));
      expect(
        warning.indexOf('remove it'),
        lessThan(warning.indexOf('help')),
        reason: 'the instruction to get help comes before removing it',
      );
    });

    test('is not softened into a suggestion', () {
      // "You might want to consider speaking to someone" is how an urgent
      // instruction dies. Hedges are what turn it into one.
      final warning = _copy()['hygieneTssUrgent']!.toLowerCase();
      for (final hedge in <String>[
        'might want',
        'you may wish',
        'consider ',
        'it could be worth',
        'perhaps',
      ]) {
        expect(
          warning,
          isNot(contains(hedge)),
          reason: 'the urgent warning has been hedged with "$hedge"',
        );
      }
    });
  });

  group('the curated copy generally', () {
    test('never tells the reader what they have', () {
      final offences = <String>[];
      _copy().forEach((key, value) {
        final text = value.toLowerCase();
        for (final phrase in <String>[
          'you have toxic',
          'you are suffering',
          'diagnos',
          'you should use',
          'we recommend',
        ]) {
          if (text.contains(phrase)) offences.add('$key: "$phrase"');
        }
      });
      expect(
        offences,
        isEmpty,
        reason:
            'Curated reference text may describe products and symptoms. It may '
            'not diagnose the reader or recommend a product — this app has no '
            'basis for either.\n${offences.join("\n")}',
      );
    });

    test('points at the packet rather than inventing a number', () {
      // Wear times and cleaning instructions genuinely differ between
      // products. A single figure here would be wrong for somebody, and it
      // would be wrong with the app's authority behind it.
      final cups = _copy()['hygieneCupsBody']!.toLowerCase();
      expect(
        cups,
        contains('instructions that came with yours'),
        reason: 'the cup entry no longer defers to the product instructions',
      );
      expect(
        RegExp(r'\b\d+\s*(hours?|hrs?)\b').hasMatch(cups),
        isFalse,
        reason: 'the cup entry states a wear time, which differs by product',
      );
    });

    test('every entry has both a title and a body', () {
      // A switch with a missing arm would not compile, but an ARB key that was
      // never added renders as an empty card.
      final copy = _copy();
      for (final entry in bundledHygieneEntries) {
        final stem = entry.key[0].toUpperCase() + entry.key.substring(1);
        expect(
          copy['hygiene${stem}Title']?.trim(),
          isNotEmpty,
          reason: '${entry.key} has no title',
        );
        expect(
          copy['hygiene${stem}Body']?.trim(),
          isNotEmpty,
          reason: '${entry.key} has no body',
        );
      }
    });

    test('exactly one entry is marked urgent', () {
      // The urgent styling works by being rare. A page where several things
      // shout is a page where nothing does.
      expect(
        bundledHygieneEntries.where(
          (e) => e.urgency == HygieneUrgency.urgent,
        ),
        hasLength(1),
      );
    });
  });
}
