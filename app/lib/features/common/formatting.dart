/// Display formatting.
///
/// Renders dates and day counts in the reader's locale. The conversion from
/// the app's timezone-free date type to a [DateTime] happens only here, and
/// only at local midnight.
///
/// Includes:
///     - CivilDateFormatting: The date formats, as an extension.
///     - formatMonth: A month heading.
///     - formatDays: A day count, without a pointless trailing zero.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Civil date formatting: renders a date in the reader's locale.
///
/// The conversion to [DateTime] happens only here and only at local midnight.
/// [CivilDate] is the app's date type precisely because it has no timezone,
/// and the further that property travels, the fewer places a daylight-saving
/// shift can move a recorded day (risk R7).
extension CivilDateFormatting on CivilDate {
  /// Render as "14 March", or the locale's equivalent.
  ///
  /// Args:
  ///     context (BuildContext): Read for the locale.
  ///
  /// Returns:
  ///     String: The day and month.
  String dayAndMonth(BuildContext context) =>
      DateFormat.MMMd(_locale(context)).format(toLocalMidnight());

  /// Render as "Sat, 14 March", or the locale's equivalent.
  ///
  /// Args:
  ///     context (BuildContext): Read for the locale.
  ///
  /// Returns:
  ///     String: The weekday, day and month.
  String weekdayDayAndMonth(BuildContext context) =>
      DateFormat.MMMEd(_locale(context)).format(toLocalMidnight());

  /// Render as "14 March 2026", or the locale's equivalent.
  ///
  /// Args:
  ///     context (BuildContext): Read for the locale.
  ///
  /// Returns:
  ///     String: The full date.
  String full(BuildContext context) =>
      DateFormat.yMMMMd(_locale(context)).format(toLocalMidnight());

  /// Render the single letter a week strip labels its columns with.
  ///
  /// The locale's narrow weekday, so it is not always the first letter of the
  /// full name and is not always unique. English has two of both T and S,
  /// which is why the strip is decoration beside a date the reader can also
  /// read in full.
  ///
  /// Args:
  ///     context (BuildContext): Read for the locale.
  ///
  /// Returns:
  ///     String: One letter, not necessarily unique within a week.
  String weekdayInitial(BuildContext context) =>
      DateFormat('EEEEE', _locale(context)).format(toLocalMidnight());

  /// Render the day number alone, for a calendar cell.
  ///
  /// Args:
  ///     context (BuildContext): Read for the locale.
  ///
  /// Returns:
  ///     String: The day of the month.
  String dayNumber(BuildContext context) =>
      DateFormat.d(_locale(context)).format(toLocalMidnight());

  /// Read the reader's locale as a language tag.
  ///
  /// Args:
  ///     context (BuildContext): Where the locale is looked up.
  ///
  /// Returns:
  ///     String: A BCP-47 tag, such as `en-GB`.
  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();
}

/// Render a month heading such as "March 2026".
///
/// Args:
///     context (BuildContext): Read for the locale.
///     date (CivilDate): Any day in the month.
///
/// Returns:
///     String: The month and year.
String formatMonth(BuildContext context, CivilDate date) => DateFormat.yMMMM(
  Localizations.localeOf(context).toLanguageTag(),
).format(date.toLocalMidnight());

/// Render a number of days, dropping a pointless trailing zero.
///
/// Cycle statistics are doubles because a median of an even number of cycles
/// can land on a half day. Showing "28.0 days" reads as false precision, and
/// showing "28.5 days" is genuinely the right answer, so the distinction is
/// kept rather than rounded away.
///
/// Args:
///     days (double): The count, possibly fractional.
///
/// Returns:
///     String: One decimal place, or none when the value is whole.
String formatDays(double days) {
  final rounded = (days * 10).roundToDouble() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
