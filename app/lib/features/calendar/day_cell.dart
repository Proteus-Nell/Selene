import 'package:flutter/material.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// A solid marker: this day was logged as bleeding.
///
/// Filled, where the predicted marker is hollow. The pair is chosen so that the
/// two states are told apart by shape in greyscale, not only by colour
/// (`docs/PLAN.md` 2.4.4, "never colour alone").
class PeriodMarker extends StatelessWidget {
  /// Creates the marker.
  const PeriodMarker({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// A hollow marker: this day is inside the predicted window.
class PredictedMarker extends StatelessWidget {
  /// Creates the marker.
  const PredictedMarker({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.secondary,
        width: 2,
      ),
    ),
  );
}

/// One day in the month grid.
///
/// The [Semantics] label is the load-bearing part. A screen reader reading this
/// grid without it gets a list of bare numbers, which is worse than useless on
/// the screen the app is built around. The label is assembled to read as a
/// sentence: "14 March, period day 2, inside predicted window, today".
class DayCell extends StatelessWidget {
  /// Creates a cell for [date].
  const DayCell({
    required this.date,
    required this.height,
    required this.isToday,
    required this.periodDayNumber,
    required this.isPredicted,
    required this.hasSymptoms,
    required this.onLongPress,
    super.key,
  });

  /// The day this cell shows.
  final CivilDate date;

  /// How tall the cell should be, measured from the current text scale.
  final double height;

  /// Whether this is the current day.
  final bool isToday;

  /// Which day of a bleeding run this is, or null if it is not one.
  final int? periodDayNumber;

  /// Whether this day falls inside the predicted window.
  final bool isPredicted;

  /// Whether any symptom was recorded.
  final bool hasSymptoms;

  /// Opens the editor for this day.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPeriod = periodDayNumber != null;

    final label = _semanticLabel(l10n, context);

    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onLongPress,
        onLongPress: onLongPress,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isPeriod
                    ? theme.colorScheme.primary.withValues(alpha: 0.16)
                    : null,
                border: Border.all(
                  color: isToday
                      ? theme.colorScheme.onSurface
                      : isPredicted
                      ? theme.colorScheme.secondary
                      : Colors.transparent,
                  width: isToday ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        date.dayNumber(context),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday || isPeriod
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  // Shape carries the state as well as the fill does, so the
                  // grid still reads in greyscale.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isPeriod) const PeriodMarker(),
                      if (isPeriod && isPredicted) const SizedBox(width: 3),
                      if (isPredicted) const PredictedMarker(),
                      if (hasSymptoms) ...<Widget>[
                        if (isPeriod || isPredicted) const SizedBox(width: 3),
                        Icon(
                          Icons.circle,
                          size: 5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel(AppLocalizations l10n, BuildContext context) {
    final readable = date.dayAndMonth(context);
    final periodDay = periodDayNumber;
    var label = switch ((periodDay, isPredicted)) {
      (final int day, true) => l10n.calendarCellPeriodAndPredicted(
        readable,
        day,
      ),
      (final int day, false) => l10n.calendarCellPeriodDay(readable, day),
      (null, true) => l10n.calendarCellPredicted(readable),
      (null, false) => l10n.calendarCellPlain(readable),
    };
    if (hasSymptoms) label = l10n.calendarCellSymptomsSuffix(label);
    if (isToday) label = l10n.calendarCellTodaySuffix(label);
    return label;
  }
}
