/// Model priors and their artifact format.
///
/// Defines everything the prediction pipeline reads out of `priors_v1.json`,
/// and the validating parser that refuses a file it cannot trust. The app
/// normally runs from the compiled-in copy in `priors_bundled.dart`; this file
/// is what both that copy and a runtime parse land in, so there is one
/// definition of what a valid priors file is.
///
/// Includes:
///     - QuantileLevel: The five predictive levels the app needs.
///     - FilterPriors: Population constants the filter starts from.
///     - QuantileTable: Shipped Student-t quantiles for a fixed df.
///     - Personalisation: The on-device refit grids.
///     - ConfidenceThresholds: Where the confidence classes fall.
///     - PriorsLoadError, PriorsLoadFailure: Why a load was refused.
///     - ModelPriors: All of the above, plus the parser.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:period_tracker/core/result.dart';

/// Quantile level: one of the five predictive levels the app needs.
///
/// The set is deliberately small and fixed. Because the observation model's
/// degrees of freedom are a constant, the Student-t quantiles at these levels
/// are constants too, so they ship inside `priors_v1.json` and this runtime
/// never computes a special function. See `docs/PLAN.md` section 8 and the
/// portability rules in `research/src/cyclecore/models/bayes_filter.py`.
enum QuantileLevel {
  /// 10th percentile: lower bound of the 80% window.
  p10('p10'),

  /// 25th percentile: lower bound of the 50% window.
  p25('p25'),

  /// 50th percentile: the predictive median.
  p50('p50'),

  /// 75th percentile: upper bound of the 50% window.
  p75('p75'),

  /// 90th percentile: upper bound of the 80% window.
  p90('p90');

  const QuantileLevel(this.wireName);

  /// The key this level carries in `priors_v1.json` and the golden vectors.
  ///
  /// Spelled out rather than derived from [name] so a rename of the Dart
  /// identifier cannot silently break the artifact contract (ADR-0002).
  final String wireName;
}

/// Filter priors: the population constants the filter starts from.
///
/// Fitted offline in Python and shipped as `priors_v1.json`. Every field is a
/// plain double, so the Dart port holds exactly the values the reference
/// implementation used. Mirrors `FilterPriors` in
/// `research/src/cyclecore/models/bayes_filter.py`.
@immutable
final class FilterPriors {
  /// Creates the population constants.
  const FilterPriors({
    required this.logMeanCenter,
    required this.logMeanVar,
    required this.obsVar,
    required this.driftVar,
    required this.studentTDf,
    required this.minObsVar,
  });

  /// Prior mean of the log-length level, around `log(29)`.
  final double logMeanCenter;

  /// Prior variance of that level.
  ///
  /// Wide enough that roughly three observed cycles dominate it.
  final double logMeanVar;

  /// Within-user observation variance on the log scale.
  final double obsVar;

  /// Random-walk variance of the level between cycles.
  final double driftVar;

  /// Degrees of freedom of the Student-t observation model.
  ///
  /// Fixed, which is what makes the predictive quantiles constants.
  final double studentTDf;

  /// Floor on the effective observation variance.
  ///
  /// Stops a run of identical cycles collapsing the interval to zero width.
  final double minObsVar;

  /// Copy this set with the two per-user variances replaced.
  ///
  /// The only fields personalisation ever changes, which is why the copy is
  /// narrowed to them rather than being a general `copyWith`. Mirrors the
  /// `dataclasses.replace` call in `personalize.py`.
  ///
  /// Args:
  ///     obsVar (double): New within-user observation variance.
  ///     driftVar (double): New random-walk variance of the level.
  ///
  /// Returns:
  ///     FilterPriors: A copy with every other field unchanged.
  FilterPriors withVariances({
    required double obsVar,
    required double driftVar,
  }) => FilterPriors(
    logMeanCenter: logMeanCenter,
    logMeanVar: logMeanVar,
    obsVar: obsVar,
    driftVar: driftVar,
    studentTDf: studentTDf,
    minObsVar: minObsVar,
  );

  @override
  bool operator ==(Object other) =>
      other is FilterPriors &&
      other.logMeanCenter == logMeanCenter &&
      other.logMeanVar == logMeanVar &&
      other.obsVar == obsVar &&
      other.driftVar == driftVar &&
      other.studentTDf == studentTDf &&
      other.minObsVar == minObsVar;

  @override
  int get hashCode => Object.hash(
    logMeanCenter,
    logMeanVar,
    obsVar,
    driftVar,
    studentTDf,
    minObsVar,
  );

  @override
  String toString() =>
      'FilterPriors(logMeanCenter: $logMeanCenter, logMeanVar: $logMeanVar, '
      'obsVar: $obsVar, driftVar: $driftVar, studentTDf: $studentTDf, '
      'minObsVar: $minObsVar)';
}

/// Quantile table: the shipped Student-t quantiles for a fixed [df].
///
/// This table is the whole reason the prediction path needs no special
/// functions on device: SciPy computes it once, offline, and the app reads it
/// as data.
@immutable
final class QuantileTable {
  /// Creates a quantile table.
  const QuantileTable({
    required this.df,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
  });

  /// Degrees of freedom these quantiles were computed for.
  ///
  /// Checked against [FilterPriors.studentTDf] on load. A table computed for
  /// a different `df` would mis-scale every interval the app ever shows,
  /// without any other symptom.
  final double df;

  /// 10th percentile of the standard Student-t.
  final double p10;

  /// 25th percentile of the standard Student-t.
  final double p25;

  /// 50th percentile of the standard Student-t, which is zero.
  final double p50;

  /// 75th percentile of the standard Student-t.
  final double p75;

  /// 90th percentile of the standard Student-t.
  final double p90;

  /// Read the quantile at one level.
  ///
  /// Args:
  ///     level (QuantileLevel): Which percentile to read.
  ///
  /// Returns:
  ///     double: The standard Student-t quantile at that level.
  double operator [](QuantileLevel level) => switch (level) {
    QuantileLevel.p10 => p10,
    QuantileLevel.p25 => p25,
    QuantileLevel.p50 => p50,
    QuantileLevel.p75 => p75,
    QuantileLevel.p90 => p90,
  };

  @override
  bool operator ==(Object other) =>
      other is QuantileTable &&
      other.df == df &&
      other.p10 == p10 &&
      other.p25 == p25 &&
      other.p50 == p50 &&
      other.p75 == p75 &&
      other.p90 == p90;

  @override
  int get hashCode => Object.hash(df, p10, p25, p50, p75, p90);

  @override
  String toString() =>
      'QuantileTable(df: $df, p10: $p10, p25: $p25, p50: $p50, p75: $p75, '
      'p90: $p90)';
}

/// Personalisation: the on-device refit search, as shipped.
///
/// The grids are explicit values rather than a computed range, so Dart
/// iterates exactly the points Python did. Recomputing a log-spaced range in
/// two languages is a reliable way to end up one rounding step apart on a grid
/// point, and the winning point would then differ between runtimes.
///
/// Attributes:
///     minCycles (int): Completed cycles required before the refit runs.
///     obsSdGrid (`List<double>`): Candidate observation SDs, in search
///         order.
///     driftSdGrid (`List<double>`): Candidate drift SDs, in search order.
@immutable
final class Personalisation {
  /// Creates a personalisation configuration.
  const Personalisation({
    required this.minCycles,
    required this.obsSdGrid,
    required this.driftSdGrid,
  });

  /// Completed cycles required before the refit runs at all.
  ///
  /// Below this the estimate is dominated by noise and the interval width
  /// would swing around alarmingly between cycles.
  final int minCycles;

  /// Candidate within-user observation standard deviations, in search order.
  final List<double> obsSdGrid;

  /// Candidate drift standard deviations, in search order.
  final List<double> driftSdGrid;

  @override
  bool operator ==(Object other) =>
      other is Personalisation &&
      other.minCycles == minCycles &&
      _doublesEqual(other.obsSdGrid, obsSdGrid) &&
      _doublesEqual(other.driftSdGrid, driftSdGrid);

  @override
  int get hashCode => Object.hash(
    minCycles,
    Object.hashAll(obsSdGrid),
    Object.hashAll(driftSdGrid),
  );

  @override
  String toString() =>
      'Personalisation(minCycles: $minCycles, obsSdGrid: $obsSdGrid, '
      'driftSdGrid: $driftSdGrid)';
}

/// Confidence thresholds: the widths at which the 80% window changes class.
///
/// Thresholds rather than an inequality buried in code, because these are
/// product judgements about how wide a window may be before calling it
/// confident becomes dishonest (`docs/PLAN.md` 6.2).
@immutable
final class ConfidenceThresholds {
  /// Creates a threshold set.
  const ConfidenceThresholds({
    required this.highBelowDays,
    required this.mediumBelowDays,
    required this.lowBelowDays,
  });

  /// An 80% window strictly narrower than this counts as high confidence.
  final int highBelowDays;

  /// Below this, medium confidence.
  final int mediumBelowDays;

  /// Below this, low confidence. At or above it, refuse a narrow window.
  final int lowBelowDays;

  @override
  bool operator ==(Object other) =>
      other is ConfidenceThresholds &&
      other.highBelowDays == highBelowDays &&
      other.mediumBelowDays == mediumBelowDays &&
      other.lowBelowDays == lowBelowDays;

  @override
  int get hashCode => Object.hash(highBelowDays, mediumBelowDays, lowBelowDays);

  @override
  String toString() =>
      'ConfidenceThresholds(highBelowDays: $highBelowDays, '
      'mediumBelowDays: $mediumBelowDays, lowBelowDays: $lowBelowDays)';
}

/// Priors load error: why an artifact could not be loaded.
enum PriorsLoadError {
  /// The `schema_version` is one this build does not know.
  ///
  /// Refusing is the point: fields can change meaning between versions, and
  /// reading them anyway would produce a plausible-looking wrong prediction
  /// rather than a visible failure (`docs/PLAN.md` 5.3).
  unsupportedSchemaVersion,

  /// The text was not valid JSON.
  malformedJson,

  /// A required field is absent.
  missingField,

  /// A field is present but of the wrong type.
  wrongType,

  /// A field is well-formed but not usable, such as a negative variance.
  invalidValue,
}

/// Priors load failure: a refusal, with enough detail to act on.
///
/// Attributes:
///     error (PriorsLoadError): What kind of problem this is.
///     field (String): Dotted path of the offending field, or `<root>`.
///     message (String): Human-readable detail, for logs and tests.
@immutable
final class PriorsLoadFailure {
  /// Creates a failure for [field] with [message].
  const PriorsLoadFailure(this.error, this.field, this.message);

  /// What kind of problem this is.
  final PriorsLoadError error;

  /// Dotted path of the offending field, or `<root>` for whole-file problems.
  final String field;

  /// Human-readable detail, for logs and test failure messages.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is PriorsLoadFailure &&
      other.error == error &&
      other.field == field &&
      other.message == message;

  @override
  int get hashCode => Object.hash(error, field, message);

  @override
  String toString() => 'PriorsLoadFailure(${error.name}, $field: $message)';
}

/// Model priors: everything read out of `priors_v1.json`.
///
/// The app ships a compiled-in copy (`bundledPriors` in `priors_bundled.dart`,
/// generated from the artifact) and can also parse the artifact at runtime
/// with [ModelPriors.parse]. Both paths land in this one type, so there is a
/// single definition of what a valid priors file is.
@immutable
final class ModelPriors {
  /// Creates a priors set.
  const ModelPriors({
    required this.schemaVersion,
    required this.filterPriors,
    required this.quantiles,
    required this.personalisation,
    required this.confidenceThresholds,
  });

  /// Parse text as a priors artifact.
  ///
  /// Args:
  ///     jsonText (String): The artifact's contents.
  ///
  /// Returns:
  ///     `Result<ModelPriors, PriorsLoadFailure>`: The priors, or a refusal.
  ///     An [Err] rather than a throw, because a priors file the app cannot
  ///     read is a state the app must handle, not a crash (`docs/PLAN.md`
  ///     5.5).
  static Result<ModelPriors, PriorsLoadFailure> parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      return Err(
        PriorsLoadFailure(PriorsLoadError.malformedJson, '<root>', e.message),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return const Err(
        PriorsLoadFailure(
          PriorsLoadError.wrongType,
          '<root>',
          'expected a JSON object',
        ),
      );
    }
    return fromJson(decoded);
  }

  /// Validate an already-decoded priors document.
  ///
  /// Every check here is a guard against shipping a file that would produce
  /// silently wrong predictions: an unknown schema, a quantile table computed
  /// for the wrong degrees of freedom, a non-positive variance, an empty
  /// search grid, or thresholds that do not increase.
  ///
  /// Args:
  ///     json (`Map<String, Object?>`): The decoded document.
  ///
  /// Returns:
  ///     `Result<ModelPriors, PriorsLoadFailure>`: The priors, or the first
  ///     refusal encountered.
  static Result<ModelPriors, PriorsLoadFailure> fromJson(
    Map<String, Object?> json,
  ) {
    try {
      final schemaVersion = _requireInt(json, 'schema_version');
      if (!supportedSchemaVersions.contains(schemaVersion)) {
        throw _PriorsFormatException(
          PriorsLoadError.unsupportedSchemaVersion,
          'schema_version',
          'this build supports $supportedSchemaVersions, file declares '
              '$schemaVersion',
        );
      }

      final filterJson = _requireMap(json, 'filter_priors');
      final filterPriors = FilterPriors(
        logMeanCenter: _requireFinite(filterJson, 'log_mean_center'),
        logMeanVar: _requirePositive(filterJson, 'log_mean_var'),
        obsVar: _requirePositive(filterJson, 'obs_var'),
        driftVar: _requirePositive(filterJson, 'drift_var'),
        studentTDf: _requirePositive(filterJson, 'student_t_df'),
        minObsVar: _requirePositive(filterJson, 'min_obs_var'),
      );

      final quantileJson = _requireMap(json, 't_quantiles');
      final values = _requireMap(quantileJson, 'values');
      final quantiles = QuantileTable(
        df: _requirePositive(quantileJson, 'df'),
        p10: _requireFinite(values, QuantileLevel.p10.wireName),
        p25: _requireFinite(values, QuantileLevel.p25.wireName),
        p50: _requireFinite(values, QuantileLevel.p50.wireName),
        p75: _requireFinite(values, QuantileLevel.p75.wireName),
        p90: _requireFinite(values, QuantileLevel.p90.wireName),
      );
      if (quantiles.df != filterPriors.studentTDf) {
        throw _PriorsFormatException(
          PriorsLoadError.invalidValue,
          't_quantiles.df',
          'quantiles are for df ${quantiles.df} but the observation model uses '
              'df ${filterPriors.studentTDf}',
        );
      }
      if (!(quantiles.p10 < quantiles.p25 &&
          quantiles.p25 < quantiles.p50 &&
          quantiles.p50 < quantiles.p75 &&
          quantiles.p75 < quantiles.p90)) {
        throw const _PriorsFormatException(
          PriorsLoadError.invalidValue,
          't_quantiles.values',
          'quantiles must increase from p10 to p90',
        );
      }

      final personalisationJson = _requireMap(json, 'personalisation');
      final personalisation = Personalisation(
        minCycles: _requireInt(personalisationJson, 'min_cycles'),
        obsSdGrid: _requirePositiveGrid(personalisationJson, 'obs_sd_grid'),
        driftSdGrid: _requirePositiveGrid(personalisationJson, 'drift_sd_grid'),
      );
      if (personalisation.minCycles < 1) {
        throw _PriorsFormatException(
          PriorsLoadError.invalidValue,
          'personalisation.min_cycles',
          'must be at least 1, got ${personalisation.minCycles}',
        );
      }

      final thresholdJson = _requireMap(json, 'confidence_thresholds_days');
      final confidenceThresholds = ConfidenceThresholds(
        highBelowDays: _requireInt(thresholdJson, 'high_below'),
        mediumBelowDays: _requireInt(thresholdJson, 'medium_below'),
        lowBelowDays: _requireInt(thresholdJson, 'low_below'),
      );
      if (!(confidenceThresholds.highBelowDays <
              confidenceThresholds.mediumBelowDays &&
          confidenceThresholds.mediumBelowDays <
              confidenceThresholds.lowBelowDays)) {
        throw const _PriorsFormatException(
          PriorsLoadError.invalidValue,
          'confidence_thresholds_days',
          'thresholds must increase: high < medium < low',
        );
      }

      return Ok(
        ModelPriors(
          schemaVersion: schemaVersion,
          filterPriors: filterPriors,
          quantiles: quantiles,
          personalisation: personalisation,
          confidenceThresholds: confidenceThresholds,
        ),
      );
    } on _PriorsFormatException catch (e) {
      return Err(PriorsLoadFailure(e.error, e.field, e.message));
    }
  }

  /// Schema versions this build knows how to read.
  ///
  /// Anything else is refused by [fromJson]. Widening this set is a
  /// deliberate act that must come with code that understands the new shape.
  static const Set<int> supportedSchemaVersions = <int>{1};

  /// Version of the artifact this was read from.
  final int schemaVersion;

  /// Constants the filter itself consumes.
  final FilterPriors filterPriors;

  /// Student-t quantiles for [FilterPriors.studentTDf].
  final QuantileTable quantiles;

  /// The on-device refit configuration.
  final Personalisation personalisation;

  /// Where the confidence classes fall.
  final ConfidenceThresholds confidenceThresholds;

  @override
  bool operator ==(Object other) =>
      other is ModelPriors &&
      other.schemaVersion == schemaVersion &&
      other.filterPriors == filterPriors &&
      other.quantiles == quantiles &&
      other.personalisation == personalisation &&
      other.confidenceThresholds == confidenceThresholds;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    filterPriors,
    quantiles,
    personalisation,
    confidenceThresholds,
  );

  @override
  String toString() =>
      'ModelPriors(schemaVersion: $schemaVersion, '
      'filterPriors: $filterPriors, quantiles: $quantiles, '
      'personalisation: $personalisation, '
      'confidenceThresholds: $confidenceThresholds)';
}

/// Report whether two lists of doubles hold the same values in order.
///
/// Args:
///     a (`List<double>`): First list.
///     b (`List<double>`): Second list.
///
/// Returns:
///     bool: True when both hold the same values in the same order.
bool _doublesEqual(List<double> a, List<double> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Priors format exception: the parser's internal failure signal.
///
/// Converted to a [PriorsLoadFailure] at the boundary and never allowed to
/// escape: unwinding a dozen nested field reads through [Result] would bury
/// the actual validation rules in plumbing.
///
/// Attributes:
///     error (PriorsLoadError): What kind of problem this is.
///     field (String): Dotted path of the offending field.
///     message (String): Human-readable detail.
@immutable
final class _PriorsFormatException implements Exception {
  /// Creates a parse failure for [field].
  ///
  /// Args:
  ///     error (PriorsLoadError): What kind of problem this is.
  ///     field (String): Dotted path of the offending field.
  ///     message (String): Human-readable detail.
  const _PriorsFormatException(this.error, this.field, this.message);

  /// What kind of problem this is.
  final PriorsLoadError error;

  /// Dotted path of the offending field.
  final String field;

  /// Human-readable detail.
  final String message;
}

/// Read a field, requiring it to be present.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     Object?: The raw value, which may itself be null.
///
/// Throws:
///     _PriorsFormatException: If the key is absent.
Object? _require(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) {
    throw _PriorsFormatException(
      PriorsLoadError.missingField,
      field,
      'required field is absent',
    );
  }
  return json[field];
}

/// Read a field, requiring it to be a JSON object.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     `Map<String, Object?>`: The nested object.
///
/// Throws:
///     _PriorsFormatException: If the key is absent or not an object.
Map<String, Object?> _requireMap(Map<String, Object?> json, String field) {
  final value = _require(json, field);
  if (value is! Map<String, Object?>) {
    throw _PriorsFormatException(
      PriorsLoadError.wrongType,
      field,
      'expected an object, got ${value.runtimeType}',
    );
  }
  return value;
}

/// Read a field, requiring it to be an integer.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     int: The value.
///
/// Throws:
///     _PriorsFormatException: If the key is absent or not an integer.
int _requireInt(Map<String, Object?> json, String field) {
  final value = _require(json, field);
  if (value is! int) {
    throw _PriorsFormatException(
      PriorsLoadError.wrongType,
      field,
      'expected an integer, got ${value.runtimeType}',
    );
  }
  return value;
}

/// Read a field, requiring it to be a finite number.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     double: The value, widened from int if necessary.
///
/// Throws:
///     _PriorsFormatException: If the key is absent, not a number, or not
///         finite.
double _requireFinite(Map<String, Object?> json, String field) {
  final value = _require(json, field);
  if (value is! num) {
    throw _PriorsFormatException(
      PriorsLoadError.wrongType,
      field,
      'expected a number, got ${value.runtimeType}',
    );
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite) {
    throw _PriorsFormatException(
      PriorsLoadError.invalidValue,
      field,
      'must be finite, got $asDouble',
    );
  }
  return asDouble;
}

/// Read a field, requiring it to be a positive finite number.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     double: The value.
///
/// Throws:
///     _PriorsFormatException: If the value is absent, not a number, not
///         finite, or not greater than zero.
double _requirePositive(Map<String, Object?> json, String field) {
  final value = _requireFinite(json, field);
  if (value <= 0) {
    throw _PriorsFormatException(
      PriorsLoadError.invalidValue,
      field,
      'must be positive, got $value',
    );
  }
  return value;
}

/// Read a field, requiring it to be a non-empty grid of positive SDs.
///
/// Args:
///     json (`Map<String, Object?>`): The object to read from.
///     field (String): The key to read.
///
/// Returns:
///     `List<double>`: The grid, unmodifiable, in the order it shipped in.
///
/// Throws:
///     _PriorsFormatException: If the value is absent, not an array, empty,
///         or holds anything that is not a positive finite number. Empty is
///         refused because the refit iterates the grid directly.
List<double> _requirePositiveGrid(Map<String, Object?> json, String field) {
  final value = _require(json, field);
  if (value is! List<Object?>) {
    throw _PriorsFormatException(
      PriorsLoadError.wrongType,
      field,
      'expected an array, got ${value.runtimeType}',
    );
  }
  if (value.isEmpty) {
    throw _PriorsFormatException(
      PriorsLoadError.invalidValue,
      field,
      'must not be empty; the refit iterates it directly',
    );
  }
  final grid = <double>[];
  for (var i = 0; i < value.length; i++) {
    final entry = value[i];
    if (entry is! num) {
      throw _PriorsFormatException(
        PriorsLoadError.wrongType,
        '$field[$i]',
        'expected a number, got ${entry.runtimeType}',
      );
    }
    final asDouble = entry.toDouble();
    if (!asDouble.isFinite || asDouble <= 0) {
      throw _PriorsFormatException(
        PriorsLoadError.invalidValue,
        '$field[$i]',
        'must be a positive finite standard deviation, got $asDouble',
      );
    }
    grid.add(asDouble);
  }
  return List<double>.unmodifiable(grid);
}
