import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/converters.dart';

part 'cycle_record.freezed.dart';
part 'cycle_record.g.dart';

/// Whether a segmented cycle looks trustworthy enough to feed the model.
///
/// Nothing is ever silently dropped. A flagged cycle is still shown to the user
/// and still stored; it is only down-weighted by the prediction filter until the
/// user confirms or corrects it. Silently discarding data the user entered is
/// how an app loses trust. See `docs/PLAN.md` 5.5.
enum CycleValidity {
  /// Plausible, used at full weight.
  ok,

  /// Shorter than 15 days. Usually a mis-logged start or spotting counted as a
  /// period.
  implausiblyShort,

  /// Longer than 90 days. Usually a missed log rather than a real cycle.
  implausiblyLong,

  /// Plausible in isolation but a strong outlier against this user's own
  /// history, pending confirmation.
  unconfirmedOutlier,
}

/// One menstrual cycle, derived from an ordered run of day logs.
///
/// A cycle runs from its first bleeding day up to the day before the next
/// cycle's first bleeding day. The cycle currently in progress has no
/// [nextStartDate] and therefore no [lengthInDays]: it is not yet an
/// observation the model can learn from.
@freezed
abstract class CycleRecord with _$CycleRecord {
  /// Creates a cycle record.
  const factory CycleRecord({
    @CivilDateConverter() required CivilDate startDate,
    @NullableCivilDateConverter() CivilDate? bleedingEndDate,
    @NullableCivilDateConverter() CivilDate? nextStartDate,
    @Default(CycleValidity.ok) CycleValidity validity,
  }) = _CycleRecord;

  const CycleRecord._();

  /// Rebuilds a cycle record from its JSON form.
  factory CycleRecord.fromJson(Map<String, dynamic> json) =>
      _$CycleRecordFromJson(json);

  /// Whether the next cycle has started, making this one a complete
  /// observation.
  bool get isComplete => nextStartDate != null;

  /// Length in days, or null while the cycle is still in progress.
  ///
  /// Measured start-to-start, which is the standard definition and the quantity
  /// the prediction model works in.
  int? get lengthInDays {
    final next = nextStartDate;
    return next == null ? null : startDate.daysBetween(next);
  }

  /// Number of bleeding days, or null if the bleeding end was never recorded.
  int? get bleedingDays {
    final end = bleedingEndDate;
    return end == null ? null : startDate.daysBetween(end) + 1;
  }

  /// Whether this cycle should be used at full weight by the model.
  bool get isUsableObservation => isComplete && validity == CycleValidity.ok;

  /// The span of days this cycle covers, or null while in progress.
  CivilDateRange? get span {
    final next = nextStartDate;
    return next == null ? null : CivilDateRange(startDate, next.addDays(-1));
  }

  /// The span of bleeding days, or null if the end was never recorded.
  CivilDateRange? get bleedingSpan {
    final end = bleedingEndDate;
    return end == null ? null : CivilDateRange(startDate, end);
  }
}
