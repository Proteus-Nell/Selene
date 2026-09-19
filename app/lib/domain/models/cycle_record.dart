/// Cycle record model.
///
/// One menstrual cycle as the app understands it: where it started, how long
/// the bleeding ran, where the next one began, and whether the model should
/// trust it. Derived from day logs by `segmentation.dart` and judged by
/// `validation.dart`; nothing here decides either.
///
/// Includes:
///     - CycleValidity: Whether a cycle is trustworthy enough to learn from.
///     - CycleRecord: The cycle itself, with its derived spans and lengths.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/models/converters.dart';

part 'cycle_record.freezed.dart';
part 'cycle_record.g.dart';

/// Cycle validity: whether a segmented cycle can feed the model.
///
/// Nothing is ever silently dropped. A flagged cycle is still shown to the
/// user and still stored; it is only down-weighted by the prediction filter
/// until the user confirms or corrects it. Silently discarding data the user
/// entered is how an app loses trust. See `docs/PLAN.md` 5.5.
enum CycleValidity {
  /// Plausible, used at full weight.
  ok,

  /// Shorter than 15 days. Usually a mis-logged start or spotting counted as
  /// a period.
  implausiblyShort,

  /// Longer than 90 days. Usually a missed log rather than a real cycle.
  implausiblyLong,

  /// Plausible in isolation but a strong outlier against this user's own
  /// history, pending confirmation.
  unconfirmedOutlier,
}

/// Cycle record: one menstrual cycle, derived from an ordered run of day
/// logs.
///
/// A cycle runs from its first bleeding day up to the day before the next
/// cycle's first bleeding day. The cycle currently in progress has no
/// [nextStartDate] and therefore no [lengthInDays]: it is not yet an
/// observation the model can learn from.
///
/// Attributes:
///     startDate (CivilDate): First bleeding day of this cycle.
///     bleedingEndDate (CivilDate?): Last bleeding day, or null if it was
///         never recorded.
///     nextStartDate (CivilDate?): First bleeding day of the next cycle, or
///         null while this one is in progress.
///     validity (CycleValidity): Whether the model may learn from it.
///         Defaults to [CycleValidity.ok].
@freezed
abstract class CycleRecord with _$CycleRecord {
  /// Creates a cycle record.
  ///
  /// Args:
  ///     startDate (CivilDate): First bleeding day of this cycle.
  ///     bleedingEndDate (CivilDate?, optional): Last bleeding day.
  ///     nextStartDate (CivilDate?, optional): First bleeding day of the next
  ///         cycle. Null leaves this cycle in progress.
  ///     validity (CycleValidity, optional): Defaults to
  ///         [CycleValidity.ok].
  const factory CycleRecord({
    @CivilDateConverter() required CivilDate startDate,
    @NullableCivilDateConverter() CivilDate? bleedingEndDate,
    @NullableCivilDateConverter() CivilDate? nextStartDate,
    @Default(CycleValidity.ok) CycleValidity validity,
  }) = _CycleRecord;

  const CycleRecord._();

  /// Rebuild a cycle record from its JSON form.
  ///
  /// Args:
  ///     json (`Map<String, dynamic>`): The encoded record.
  ///
  /// Returns:
  ///     CycleRecord: The decoded cycle.
  factory CycleRecord.fromJson(Map<String, dynamic> json) =>
      _$CycleRecordFromJson(json);

  /// Whether the next cycle has started, making this one a complete
  /// observation.
  bool get isComplete => nextStartDate != null;

  /// Length in days, or null while the cycle is still in progress.
  ///
  /// Measured start-to-start, which is the standard definition and the
  /// quantity the prediction model works in.
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
