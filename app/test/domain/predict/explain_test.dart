import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/explain.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

PredictionExplanation explain(List<int> lengths) => Explain.forPrediction(
  prediction: Intervals.forHistory(lengths, bundledPriors),
  cycleLengths: lengths,
  priors: bundledPriors,
);

/// Every history the copy rules are checked against.
const List<List<int>> histories = <List<int>>[
  <int>[],
  <int>[28],
  <int>[28, 30],
  <int>[28, 28, 28, 28],
  <int>[27, 29, 28, 30, 28, 29],
  <int>[28, 29, 28, 55, 28, 29],
  <int>[28, 29, 90, 28],
  <int>[24, 35, 28, 42, 31, 26],
  <int>[15, 15, 16, 15],
];

void main() {
  group('every explanation', () {
    test('states a range, never a bare number', () {
      // The single most important product rule in the app: a bare predicted
      // date implies a precision the model does not have (docs/PLAN.md 6.2).
      for (final history in histories) {
        final explanation = explain(history);
        final prediction = Intervals.forHistory(history, bundledPriors);
        if (prediction.confidence == ConfidenceClass.tooIrregular) {
          expect(
            explanation.headline,
            isNot(contains('${prediction.windows.medianDays} days')),
            reason: '$history must not headline a median it will not show',
          );
        } else {
          expect(
            explanation.headline,
            contains('day ${prediction.windows.lo80}'),
            reason: '$history',
          );
          expect(
            explanation.headline,
            contains('day ${prediction.windows.hi80}'),
          );
        }
      }
    });

    test('says what it was based on and how uncertain it is', () {
      for (final history in histories) {
        final explanation = explain(history);
        expect(explanation.basis, isNotEmpty, reason: '$history');
        expect(explanation.uncertainty, isNotEmpty, reason: '$history');
        expect(explanation.lines.length, greaterThanOrEqualTo(3));
        expect(explanation.text, contains(explanation.headline));
        expect(explanation.notes, isNotEmpty);
      }
    });

    test('never strays into medical territory', () {
      // Not a style preference. Overclaiming is the main way this class of app
      // causes harm, and the pregnancy inference in particular is the one the
      // ethics review singles out (docs/PLAN.md 6.2).
      const forbidden = <String>[
        'pregnan',
        'fertil',
        'ovulat',
        'diagnos',
        'symptom of',
        'you should see',
      ];
      for (final history in histories) {
        final text = explain(history).text.toLowerCase();
        for (final word in forbidden) {
          expect(text, isNot(contains(word)), reason: '$history said "$word"');
        }
      }
    });

    test('describes the cycles, never the person', () {
      for (final history in histories) {
        final text = explain(history).text.toLowerCase();
        expect(text, isNot(contains('you are irregular')));
        expect(text, isNot(contains('abnormal')));
        expect(text, isNot(contains('you have irregular')));
      }
    });

    test('prints its whole text for a failing expectation', () {
      final explanation = explain(const [28, 30]);
      expect(explanation.toString(), contains(explanation.headline));
      expect(explanation.toString(), startsWith('PredictionExplanation('));
    });

    test('reads as sentences', () {
      for (final history in histories) {
        for (final line in explain(history).lines) {
          expect(line.trim(), line, reason: 'stray whitespace in "$line"');
          expect(line, endsWith('.'), reason: '"$line"');
          expect(line, isNot(contains('  ')), reason: '"$line"');
        }
      }
    });
  });

  group('a brand new user', () {
    test('is told the prediction is not about them yet', () {
      final explanation = explain(const []);
      expect(explanation.notes, contains(ExplanationNote.populationPriorOnly));
      expect(explanation.basis, contains('typical cycle lengths'));
      expect(explanation.uncertainty, contains('almost no history'));
      expect(explanation.cautions, isEmpty);
    });
  });

  group('a user below the personalisation threshold', () {
    test('is told the model has not tuned to them yet', () {
      final explanation = explain(const [28, 30, 29]);
      expect(explanation.notes, contains(ExplanationNote.notYetPersonalised));
      expect(explanation.notes, isNot(contains(ExplanationNote.personalised)));
      expect(explanation.basis, contains('3 cycles'));
      expect(
        explanation.basis,
        contains('${bundledPriors.personalisation.minCycles} cycles'),
      );
    });

    test('counts one cycle in the singular', () {
      expect(explain(const [28]).basis, contains('1 cycle you have logged'));
    });
  });

  group('a settled user', () {
    test('is told the model is using their own variability', () {
      final explanation = explain(const [27, 29, 28, 30, 28, 29]);
      expect(explanation.notes, contains(ExplanationNote.personalised));
      expect(explanation.basis, contains('6 cycles'));
      expect(explanation.uncertainty, contains('about half the time'));
      expect(explanation.cautions, isEmpty);
    });

    test('says so plainly when the cycles are all but identical', () {
      expect(
        explain(List<int>.filled(6, 28)).uncertainty,
        contains('almost the same length'),
      );
    });
  });

  group('an unusual recent cycle', () {
    test('is flagged, with the mundane explanation offered first', () {
      // A 90 day observation is nearly always a start date that never got
      // logged, and saying so is more useful than any other reading of it.
      final explanation = explain(const [28, 29, 90, 28]);
      expect(explanation.notes, contains(ExplanationNote.unusualRecentCycle));
      expect(explanation.cautions, hasLength(1));
      expect(explanation.cautions.single, contains('90 days'));
      expect(explanation.cautions.single, contains('longer'));
      expect(explanation.cautions.single, contains('never got logged'));
    });

    test('is not flagged on a history that is merely variable', () {
      expect(
        explain(const [27, 29, 28, 30, 28, 29]).notes,
        isNot(contains(ExplanationNote.unusualRecentCycle)),
      );
      expect(
        explain(const [24, 35, 28, 42, 31, 26]).notes,
        isNot(contains(ExplanationNote.unusualRecentCycle)),
      );
    });

    test(
      'is not flagged before there is a baseline to be surprised against',
      () {
        // A first logged cycle of 40 days is far from the population prior and
        // is not remotely unusual for the person logging it.
        expect(
          explain(const [40]).notes,
          isNot(contains(ExplanationNote.unusualRecentCycle)),
        );
        expect(
          explain(const [40, 41]).notes,
          isNot(contains(ExplanationNote.unusualRecentCycle)),
        );
      },
    );

    test('goes quiet again once it is no longer recent', () {
      final recent = explain(const [28, 29, 28, 55]);
      final old = explain(const [28, 29, 28, 55, 28, 29, 28, 29]);
      expect(recent.notes, contains(ExplanationNote.unusualRecentCycle));
      expect(old.notes, isNot(contains(ExplanationNote.unusualRecentCycle)));
    });
  });

  group('a user whose cycles cannot be predicted narrowly', () {
    test('is given their own statistics instead of a dead end', () {
      // Risk R17: this state must never be "we cannot help you".
      final explanation = explain(const [24, 35, 28, 42, 31, 26]);
      expect(explanation.notes, contains(ExplanationNote.tooIrregular));
      expect(explanation.headline, contains('vary too much'));
      expect(explanation.headline, contains('your own range'));
      expect(explanation.uncertainty, contains('varied by about'));
      expect(explanation.uncertainty, contains('typical'));
    });
  });

  group('standardisedResiduals', () {
    test('scores each cycle against only the cycles before it', () {
      final residuals = Explain.standardisedResiduals(
        const [28, 29, 28, 55],
        bundledPriors.filterPriors,
      );
      expect(residuals, hasLength(4));
      // The 55 is the surprising one; the settled 28s are not.
      expect(residuals.last.abs(), greaterThan(3));
      expect(residuals[2].abs(), lessThan(1));
    });

    test('is empty for an empty history', () {
      expect(
        Explain.standardisedResiduals(const [], bundledPriors.filterPriors),
        isEmpty,
      );
    });
  });
}
