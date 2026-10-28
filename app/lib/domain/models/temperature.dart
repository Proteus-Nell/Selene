/// Basal temperatures, as the app shows and writes them.
///
/// Stored in Celsius always, and shown in the unit the user chose (ADR-0020).
/// One place for the conversion and the rounding, read by the day editor and
/// by the summary for a doctor (ADR-0024), so a reading cannot be written two
/// ways.
///
/// Includes:
///     - Temperature: Conversion, rounding and writing.
library;

/// Basal temperature conversion, rounding and writing.
abstract final class Temperature {
  /// [celsius] in the unit the user reads: Fahrenheit if [fahrenheit].
  static double toShown(double celsius, {required bool fahrenheit}) =>
      fahrenheit ? celsius * 9 / 5 + 32 : celsius;

  /// A reading [shown] in the user's unit, back in Celsius.
  static double toCelsius(double shown, {required bool fahrenheit}) =>
      fahrenheit ? (shown - 32) * 5 / 9 : shown;

  /// [value] rounded to the hundredths a thermometer shows.
  static double hundredths(double value) => (value * 100).round() / 100;

  /// [value] in hundredths, without the trailing zeros a reading would not
  /// show: "36.5", not "36.50".
  static String format(double value) {
    final fixed = hundredths(value).toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
