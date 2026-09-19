import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Formats [CivilDate]s for display, in the reader's locale.
///
/// The conversion to [DateTime] happens only here and only at local midnight.
/// [CivilDate] is the app's date type precisely because it has no timezone, and
/// the further that property travels, the fewer places a daylight-saving shift
/// can move a recorded day (risk R7).
extension CivilDateFormatting on CivilDate {
  /// "14 March", or the locale's equivalent.
  String dayAndMonth(BuildContext context) =>
      DateFormat.MMMd(_locale(context)).format(toLocalMidnight());

  /// "Sat, 14 March", or the locale's equivalent.
  String weekdayDayAndMonth(BuildContext context) =>
      DateFormat.MMMEd(_locale(context)).format(toLocalMidnight());

  /// "14 March 2026", or the locale's equivalent.
  String full(BuildContext context) =>
      DateFormat.yMMMMd(_locale(context)).format(toLocalMidnight());

  /// The single letter a week strip labels its columns with.
  ///
  /// The locale's narrow weekday, so it is not always the first letter of the
  /// full name and is not always unique — English has two of both T and S,
  /// which is why the strip is decoration beside a date the reader can also
  /// read in full.
  String weekdayInitial(BuildContext context) =>
      DateFormat('EEEEE', _locale(context)).format(toLocalMidnight());

  /// The day number alone, for a calendar cell.
  String dayNumber(BuildContext context) =>
      DateFormat.d(_locale(context)).format(toLocalMidnight());

  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();
}

/// Formats a month heading such as "March 2026".
String formatMonth(BuildContext context, CivilDate date) => DateFormat.yMMMM(
  Localizations.localeOf(context).toLanguageTag(),
).format(date.toLocalMidnight());

/// Formats a number of days for display, dropping a pointless ".0".
///
/// Cycle statistics are doubles because a median of an even number of cycles
/// can land on a half day. Showing "28.0 days" reads as false precision, and
/// showing "28.5 days" is genuinely the right answer, so the distinction is
/// kept rather than rounded away.
String formatDays(double days) {
  final rounded = (days * 10).roundToDouble() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
