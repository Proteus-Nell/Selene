// Every word the companion can ever say, in one place (AND-37).
//
// This is the file a reviewer reads to find out what this feature is. The
// companion has no network permission, no model on the device and no way to
// assemble a sentence: it looks at the user's own state, walks an ordered list
// of conditions, and returns one member of a closed enum. So the complete set
// of things it can utter is a finite list, and the list is below, written out
// in full rather than derived from the ARB.
//
// Two guards make that claim hold rather than merely state it:
//
//   * the rule set is walked over every combination of its inputs, and the
//     lines that fall out have to be exactly `CompanionLine.values` — no
//     unreachable line, and none missing;
//   * the sentence each line resolves to has to be exactly the one written
//     here. Adding a fourteenth thing this thing can say fails this file until
//     somebody types the sentence into it, which is the point: a line cannot
//     arrive without being read.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';
import 'package:period_tracker/features/companion/companion_rules.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Everything the companion can say, and nothing else.
///
/// Read it as prose. If any sentence here would be wrong to show to somebody
/// having a bad month, it is wrong, and the fix is in `app_en.arb` rather than
/// in this map.
const Map<CompanionLine, String> everythingItCanSay = <CompanionLine, String>{
  CompanionLine.stillReading: 'The log is still being read.',
  CompanionLine.predictionPaused:
      'A pregnancy is recorded, so predictions are paused. Days can still be '
      'logged.',
  CompanionLine.heavyBleeding:
      'Heavy bleeding is recorded on several days. Heavy menstrual bleeding is '
      'a recognised cause of iron deficiency anaemia, which a blood test '
      'settles rather than symptoms.',
  CompanionLine.cramps:
      'Cramps are recorded for today. Guidance on period pain lists heat, '
      'painkillers and exercise among the measures that may help.',
  CompanionLine.sleep:
      'Disturbed sleep is recorded for today. Sleep problems are among the '
      'symptoms commonly reported around a period.',
  CompanionLine.lowEnergy:
      'Low energy is recorded for today. Tiredness is among the symptoms '
      'commonly reported before and during a period.',
  CompanionLine.periodToday:
      'A period is logged for today. Menstruation is not named anywhere in the '
      'guidance behind this app as a reason to stop moving.',
  CompanionLine.overdue:
      'The predicted window has passed with no period logged. That is a data '
      'state, and nothing here guesses at what is behind it.',
  CompanionLine.nothingLoggedRecently:
      'Nothing has been logged for a few days. The log is on the first tab, '
      'whenever there is something to put in it.',
  CompanionLine.noLogsYet:
      'Nothing is recorded yet. One period start date is enough to begin.',
  CompanionLine.noPredictionYet:
      'There is not enough history for a prediction yet. Insights holds what '
      'has been recorded so far.',
  CompanionLine.todayLogged:
      'Today is already logged. The day can be opened again and changed.',
  CompanionLine.nothingToPointAt: 'Nothing to point at just now.',
};

/// Which lines make a claim about bodies, and therefore need a source.
///
/// Named here as well as on the enum so that flipping one to false — the
/// cheapest possible way to make `companion_sources_test.dart` stop asking for
/// a citation — fails loudly instead of quietly.
const Set<CompanionLine> claimBearing = <CompanionLine>{
  CompanionLine.heavyBleeding,
  CompanionLine.cramps,
  CompanionLine.sleep,
  CompanionLine.lowEnergy,
  CompanionLine.periodToday,
};

/// Every state the rules can be asked about.
///
/// A cartesian product rather than a hand-picked set of cases. Hand-picked
/// cases test the branches somebody thought of; the product tests the ones they
/// did not, which is where an unreachable line or a line that can never be
/// escaped from would hide.
Iterable<CompanionState> everyState() sync* {
  const phases = <CyclePhase?>[
    null,
    CyclePhase.period,
    CyclePhase.follicular,
    CyclePhase.luteal,
  ];
  const symptomSets = <Set<Symptom>>[
    <Symptom>{},
    <Symptom>{Symptom.cramps},
    <Symptom>{Symptom.sleep},
    <Symptom>{Symptom.energy},
    <Symptom>{Symptom.mood, Symptom.bloating},
    <Symptom>{Symptom.cramps, Symptom.sleep, Symptom.energy},
  ];
  const silences = <int?>[null, 0, 1, 3, 4, 30];

  for (final ready in <bool>[true, false]) {
    for (final paused in <bool>[true, false]) {
      for (final heavy in <bool>[true, false]) {
        for (final hasPrediction in <bool>[true, false]) {
          for (final overdue in <bool>[true, false]) {
            for (final loggedToday in <bool>[true, false]) {
              for (final phase in phases) {
                for (final symptoms in symptomSets) {
                  for (final silence in silences) {
                    yield CompanionState(
                      ready: ready,
                      phase: phase,
                      predictionPaused: paused,
                      hasPrediction: hasPrediction,
                      periodOverdue: overdue,
                      daysSinceLastLog: silence,
                      loggedToday: loggedToday,
                      symptomsToday: symptoms,
                      heavyBleedingRecently: heavy,
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the whole vocabulary', () {
    test('is exactly what is written out in this file', () {
      // The assertion the rest of this feature rests on. Every sentence the
      // companion is capable of producing is above, and if the two ever
      // disagree this fails with both versions printed.
      final said = <CompanionLine, String>{
        for (final line in CompanionLine.values) line: line.text(l10n),
      };
      expect(
        said,
        everythingItCanSay,
        reason:
            'The companion can say something that is not written out in this '
            'file, or can no longer say something that is. Either way somebody '
            'has to read the new wording: put it in the map above.',
      );
    });

    test('has no duplicated and no empty sentence', () {
      final sentences = everythingItCanSay.values.toList();
      expect(sentences.toSet(), hasLength(sentences.length));
      for (final sentence in sentences) {
        expect(sentence.trim(), isNotEmpty);
      }
    });

    test('is the size the enum says it is', () {
      expect(everythingItCanSay, hasLength(CompanionLine.values.length));
    });
  });

  group('walking the rules over every state it can be in', () {
    test('reaches every line, and produces nothing else', () {
      final produced = <CompanionLine>{
        for (final state in everyState()) CompanionRules.select(state),
      };
      expect(
        produced,
        CompanionLine.values.toSet(),
        reason:
            'Either a line can never be reached — dead copy nobody will ever '
            'see, which is worse than no copy — or a state produces something '
            'not in the enum, which cannot happen and means this test is '
            'lying.',
      );
    });

    test('answers the same state the same way, every time', () {
      // There is no randomness here and there must never be. A companion that
      // varied its answer would be a companion whose utterances could not be
      // enumerated, which is this whole file.
      for (final state in everyState()) {
        expect(CompanionRules.select(state), CompanionRules.select(state));
      }
    });
  });

  group('the order the rules run in', () {
    const base = CompanionState(daysSinceLastLog: 0, loggedToday: true);

    test('says nothing at all until the data has been read', () {
      expect(
        CompanionRules.select(const CompanionState.notReady()),
        CompanionLine.stillReading,
      );
    });

    test('explains a paused prediction before mentioning anything else', () {
      // Somebody who has recorded a pregnancy must not be shown a note about
      // menstrual iron loss above the explanation of why their predictions
      // stopped.
      final state = CompanionState(
        predictionPaused: true,
        heavyBleedingRecently: true,
        phase: CyclePhase.period,
        symptomsToday: const <Symptom>{Symptom.cramps},
        daysSinceLastLog: base.daysSinceLastLog,
      );
      expect(CompanionRules.select(state), CompanionLine.predictionPaused);
    });

    test('answers what was logged today before what was predicted', () {
      // A symptom recorded an hour ago is a better thing to speak to than a
      // window that closed yesterday.
      const state = CompanionState(
        symptomsToday: <Symptom>{Symptom.cramps},
        periodOverdue: true,
        daysSinceLastLog: 0,
        loggedToday: true,
      );
      expect(CompanionRules.select(state), CompanionLine.cramps);
    });

    test('treats a passed window as a data state and nothing more', () {
      const state = CompanionState(
        hasPrediction: true,
        periodOverdue: true,
        daysSinceLastLog: 1,
      );
      expect(CompanionRules.select(state), CompanionLine.overdue);
      // PLAN 6.3: a missed period is a data state, not a life event. The line
      // for it must say only that, and nothing downstream may branch on it.
      expect(
        everythingItCanSay[CompanionLine.overdue]!.toLowerCase(),
        contains('data state'),
      );
    });

    test('offers the log after a silence, without asking why', () {
      const state = CompanionState(
        hasPrediction: true,
        daysSinceLastLog: CompanionState.quietDays,
      );
      expect(CompanionRules.select(state), CompanionLine.nothingLoggedRecently);
    });

    test('falls through to nothing rather than inventing something', () {
      const state = CompanionState(hasPrediction: true, daysSinceLastLog: 1);
      expect(CompanionRules.select(state), CompanionLine.nothingToPointAt);
    });
  });

  group('the health-claim split', () {
    test('is what the enum says it is', () {
      expect(
        CompanionLine.values.where((l) => l.carriesHealthClaim).toSet(),
        claimBearing,
        reason:
            'A line changed sides. Turning a claim-bearing line into a '
            'claim-free one is the cheapest way to make the sources guard stop '
            'asking for a citation, so it fails here first.',
      );
    });

    test('leaves the offers and the data statements uncited, deliberately', () {
      // "Nothing has been logged for a few days" claims nothing about anybody's
      // body. Citing it would be noise; not recording *why* it is uncited is
      // how an omission gets mistaken for an oversight, which is what
      // docs/COMPANION_SOURCES.md exists to prevent.
      for (final line in <CompanionLine>[
        CompanionLine.nothingLoggedRecently,
        CompanionLine.noLogsYet,
        CompanionLine.noPredictionYet,
        CompanionLine.todayLogged,
        CompanionLine.nothingToPointAt,
        CompanionLine.overdue,
        CompanionLine.predictionPaused,
        CompanionLine.stillReading,
      ]) {
        expect(line.carriesHealthClaim, isFalse);
      }
    });
  });
}
