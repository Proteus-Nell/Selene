import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/predict/bayes_filter.dart';
import 'package:period_tracker/domain/predict/intervals.dart';
import 'package:period_tracker/domain/predict/priors.dart';

/// A fact about why a prediction looks the way it does.
///
/// The structured half of an explanation. Callers should switch on these rather
/// than matching the English text, because the text is a default rendering that
/// localisation will replace, while these notes are the model's actual
/// reasoning and will not change with language.
enum ExplanationNote {
  /// No completed cycle yet, so the population prior is all there is.
  populationPriorOnly,

  /// Some history, but not enough for the per-user refit to run.
  notYetPersonalised,

  /// The refit ran and the variances are this user's own.
  personalised,

  /// A recent observation sits far from what the model expected.
  unusualRecentCycle,

  /// The 80% window is too wide to show as a prediction.
  tooIrregular,
}

/// A plain-language rationale for one prediction.
///
/// Four separate fields rather than one paragraph, because the insights screen
/// shows them at different weights and a screen reader should be able to stop
/// after the headline.
@immutable
final class PredictionExplanation {
  /// Creates an explanation.
  const PredictionExplanation({
    required this.headline,
    required this.basis,
    required this.uncertainty,
    required this.cautions,
    required this.notes,
  });

  /// What the model predicts, always stated as a range.
  final String headline;

  /// What the prediction was computed from.
  final String basis;

  /// Why the window is as wide as it is.
  final String uncertainty;

  /// Things the user may want to check, in priority order. Often empty.
  final List<String> cautions;

  /// The structured facts behind the text.
  final List<ExplanationNote> notes;

  /// Every line in reading order.
  List<String> get lines => <String>[headline, basis, uncertainty, ...cautions];

  /// The whole explanation as one paragraph.
  String get text => lines.join(' ');

  @override
  String toString() => 'PredictionExplanation($text)';
}

/// Builds the plain-language rationale that accompanies every prediction.
///
/// The product rule this file exists to serve: a number the user cannot
/// interrogate is worse than no number. Every prediction the app shows comes
/// with its range, what it was based on, and what would make it wrong
/// (`docs/PLAN.md` 6.2 and 6.4).
///
/// Three things this text must never do, all of them from the ethics review:
/// state a bare date, offer any medical interpretation, or attribute
/// variability to the person rather than to the data. Where a cycle is
/// unusual, the copy names the most likely mundane cause, which is a missed
/// log.
abstract final class Explain {
  /// Explains [prediction], computed from [cycleLengths] under [priors].
  static PredictionExplanation forPrediction({
    required HistoryPrediction prediction,
    required List<int> cycleLengths,
    required ModelPriors priors,
  }) {
    final notes = <ExplanationNote>[];
    final cautions = <String>[];
    final windows = prediction.windows;
    final n = cycleLengths.length;

    final tooIrregular = prediction.confidence == ConfidenceClass.tooIrregular;
    if (tooIrregular) notes.add(ExplanationNote.tooIrregular);

    final headline = tooIrregular
        ? 'Your logged cycles vary too much to give a useful window, so this '
              'shows your own range instead of a prediction.'
        : 'Your next period is most likely to start about '
              '${_days(windows.medianDays)} after your last one did, and about '
              '4 times in 5 it starts between day ${windows.lo80} and day '
              '${windows.hi80}.';

    final String basis;
    if (n == 0) {
      notes.add(ExplanationNote.populationPriorOnly);
      basis =
          'This is based on typical cycle lengths rather than on you: no '
          'completed cycle has been logged yet.';
    } else if (!prediction.refit.personalised) {
      notes.add(ExplanationNote.notYetPersonalised);
      basis =
          'This is based on the ${_cycles(n)} you have logged, with typical '
          'variability assumed until ${_cycles(priors.personalisation.minCycles)} '
          'are logged.';
    } else {
      notes.add(ExplanationNote.personalised);
      basis =
          'This is based on the ${_cycles(n)} you have logged, including how '
          'much they varied.';
    }

    final uncertainty = _uncertaintyLine(
      cycleLengths: cycleLengths,
      windows: windows,
      tooIrregular: tooIrregular,
    );

    final unusual = _mostUnusualRecent(cycleLengths, prediction.refit.priors);
    if (unusual != null) {
      notes.add(ExplanationNote.unusualRecentCycle);
      final length = cycleLengths[unusual];
      final direction = length > windows.medianDays ? 'longer' : 'shorter';
      cautions.add(
        'One recent cycle was much $direction than your others '
        '(${_days(length)}), which widens the window. A start date that never '
        'got logged looks exactly like this, so it is worth checking that '
        'entry.',
      );
    }

    return PredictionExplanation(
      headline: headline,
      basis: basis,
      uncertainty: uncertainty,
      cautions: List<String>.unmodifiable(cautions),
      notes: List<ExplanationNote>.unmodifiable(notes),
    );
  }

  /// One-step-ahead standardised residuals, oldest first.
  ///
  /// A diagnostic, not part of the prediction path: nothing in the golden
  /// vectors depends on it. It answers "how surprising was each cycle, given
  /// only the cycles before it", which is what makes the unusual-cycle note
  /// honest rather than a fixed day threshold that would fire on anyone with
  /// naturally long cycles.
  static List<double> standardisedResiduals(
    List<int> cycleLengths,
    FilterPriors priors,
  ) {
    final residuals = <double>[];
    var state = BayesFilter.initialState(priors);
    for (final length in cycleLengths) {
      final fc = BayesFilter.forecast(state, priors);
      residuals.add((math.log(length.toDouble()) - fc.mean) / fc.scale);
      state = BayesFilter.update(state, length, priors);
    }
    return residuals;
  }

  /// Standardised residual beyond which a cycle is called unusual.
  ///
  /// Three predictive standard deviations. Deliberately conservative: a false
  /// flag asks the user a needless question, which erodes trust faster than a
  /// missed flag costs accuracy, the same reasoning as
  /// `CycleRules.outlierModifiedZThreshold`.
  static const double unusualResidualThreshold = 3;

  /// How many of the most recent cycles the unusual-cycle note looks at.
  static const int recentCyclesConsidered = 3;

  /// Cycles required before any cycle can be called unusual.
  ///
  /// With fewer, the model has no baseline to be surprised against: the first
  /// observation of a genuinely long-cycled user is far from the population
  /// prior and is not remotely unusual for them.
  static const int minCyclesForUnusualNote = 3;

  /// Index of the most surprising of the recent cycles, or null if none stands
  /// out.
  static int? _mostUnusualRecent(List<int> cycleLengths, FilterPriors priors) {
    if (cycleLengths.length < minCyclesForUnusualNote) return null;
    final residuals = standardisedResiduals(cycleLengths, priors);
    final from = math.max(0, residuals.length - recentCyclesConsidered);
    int? worst;
    var worstMagnitude = unusualResidualThreshold;
    for (var i = from; i < residuals.length; i++) {
      final magnitude = residuals[i].abs();
      if (magnitude > worstMagnitude) {
        worstMagnitude = magnitude;
        worst = i;
      }
    }
    return worst;
  }

  static String _uncertaintyLine({
    required List<int> cycleLengths,
    required PredictionWindows windows,
    required bool tooIrregular,
  }) {
    if (cycleLengths.length < 2) {
      return 'The window is wide because there is almost no history to narrow '
          'it. It tightens as you log more cycles.';
    }
    final lengths = cycleLengths.map((l) => l.toDouble()).toList();
    final spread = CycleFeatures.medianAbsoluteDeviation(lengths);
    // Same `floor(x + 0.5)` convention the model uses for day counts, applied
    // directly rather than through a log round trip that could land a whole
    // day out on an exact half.
    final typical = (CycleFeatures.median(lengths) + 0.5).floor();
    final spreadText = spread < 0.5
        ? 'have been almost the same length'
        : 'have varied by about ${_days((spread + 0.5).floor())}';
    if (tooIrregular) {
      return 'Your logged cycles $spreadText around a typical '
          '${_days(typical)}, which is more than a window can usefully '
          'describe.';
    }
    return 'Your logged cycles $spreadText around a typical ${_days(typical)}, '
        'and about half the time the next one starts between day '
        '${windows.lo50} and day ${windows.hi50}.';
  }

  static String _days(int count) => count == 1 ? '1 day' : '$count days';

  static String _cycles(int count) => count == 1 ? '1 cycle' : '$count cycles';
}
