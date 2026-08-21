import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/prediction.dart';

const _basis = PredictionBasis(
  cyclesUsed: 6,
  medianLengthDays: 28.5,
  variabilityDays: 1.8,
);

Prediction _prediction({
  int median = 20,
  int spread50 = 1,
  int spread80 = 3,
  Confidence confidence = Confidence.high,
}) {
  final centre = CivilDate(2026, 9, median);
  return Prediction(
    medianStart: centre,
    window50: CivilDateRange(
      centre.addDays(-spread50),
      centre.addDays(spread50),
    ),
    window80: CivilDateRange(
      centre.addDays(-spread80),
      centre.addDays(spread80),
    ),
    confidence: confidence,
    basis: _basis,
  );
}

void main() {
  group('Prediction always carries its uncertainty', () {
    test('both windows are required, so a bare date is unrepresentable', () {
      // There is no constructor that yields a Prediction without window50 and
      // window80. The product rule "never show a bare predicted date" is
      // enforced by the type rather than by review. See PLAN.md 6.2.
      final p = _prediction();
      expect(p.window50, isNotNull);
      expect(p.window80, isNotNull);
      expect(p.uncertaintyDays, 7, reason: '3 either side plus the median day');
    });

    test('the 80% window cannot be narrower than the 50% window', () {
      final centre = CivilDate(2026, 9, 20);
      expect(
        () => Prediction(
          medianStart: centre,
          window50: CivilDateRange(
            centre.addDays(-5),
            centre.addDays(5),
          ),
          window80: CivilDateRange(
            centre.addDays(-1),
            centre.addDays(1),
          ),
          confidence: Confidence.low,
          basis: _basis,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('isCoherent holds for a well-formed prediction', () {
      expect(_prediction().isCoherent, isTrue);
    });

    test('isCoherent fails when the median sits outside the windows', () {
      final centre = CivilDate(2026, 9, 20);
      final skewed = Prediction(
        medianStart: centre.addDays(10),
        window50: CivilDateRange(centre.addDays(-1), centre.addDays(1)),
        window80: CivilDateRange(centre.addDays(-3), centre.addDays(3)),
        confidence: Confidence.low,
        basis: _basis,
      );
      expect(skewed.isCoherent, isFalse);
    });
  });

  group('CycleStatistics', () {
    test('empty reports no history', () {
      expect(CycleStatistics.empty.completedCycles, 0);
      expect(CycleStatistics.empty.hasHistory, isFalse);
      expect(CycleStatistics.empty.observedSpreadDays, isNull);
    });

    test('spread needs at least two cycles', () {
      const one = CycleStatistics(
        completedCycles: 1,
        shortestLengthDays: 28,
        longestLengthDays: 28,
      );
      expect(one.observedSpreadDays, isNull);

      const two = CycleStatistics(
        completedCycles: 2,
        shortestLengthDays: 26,
        longestLengthDays: 34,
      );
      expect(two.observedSpreadDays, 8);
    });

    test('round-trips through JSON', () {
      const stats = CycleStatistics(
        completedCycles: 7,
        medianLengthDays: 28.5,
        medianAbsoluteDeviationDays: 1.5,
        shortestLengthDays: 25,
        longestLengthDays: 33,
      );
      expect(CycleStatistics.fromJson(stats.toJson()), stats);
      expect(
        CycleStatistics.fromJson(CycleStatistics.empty.toJson()),
        CycleStatistics.empty,
      );
    });
  });

  group('PredictionResult is exhaustive', () {
    test('a switch over every case needs no default clause', () {
      // This compiles only because PredictionResult is sealed. Adding a case
      // turns every switch like this into a compile error, which is what stops
      // a new state from being silently unhandled in the UI. That has already
      // paid for itself twice: NoData and LostTrack were added at AND-09, and
      // SuppressedByCondition at AND-26, and each time this switch and five
      // others across the UI and the notification layer refused to compile
      // until every one of them was handled.
      String describe(PredictionResult r) => switch (r) {
        Predicted(:final prediction) =>
          'predicted ${prediction.confidence.name}',
        InsufficientData(:final cyclesLogged) => 'insufficient $cyclesLogged',
        TooIrregular(:final statistics) =>
          'irregular ${statistics.completedCycles}',
        DataInconsistent(:final reason) => 'inconsistent ${reason.name}',
        NoData() => 'nothing logged',
        LostTrack(:final daysSinceLastLog) => 'lost track $daysSinceLastLog',
        SuppressedByCondition(:final condition) =>
          'suppressed by ${condition.name}',
      };

      expect(
        describe(
          PredictionResult.predicted(
            prediction: _prediction(),
            statistics: CycleStatistics.empty,
          ),
        ),
        'predicted high',
      );
      expect(
        describe(
          PredictionResult.insufficientData(
            populationPrior: _prediction(confidence: Confidence.low),
            cyclesLogged: 1,
          ),
        ),
        'insufficient 1',
      );
      expect(
        describe(
          const PredictionResult.tooIrregular(
            statistics: CycleStatistics(completedCycles: 5),
          ),
        ),
        'irregular 5',
      );
      expect(
        describe(
          const PredictionResult.dataInconsistent(
            reason: DataInconsistency.duplicateDate,
          ),
        ),
        'inconsistent duplicateDate',
      );
      expect(describe(const PredictionResult.noData()), 'nothing logged');
      expect(
        describe(
          const PredictionResult.lostTrack(
            statistics: CycleStatistics.empty,
            daysSinceLastLog: 74,
          ),
        ),
        'lost track 74',
      );
    });
  });

  group('showing the user nothing is unrepresentable', () {
    test('TooIrregular must carry statistics', () {
      // Risk R17: a user with PCOS or in perimenopause who only ever sees
      // "we cannot predict this" stops logging, which degrades the data and
      // makes the state permanent. Requiring statistics here means the UI
      // always has their own observed range to show instead.
      const result = PredictionResult.tooIrregular(
        statistics: CycleStatistics(
          completedCycles: 8,
          shortestLengthDays: 21,
          longestLengthDays: 48,
          medianLengthDays: 31,
        ),
      );
      final stats = (result as TooIrregular).statistics;
      expect(stats.hasHistory, isTrue);
      expect(stats.observedSpreadDays, 27);
      expect(stats.medianLengthDays, 31);
    });

    test('InsufficientData must carry a population prior', () {
      // A brand new user still gets an honest, labelled estimate rather than an
      // empty screen. See PLAN.md 5.5.
      final result = PredictionResult.insufficientData(
        populationPrior: _prediction(spread80: 5, confidence: Confidence.low),
        cyclesLogged: 0,
      );
      final prior = (result as InsufficientData).populationPrior;
      expect(prior.uncertaintyDays, 11);
      expect(prior.confidence, Confidence.low);
    });
  });

  group('JSON round-trip', () {
    test('the union itself is intentionally not serialisable', () {
      // PredictionResult is derived state and has no toJson by design, so a
      // stale prediction can never be restored from a file and shown as
      // current. Its constituent models do serialise, covered below.
      expect(
        PredictionResult.predicted(
          prediction: _prediction(),
          statistics: CycleStatistics.empty,
        ),
        isA<Predicted>(),
      );
    });

    test('PredictionBasis round-trips', () {
      expect(PredictionBasis.fromJson(_basis.toJson()), _basis);
    });

    test('a prediction encodes its windows as start/end date pairs', () {
      final json = _prediction().toJson();
      expect(json['medianStart'], '2026-09-20');
      expect(
        json['window80'],
        <String, dynamic>{'start': '2026-09-17', 'end': '2026-09-23'},
      );
    });

    test('round-trips for every confidence level', () {
      for (final confidence in Confidence.values) {
        final p = _prediction(confidence: confidence);
        expect(Prediction.fromJson(p.toJson()), p, reason: '$confidence');
      }
    });

    test('every inconsistency reason is representable and distinct', () {
      // The union is not serialised (see above), so the guarantee worth testing
      // is that each reason survives construction and compares by value.
      final results = DataInconsistency.values
          .map((r) => PredictionResult.dataInconsistent(reason: r))
          .toList();
      expect(results.toSet(), hasLength(DataInconsistency.values.length));
      for (final reason in DataInconsistency.values) {
        final r = PredictionResult.dataInconsistent(reason: reason);
        expect((r as DataInconsistent).reason, reason);
      }
    });
  });

  group('value semantics', () {
    test('predictions are equal by value', () {
      expect(_prediction(), _prediction());
      expect(_prediction().hashCode, _prediction().hashCode);
      expect(_prediction(), isNot(_prediction(median: 21)));
    });

    test('copyWith leaves the original untouched', () {
      final original = _prediction();
      final copy = original.copyWith(confidence: Confidence.low);
      expect(original.confidence, Confidence.high);
      expect(copy.confidence, Confidence.low);
      expect(copy.medianStart, original.medianStart);
    });
  });
}
