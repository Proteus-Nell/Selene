import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/converters.dart';

part 'prediction.freezed.dart';
part 'prediction.g.dart';

/// How tightly the model can pin the next start date.
///
/// Derived from predictive interval width and history length, never asserted by
/// hand. See `docs/PLAN.md` section 8.
enum Confidence {
  /// 80% window under 4 days wide.
  high,

  /// 80% window under 8 days wide.
  medium,

  /// 80% window under 14 days wide.
  low,
}

/// Ways the stored logs can contradict themselves.
enum DataInconsistency {
  /// Two cycles claim overlapping day ranges.
  overlappingCycles,

  /// The same date appears more than once.
  duplicateDate,

  /// A cycle ends before it starts.
  negativeCycleLength,

  /// The device clock moved backwards relative to the newest stored log.
  clockWentBackwards,
}

/// Summary statistics over a user's own cycle history.
///
/// Always shown, including when no prediction is possible. This type is what
/// stops the [TooIrregular] state from being a dead end: a user whose cycles
/// cannot be predicted narrowly still gets their own range and variability
/// back, which is genuinely useful information (risk R17).
@freezed
abstract class CycleStatistics with _$CycleStatistics {
  /// Creates a statistics summary.
  const factory CycleStatistics({
    required int completedCycles,
    double? medianLengthDays,
    double? medianAbsoluteDeviationDays,
    int? shortestLengthDays,
    int? longestLengthDays,
  }) = _CycleStatistics;

  const CycleStatistics._();

  /// Rebuilds a statistics summary from its JSON form.
  factory CycleStatistics.fromJson(Map<String, dynamic> json) =>
      _$CycleStatisticsFromJson(json);

  /// Statistics for a user with no completed cycles yet.
  static const CycleStatistics empty = CycleStatistics(completedCycles: 0);

  /// Whether there is any observed history at all.
  bool get hasHistory => completedCycles > 0;

  /// The observed spread in days, or null without at least two cycles.
  int? get observedSpreadDays {
    final shortest = shortestLengthDays;
    final longest = longestLengthDays;
    if (shortest == null || longest == null || completedCycles < 2) return null;
    return longest - shortest;
  }
}

/// What a prediction was based on, for the plain-language explanation.
///
/// Exists so the UI can say "based on your last 6 cycles, which varied by about
/// 5 days" rather than presenting a number from nowhere (`docs/PLAN.md` 6.4).
@freezed
abstract class PredictionBasis with _$PredictionBasis {
  /// Creates a basis record.
  const factory PredictionBasis({
    required int cyclesUsed,
    required double medianLengthDays,
    required double variabilityDays,
    @Default(false) bool usedPopulationPrior,
    @Default(false) bool personalizedHyperparameters,
  }) = _PredictionBasis;

  // The private constructor is required, not decorative: without it freezed
  // does not surface toJson() on the abstract type, and json_serializable then
  // emits `instance.basis` instead of `instance.basis.toJson()` in the enclosing
  // Prediction, which fails at runtime on the way back in.
  const PredictionBasis._();

  /// Rebuilds a basis record from its JSON form.
  factory PredictionBasis.fromJson(Map<String, dynamic> json) =>
      _$PredictionBasisFromJson(json);
}

/// Serialises a nested [PredictionBasis]. See the note on [Prediction.basis].
Map<String, dynamic> _basisToJson(PredictionBasis basis) => basis.toJson();

/// A predicted next period start, always with its uncertainty attached.
///
/// There is deliberately no way to construct a prediction without both windows.
/// The product rule is that a bare date is never shown, because it implies a
/// precision the model does not have, and that rule is enforced here in the type
/// rather than in review. See `docs/PLAN.md` 6.2.
@freezed
abstract class Prediction with _$Prediction {
  /// Creates a prediction.
  // Deliberately NOT const: the assertion calls getters on CivilDateRange, and
  // a const constructor may only assert over constant expressions. Enforcing
  // the invariant is worth more here than const-constructibility, since a
  // Prediction is always computed at runtime anyway.
  @Assert(
    'window80.lengthInDays >= window50.lengthInDays',
    'the 80% window cannot be narrower than the 50% window',
  )
  factory Prediction({
    @CivilDateConverter() required CivilDate medianStart,
    @CivilDateRangeConverter() required CivilDateRange window50,
    @CivilDateRangeConverter() required CivilDateRange window80,
    required Confidence confidence,
    // Explicit converters: json_serializable cannot resolve the
    // freezed-generated toJson() for a model declared in the SAME file, and
    // silently emits the raw object instead of a nested map, which then throws
    // on the way back in. Nested freezed models need this spelled out.
    @JsonKey(fromJson: PredictionBasis.fromJson, toJson: _basisToJson)
    required PredictionBasis basis,
  }) = _Prediction;

  const Prediction._();

  /// Rebuilds a prediction from its JSON form.
  factory Prediction.fromJson(Map<String, dynamic> json) =>
      _$PredictionFromJson(json);

  /// Width of the 80% window in days. The headline uncertainty figure.
  int get uncertaintyDays => window80.lengthInDays;

  /// Whether [medianStart] sits inside both windows, as it always should.
  bool get isCoherent =>
      window50.contains(medianStart) &&
      window80.contains(medianStart) &&
      window80.start <= window50.start &&
      window80.end >= window50.end;
}

/// The outcome of asking the model for a prediction.
///
/// A sealed union, so every consumer must handle every case and the analyzer
/// rejects a non-exhaustive switch. Most of the cases are load-bearing product
/// decisions rather than error paths:
///
/// * [InsufficientData] still carries a [Prediction], the population prior, so
///   a user with one logged period sees something honest rather than an empty
///   screen.
/// * [TooIrregular] still carries [CycleStatistics], so a user with PCOS or in
///   perimenopause is never told only "we cannot predict this" (risk R17).
/// * [LostTrack] exists so that a long silence produces an admission rather
///   than an extrapolation. Predicting from data two months stale gives a
///   confident wrong answer, which is the failure mode this project is most
///   concerned with (`docs/PLAN.md` 5.5).
///
/// In other words, "show the user nothing" is not representable in this type.
/// The one case that carries no prediction at all, [NoData], is the state
/// before the user has told the app anything, and even that names the reason
/// rather than leaving an empty screen.
@freezed
sealed class PredictionResult with _$PredictionResult {
  /// A usable, personalised prediction.
  const factory PredictionResult.predicted({
    required Prediction prediction,
    required CycleStatistics statistics,
  }) = Predicted;

  /// Too little history to personalise, so the population prior is returned.
  ///
  /// The UI must label this as not yet personalised rather than passing it off
  /// as a prediction about this user.
  const factory PredictionResult.insufficientData({
    required Prediction populationPrior,
    required int cyclesLogged,
  }) = InsufficientData;

  /// Nothing has been logged, so there is no date to anchor a prediction to.
  ///
  /// Deliberately not an [InsufficientData] carrying a window measured from
  /// today. The model predicts a cycle *length*, and turning that into a date
  /// needs a logged period start; anchoring on today instead would assert that
  /// the user's period started today, which is a fact the app would have
  /// invented. What the UI shows here is an invitation to log a first day,
  /// alongside typical cycle lengths clearly labelled as typical.
  const factory PredictionResult.noData() = NoData;

  /// No logs for long enough that the app should admit it has lost track.
  ///
  /// [statistics] is required for the same reason as in [TooIrregular]: losing
  /// track must not lose the user their own history.
  const factory PredictionResult.lostTrack({
    required CycleStatistics statistics,
    required int daysSinceLastLog,
  }) = LostTrack;

  /// Cycle variability is too high for a useful window.
  ///
  /// [statistics] is required, not optional: this state must still give the user
  /// their own observed range and variability.
  const factory PredictionResult.tooIrregular({
    required CycleStatistics statistics,
  }) = TooIrregular;

  /// The stored logs contradict themselves and must be corrected first.
  const factory PredictionResult.dataInconsistent({
    required DataInconsistency reason,
  }) = DataInconsistent;

  /// A recorded condition makes a prediction the wrong thing to give.
  ///
  /// Distinct from every other state here, and the distinction is the reason it
  /// exists. The rest describe what the model *could not* work out — too little
  /// data, too much variance, too long a silence. This one describes a case
  /// where the model would work perfectly well and its answer would still be
  /// wrong to show: forecasting a period for someone who has recorded an active
  /// pregnancy is not an uninformed guess, it is a confidently incorrect claim
  /// about something the user has already told the app.
  ///
  /// **Only [Condition.pregnancy] produces this.** Hormonal contraception often
  /// removes true cycles entirely and is the obvious next candidate; it was
  /// considered and deliberately not chosen (ADR-0010), so it must not be added
  /// here without revisiting that decision. See [Condition.suppressesPrediction],
  /// which is the single place the rule lives.
  ///
  /// [statistics] is carried for the same reason [TooIrregular] carries it:
  /// withholding a prediction must never also withhold the user's own history.
  /// A pregnancy ends, and the cycles logged before it are still theirs.
  const factory PredictionResult.suppressedByCondition({
    required Condition condition,
    required CycleStatistics statistics,
  }) = SuppressedByCondition;
}

// Note: PredictionResult deliberately has no toJson/fromJson.
//
// It is ephemeral derived state, recomputed from the day logs on every read, so
// it never needs persisting. Serialising it would actively invite a bug: a
// restored-from-export prediction could be shown as current when the underlying
// logs had changed. Export and import deal in DayLog only (ADR-0002).
//
// This also sidesteps a freezed 3.2.5 codegen defect, which emits an invalid
// `final String? $type` named parameter into the const constructors of a sealed
// union that has fromJson. The constituent models (Prediction, CycleStatistics,
// PredictionBasis) all serialise normally.
