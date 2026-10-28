/// JSON converters for calendar dates.
///
/// Encodes dates as strict `YYYY-MM-DD` strings rather than as timestamps,
/// because the export file is the user's own backup and the only recovery path
/// this app has (risk R8). It should stay readable by a human and free of any
/// timezone interpretation that could shift a recorded day.
///
/// Includes:
///     - CivilDateConverter: A required date.
///     - NullableCivilDateConverter: An optional date.
///     - CivilDateRangeConverter: A range, as a start and end object.
///     - NullableCivilDateRangeConverter: An optional range.
library;

import 'package:json_annotation/json_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Civil date converter: encodes a date as a strict `YYYY-MM-DD` string.
///
/// Deliberately not a Unix timestamp or an ISO instant. See `docs/PLAN.md`
/// 6.5.
class CivilDateConverter implements JsonConverter<CivilDate, String> {
  /// Creates the converter.
  const CivilDateConverter();

  @override
  CivilDate fromJson(String json) => CivilDate.parseIso8601(json);

  @override
  String toJson(CivilDate object) => object.toIso8601();
}

/// Nullable civil date converter: a `YYYY-MM-DD` string, or null.
///
/// Null round-trips as null rather than as a sentinel date, so an absent
/// bleeding end stays absent.
class NullableCivilDateConverter implements JsonConverter<CivilDate?, String?> {
  /// Creates the converter.
  const NullableCivilDateConverter();

  @override
  CivilDate? fromJson(String? json) =>
      json == null ? null : CivilDate.parseIso8601(json);

  @override
  String? toJson(CivilDate? object) => object?.toIso8601();
}

/// Civil date range converter: a range as `{"start": "...", "end": "..."}`.
///
/// Two named keys rather than a two-element array, so a reader opening the
/// export can tell which end is which.
class CivilDateRangeConverter
    implements JsonConverter<CivilDateRange, Map<String, dynamic>> {
  /// Creates the converter.
  const CivilDateRangeConverter();

  @override
  CivilDateRange fromJson(Map<String, dynamic> json) => CivilDateRange(
    CivilDate.parseIso8601(json['start'] as String),
    CivilDate.parseIso8601(json['end'] as String),
  );

  @override
  Map<String, dynamic> toJson(CivilDateRange object) => <String, dynamic>{
    'start': object.start.toIso8601(),
    'end': object.end.toIso8601(),
  };
}

/// Nullable civil date range converter: a start and end object, or null.
///
/// Null round-trips as null, so a prediction whose windows never moved does
/// not gain an original window it never had.
class NullableCivilDateRangeConverter
    implements JsonConverter<CivilDateRange?, Map<String, dynamic>?> {
  /// Creates the converter.
  const NullableCivilDateRangeConverter();

  @override
  CivilDateRange? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : const CivilDateRangeConverter().fromJson(json);

  @override
  Map<String, dynamic>? toJson(CivilDateRange? object) =>
      object == null ? null : const CivilDateRangeConverter().toJson(object);
}
