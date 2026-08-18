import 'package:json_annotation/json_annotation.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Encodes a [CivilDate] as a strict `YYYY-MM-DD` string.
///
/// Deliberately not a Unix timestamp or an ISO instant. The export format is
/// the user's own backup and the only recovery path this app has (risk R8), so
/// it should stay readable by a human and free of any timezone interpretation
/// that could shift a recorded day. See `docs/PLAN.md` 6.5.
class CivilDateConverter implements JsonConverter<CivilDate, String> {
  /// Creates the converter.
  const CivilDateConverter();

  @override
  CivilDate fromJson(String json) => CivilDate.parseIso8601(json);

  @override
  String toJson(CivilDate object) => object.toIso8601();
}

/// Encodes a nullable [CivilDate] as a `YYYY-MM-DD` string or null.
class NullableCivilDateConverter implements JsonConverter<CivilDate?, String?> {
  /// Creates the converter.
  const NullableCivilDateConverter();

  @override
  CivilDate? fromJson(String? json) =>
      json == null ? null : CivilDate.parseIso8601(json);

  @override
  String? toJson(CivilDate? object) => object?.toIso8601();
}

/// Encodes a [CivilDateRange] as `{"start": "...", "end": "..."}`.
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
