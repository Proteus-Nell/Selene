import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/personalize.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

final FilterPriors priors = bundledPriors.filterPriors;
final Personalisation config = bundledPriors.personalisation;

RefitResult refit(List<int> lengths, [Personalisation? c]) =>
    Personalize.refitUser(lengths, priors, c ?? config);

/// Width of the 80% window after [n] cycles of the given repeating pattern.
int width80After(List<int> pattern, int n) {
  final history = <int>[
    for (var i = 0; i < n; i++) pattern[i % pattern.length],
  ];
  return Intervals.forHistory(history, bundledPriors).windows.width80;
}

void main() {
  group('below the minimum history', () {
    test('keeps the population values and says so', () {
      for (var n = 0; n < config.minCycles; n++) {
        final result = refit(List<int>.filled(n, 28));
        expect(result.personalised, isFalse, reason: '$n cycles');
        expect(result.priors, priors, reason: '$n cycles');
        expect(result.nCycles, n);
        expect(result.obsSd, math.sqrt(priors.obsVar));
        expect(result.driftSd, math.sqrt(priors.driftVar));
        expect(result.score, double.negativeInfinity);
      }
    });

    test('runs as soon as the minimum is reached', () {
      final result = refit(List<int>.filled(config.minCycles, 28));
      expect(result.personalised, isTrue);
      expect(result.score.isFinite, isTrue);
    });
  });

  group('the selected point', () {
    test('always comes from the shipped grid', () {
      for (final history in <List<int>>[
        List<int>.filled(6, 28),
        <int>[27, 29, 28, 30, 28, 29],
        <int>[24, 35, 28, 42, 31, 26],
        <int>[28, 29, 90, 28, 27, 30],
      ]) {
        final result = refit(history);
        expect(config.obsSdGrid, contains(result.obsSd));
        expect(config.driftSdGrid, contains(result.driftSd));
        expect(
          result.priors.obsVar,
          closeTo(result.obsSd * result.obsSd, 1e-15),
        );
        expect(
          result.priors.driftVar,
          closeTo(result.driftSd * result.driftSd, 1e-15),
        );
      }
    });

    test('tracks how variable the user actually is', () {
      // The point of the refit: two users with the same mean and very
      // different spread must not come out with the same interval width.
      final regular = refit(List<int>.filled(8, 28));
      final irregular = refit(const [26, 34, 26, 34, 26, 34, 26, 34]);
      expect(regular.obsSd, lessThan(irregular.obsSd));
      expect(regular.obsSd, config.obsSdGrid.first);
    });

    test('does not collapse to the tightest grid point on variable data', () {
      // The likelihood is one-step-ahead, so every term is out of sample. An
      // in-sample fit would drive both variances to the smallest candidate for
      // any history at all, which is the failure this guards.
      final irregular = refit(const [24, 35, 28, 42, 31, 26]);
      expect(irregular.obsSd, greaterThan(config.obsSdGrid.first));
    });

    test('resolves ties to the first candidate', () {
      // Strictly-greater comparison, checked with a grid that contains the
      // same value twice: whichever runtime evaluates them, the first must
      // win. On a tie the two implementations would otherwise be free to
      // disagree, and the disagreement would only show up on some users.
      final duplicated = Personalisation(
        minCycles: config.minCycles,
        obsSdGrid: const <double>[0.05, 0.05],
        driftSdGrid: const <double>[0.01, 0.01],
      );
      final result = refit(List<int>.filled(6, 28), duplicated);
      expect(result.obsSd, 0.05);
      expect(result.driftSd, 0.01);
      // Identical candidates score identically, so the assertion above only
      // means anything if the scores really are equal.
      expect(
        Personalize.partialLogLikelihood(
          List<int>.filled(6, 28),
          priors.withVariances(obsVar: 0.0025, driftVar: 0.0001),
        ),
        result.score,
      );
    });
  });

  group('partialLogLikelihood', () {
    test('scores an empty history as zero, with nothing to explain', () {
      expect(Personalize.partialLogLikelihood(const [], priors), 0);
    });

    test('prefers the variance that matches the data', () {
      const history = <int>[26, 34, 26, 34, 26, 34];
      final tight = Personalize.partialLogLikelihood(
        history,
        priors.withVariances(obsVar: 0.0004, driftVar: 0.000016),
      );
      final loose = Personalize.partialLogLikelihood(
        history,
        priors.withVariances(obsVar: 0.018225, driftVar: 0.000016),
      );
      expect(loose, greaterThan(tight));
    });

    test('prefers the tight variance when the data really is tight', () {
      // The mirror of the test above, and the pair is what makes the search
      // meaningful: neither candidate wins everywhere.
      final history = List<int>.filled(6, 28);
      final tight = Personalize.partialLogLikelihood(
        history,
        priors.withVariances(obsVar: 0.0004, driftVar: 0.000016),
      );
      final loose = Personalize.partialLogLikelihood(
        history,
        priors.withVariances(obsVar: 0.018225, driftVar: 0.000016),
      );
      expect(tight, greaterThan(loose));
    });

    test('scores each cycle against only the cycles before it', () {
      // One-step-ahead, so the order of the same six lengths changes the
      // score. A port that scored against the final posterior instead would
      // return the same number for both and would drive every variance to the
      // smallest grid point.
      const alternating = <int>[26, 34, 26, 34, 26, 34];
      const grouped = <int>[26, 26, 26, 34, 34, 34];
      expect(
        Personalize.partialLogLikelihood(alternating, priors),
        isNot(Personalize.partialLogLikelihood(grouped, priors)),
      );
    });
  });

  // The two properties AND-07 names as the acceptance criteria for
  // personalisation. They are opposites on purpose: the same code path has to
  // narrow for one user and widen for the other, and a port that drops the
  // robustness term passes the first and fails the second.
  group(
    'the interval responds to the user, not just to the count of cycles',
    () {
      test(
        'a constant 28 day user collapses onto 28 with a narrowing window',
        () {
          final widths = <int>[
            for (var n = 0; n <= 12; n++) width80After(const [28], n),
          ];
          for (var i = 1; i < widths.length; i++) {
            expect(
              widths[i],
              lessThanOrEqualTo(widths[i - 1]),
              reason: 'window grew between $i-1 and $i cycles: $widths',
            );
          }
          expect(widths.first, greaterThanOrEqualTo(10));
          expect(widths.last, lessThanOrEqualTo(3));

          final settled = Intervals.forHistory(
            List<int>.filled(12, 28),
            bundledPriors,
          );
          expect(settled.windows.medianDays, 28);
          expect(math.exp(settled.state.mean), closeTo(28, 0.01));
          expect(settled.confidence, ConfidenceClass.high);
        },
      );

      test('an alternating 26/34 user makes the window WIDEN', () {
        // Before the refit runs, the window narrows exactly as it would for a
        // regular user: the filter is learning the mean, which is 30 for this
        // user, and knows nothing about the spread. The refit is what notices.
        final beforeRefit = width80After(const [26, 34], config.minCycles - 1);
        final afterRefit = width80After(const [26, 34], config.minCycles);
        expect(
          afterRefit,
          greaterThan(beforeRefit),
          reason:
              'refit must widen the window for a variable user, not narrow it',
        );

        // And it stays wide as more alternating cycles arrive.
        for (var n = config.minCycles; n <= 16; n++) {
          expect(
            width80After(const [26, 34], n),
            greaterThan(beforeRefit),
            reason: 'window narrowed again at $n cycles',
          );
        }

        // Next to a regular user with the same amount of history, the
        // difference is the whole point: 41% coverage for irregular users was
        // what shipping the population variance for everyone actually cost.
        expect(
          width80After(const [26, 34], 8),
          greaterThan(width80After(const [28], 8)),
        );
        expect(
          Intervals.forHistory(const [
            26,
            34,
            26,
            34,
            26,
            34,
          ], bundledPriors).confidence,
          ConfidenceClass.tooIrregular,
        );
      });
    },
  );

  group('RefitResult', () {
    test('compares by value and reports itself readably', () {
      final a = refit(List<int>.filled(6, 28));
      final b = refit(List<int>.filled(6, 28));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(refit(const [26, 34, 26, 34, 26, 34])));
      expect(a.toString(), contains('personalised: true'));
    });
  });
}
