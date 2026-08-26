import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
import 'package:period_tracker/features/calendar/phase_strip.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/next_period_panel.dart';
import 'package:period_tracker/features/log/day_editor.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The month grid: what was logged, and when the next period is expected.
///
/// The app's primary surface, and the one most likely to be unusable. Two
/// requirements shape every decision here, both from `docs/PLAN.md` 2.4.4 and
/// 6.2:
///
/// **A grid of coloured squares announces nothing.** Every cell carries a
/// hand-written [Semantics] label with the date *and* its state, and every
/// state is also distinguishable without colour: a logged period day is filled
/// with a solid marker, a predicted day is outlined with a hollow marker, today
/// carries a ring. Colour is the fourth cue, not the only one.
///
/// **The predicted window is a range.** There is deliberately no code path
/// here that highlights the median day: marking one day would imply a precision
/// the model does not have, which is the everyday form of overclaiming.
class CalendarScreen extends ConsumerStatefulWidget {
  /// Creates the calendar.
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _monthOffset = 0;

  /// Which way the last month change went: 1 forward, -1 back.
  ///
  /// Kept so the grid can leave in the direction it was pushed. A transition
  /// that always came from the same side would say nothing about which way the
  /// user is travelling, which is the only thing it is there to say.
  int _direction = 1;

  void _stepMonth(int by) => setState(() {
    _direction = by;
    _monthOffset += by;
  });

  Future<void> _edit(CivilDate date, DayLog? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // The editor is tall enough to reach the top of the screen, and there the
      // date heading lands under the status bar and the camera cutout. The
      // route has to be kept inside the cutout; a SafeArea inside the sheet is
      // too late, because the route has already claimed the full height.
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          // The date and Close sit outside the scroll view, and the editor
          // scrolls under them. Close used to be the last thing in one long
          // scrolling column, which worked while the editor was five chips
          // tall and stopped working the moment AND-23 made it sixteen: the
          // button laid out below the fold, so the only way to dismiss the
          // sheet deliberately was to scroll to the end of the symptom list
          // first. Swiping and tapping the barrier still worked, but those are
          // the gestures a screen-reader user does not have.
          //
          // Flexible rather than Expanded, so a sheet with little in it still
          // shrink-wraps instead of always filling the screen.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      date.full(sheetContext),
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(AppLocalizations.of(sheetContext).commonClose),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final logs =
                          ref.watch(dayLogsProvider).valueOrNull ??
                          const <DayLog>[];
                      return DayEditor(
                        date: date,
                        existing: _entryFor(logs, date),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(clockProvider).today();
    final month = _monthStart(today).addMonths(_monthOffset);
    final logs = ref.watch(dayLogsProvider).valueOrNull ?? const <DayLog>[];
    final prediction = ref.watch(predictionProvider).valueOrNull;
    final window = _predictedWindow(prediction);
    // Both default to their stored defaults while loading: phases on, the
    // ovulation estimate off. Erring the other way for even one frame would
    // show an estimate the user has not opted into, which is the one thing
    // docs/PLAN.md 6.2 does not tolerate.
    final showPhases = ref.watch(showCyclePhasesProvider).valueOrNull ?? true;
    final showOvulation =
        ref.watch(showOvulationWindowProvider).valueOrNull ?? false;
    final position = CyclePhases.on(
      date: today,
      logs: logs,
      predictedStart: _predictedStart(prediction),
      withOvulationEstimate: showOvulation,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => _stepMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l10n.calendarPreviousMonth,
                ),
                Expanded(
                  child: Text(
                    formatMonth(context, month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _stepMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l10n.calendarNextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // The grid travels; the row above it does not. A header that slid
            // with the grid would take the two chevrons out from under the
            // finger that is stepping through months, which is the one gesture
            // this screen is built around (AND-34).
            AnimatedSwitcher(
              duration: Motion.monthSlide(context),
              switchInCurve: Motion.curve,
              switchOutCurve: Motion.curve,
              transitionBuilder: (child, animation) {
                final entering =
                    (child.key as ValueKey<int>?)?.value == _monthOffset;
                // The month arriving comes from the side it was pushed from;
                // the one leaving goes the other way, so the pair reads as one
                // movement rather than two.
                final from = entering ? _direction : -_direction;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(from.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _MonthGrid(
                key: ValueKey<int>(_monthOffset),
                month: month,
                today: today,
                logs: logs,
                predicted: window,
                onEdit: _edit,
              ),
            ),
            const SizedBox(height: 16),
            // Above the legend, because it answers the question the user came
            // with. The legend explains the drawing; this says where they are.
            if (showPhases) ...<Widget>[
              PhaseStrip(position: position),
              const SizedBox(height: 16),
            ],
            NextPeriodPanel(
              result: prediction ?? const NoData(),
              dense: true,
            ),
            const SizedBox(height: 16),
            const CalendarLegend(),
            const SizedBox(height: 8),
            Text(l10n.calendarLongPressHint, style: theme.textTheme.bodySmall),
            if (window == null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.calendarNoPredictedWindow,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static CivilDate _monthStart(CivilDate date) =>
      CivilDate(date.year, date.month, 1);

  static DayLog? _entryFor(List<DayLog> logs, CivilDate date) {
    for (final log in logs) {
      if (log.date == date) return log;
    }
    return null;
  }

  /// The single most likely start date, or null when none may be claimed.
  ///
  /// Only used to anchor the follicular-luteal boundary, and it returns null in
  /// exactly the states [_predictedWindow] does. A phase named from a
  /// prediction the app has just declined to draw would be that same claim
  /// wearing a different word.
  static CivilDate? _predictedStart(PredictionResult? result) =>
      switch (result) {
        Predicted(:final prediction) => prediction.medianStart,
        InsufficientData(:final populationPrior) => populationPrior.medianStart,
        TooIrregular() ||
        LostTrack() ||
        NoData() ||
        DataInconsistent() ||
        SuppressedByCondition() ||
        null => null,
      };

  /// The 80% window, or null when no window may be shown.
  ///
  /// [TooIrregular], [LostTrack], [NoData] and [DataInconsistent] all return
  /// null on purpose: each is a state where drawing a window would be the app
  /// asserting something it has just said it cannot support.
  static CivilDateRange? _predictedWindow(PredictionResult? result) =>
      switch (result) {
        Predicted(:final prediction) => prediction.window80,
        InsufficientData(:final populationPrior) => populationPrior.window80,
        TooIrregular() ||
        LostTrack() ||
        NoData() ||
        // A recorded pregnancy is the one case here where the model has an
        // answer and it must not be drawn. Shading a predicted week onto the
        // calendar would restate, in a picture, exactly the claim the
        // SuppressedByCondition state exists to withhold.
        SuppressedByCondition() ||
        DataInconsistent() ||
        null => null,
      };
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.logs,
    required this.predicted,
    required this.onEdit,
    super.key,
  });

  final CivilDate month;
  final CivilDate today;
  final List<DayLog> logs;
  final CivilDateRange? predicted;
  final void Function(CivilDate date, DayLog? existing) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The grid grows with the text rather than clipping it. Most Flutter
    // calendar layouts break at textScaler 2.0 because the cell is a fixed
    // square; this one is measured from the text the device is actually asked
    // to render (2.4.4).
    final cellHeight = MediaQuery.textScalerOf(
      context,
    ).scale(22).clamp(48.0, 104.0);

    final daysInMonth = CivilDate.daysInMonth(month.year, month.month);
    // ISO weekday: 1 is Monday. Leading blanks put the 1st under its weekday.
    final leading = month.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = CivilDate(month.year, month.month, day);
      final entry = _entryFor(logs, date);
      cells.add(
        Expanded(
          child: DayCell(
            date: date,
            height: cellHeight,
            isToday: date == today,
            periodDayNumber: _periodDayNumber(date),
            isPredicted: predicted?.contains(date) ?? false,
            hasSymptoms: entry != null && entry.symptoms.isNotEmpty,
            hasIntercourse: entry?.intercourse != null,
            onLongPress: () => onEdit(date, entry),
          ),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7)));
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var weekday = 1; weekday <= 7; weekday++)
              Expanded(
                child: ExcludeSemantics(
                  child: Center(
                    child: Text(
                      _weekdayInitial(context, weekday),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  /// Which day of a bleeding run [date] is, or null if it is not one.
  int? _periodDayNumber(CivilDate date) {
    final entry = _entryFor(logs, date);
    if (entry == null || !entry.isBleedingDay) return null;
    var number = 1;
    var cursor = date.addDays(-1);
    while (_entryFor(logs, cursor)?.isBleedingDay ?? false) {
      number++;
      cursor = cursor.addDays(-1);
    }
    return number;
  }

  DayLog? _entryFor(List<DayLog> entries, CivilDate date) {
    for (final log in entries) {
      if (log.date == date) return log;
    }
    return null;
  }

  static String _weekdayInitial(BuildContext context, int weekday) {
    // 2026-06-01 was a Monday, so this walks Monday to Sunday whatever the
    // locale's first day happens to be.
    final date = CivilDate(2026, 6, weekday);
    return date.weekdayDayAndMonth(context).characters.first;
  }
}

/// Explains the shapes, so the encoding is legible without colour vision.
class CalendarLegend extends StatelessWidget {
  /// Creates the legend.
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: <Widget>[
        _LegendEntry(
          marker: const PeriodMarker(),
          label: l10n.calendarLegendPeriod,
        ),
        _LegendEntry(
          marker: const PredictedMarker(),
          label: l10n.calendarLegendPredicted,
        ),
        _LegendEntry(
          marker: const IntercourseMarker(),
          label: l10n.calendarLegendIntercourse,
        ),
        _LegendEntry(
          marker: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
            ),
          ),
          label: l10n.calendarLegendToday,
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.marker, required this.label});

  final Widget marker;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(child: marker),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
