/// Today hero.
///
/// The top of the home screen: a greeting, the week, the ring, and how far off
/// the next period is. Everything here restates something the app already
/// knows in words somewhere else on the screen, and the countdown in the
/// middle of the ring is always a range.
///
/// Includes:
///     - TodayHero: The whole block, in order down the screen.
///     - _bandsFor: The bands the ring and the legend are both drawn from.
///     - _typicalBleedDays: How long the user's periods usually run.
///     - _Greeting: The time of day, and today's date.
///     - _WeekStrip: The seven days around today.
///     - _WeekDay: One of those days.
///     - _Ring: The ring, and the two lines inside it.
///     - _Countdown: Those two lines.
///     - _countdown: How far off the next period is.
///     - _PhaseNote: The current phase, in one sentence, behind a tap.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/core/theme.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/next_period_panel.dart';
import 'package:period_tracker/features/today/cycle_ring.dart';
import 'package:period_tracker/features/today/day_sheet.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Today hero: where you are, and when the next one is due.
///
/// Everything here restates something the app already knows. The ring is the
/// phase lengths, the middle is the day of the cycle, the panel beneath is the
/// prediction in the one shape `docs/PLAN.md` 6.2 allows it. Nothing on this
/// screen is a claim that is not made in words somewhere on it.
///
/// The prediction is deliberately rendered by [NextPeriodPanel] rather than
/// re-laid-out here. That widget exists because the everyday way 6.2 erodes is
/// a second screen presenting "the same thing" a little more confidently, and a
/// home screen is exactly where that happens. The countdown in the middle of
/// the ring is derived from the same 80% window and is **always a range**, so
/// it is that window said differently rather than a firmer claim.
class TodayHero extends ConsumerWidget {
  /// Creates the hero.
  const TodayHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider).today();
    final logs = ref.watch(dayLogsProvider).valueOrNull ?? const <DayLog>[];
    final prediction = ref.watch(predictionProvider).valueOrNull;
    // Defaults to hidden while the preference loads, and the default is a
    // safety property: `docs/PLAN.md` 6.2 requires ovulation estimation to be
    // opted into, so erring the other way for a single frame would show it to
    // someone who never asked (ADR-0007).
    final showOvulation =
        ref.watch(showOvulationWindowProvider).valueOrNull ?? false;
    final namePhases = ref.watch(showCyclePhasesProvider).valueOrNull ?? true;

    final predictedStart = switch (prediction) {
      Predicted(:final prediction) => prediction.medianStart,
      _ => null,
    };
    final position = CyclePhases.on(
      date: today,
      logs: logs,
      predictedStart: predictedStart,
      withOvulationEstimate: showOvulation,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Greeting(today: today),
        const SizedBox(height: 14),
        _WeekStrip(today: today, logs: logs),
        const SizedBox(height: 18),
        Center(
          child: _Ring(
            position: position,
            prediction: prediction,
            logs: logs,
            showOvulation: showOvulation,
            namePhases: namePhases,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _countdown(context, prediction).caption,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (prediction != null)
          NextPeriodPanel(result: prediction, dense: true),
        const SizedBox(height: 14),
        Center(
          child: RingLegend(
            bands: _bandsFor(
              context: context,
              logs: logs,
              prediction: prediction,
              showOvulation: showOvulation,
            ),
          ),
        ),
        if (namePhases && position.phase != null)
          _PhaseNote(phase: position.phase!),
      ],
    );
  }
}

/// The bands the ring and its legend are both drawn from.
///
/// Built once and passed to both, so a legend can never name a band the ring
/// does not have. Lengths come from the user's own cycles where there are
/// enough of them and from the model's median otherwise; the luteal length is
/// the fixed figure [CyclePhases.lutealPhaseDays], which is what the phase
/// boundary is defined by in the first place.
///
/// Args:
///     context (BuildContext): For the translations and the phase colours.
///     logs (`List<DayLog>`): Every day the user has logged.
///     prediction (PredictionResult?): The model's current belief, read for
///         the median cycle length. Null falls back to 28 days.
///     showOvulation (bool): Whether the user has opted into the estimate.
///
/// Returns:
///     `List<RingBand>`: Four bands in cycle order: period, follicular,
///     ovular, luteal. The ovular band is zero days when the estimate is off,
///     which the ring and the legend both read as "do not draw, do not name".
List<RingBand> _bandsFor({
  required BuildContext context,
  required List<DayLog> logs,
  required PredictionResult? prediction,
  required bool showOvulation,
}) {
  final l10n = AppLocalizations.of(context);
  final phases = PhaseColors.of(context);

  final cycleLength = switch (prediction) {
    Predicted(:final prediction) => prediction.basis.medianLengthDays,
    InsufficientData(:final populationPrior) =>
      populationPrior.basis.medianLengthDays,
    _ => 28.0,
  };
  final bleedDays = _typicalBleedDays(logs);
  final luteal = CyclePhases.lutealPhaseDays.toDouble();
  // The days between the end of bleeding and the luteal boundary. Everything
  // below is carved out of this, never added to it.
  final betweenPhases = (cycleLength - bleedDays - luteal).clamp(
    0.0,
    cycleLength,
  );
  // The ovulation band is a slice of the follicular phase rather than an extra
  // one, so turning it on cannot make the ring add up to more than a cycle.
  //
  // Bounded by what is actually there, which is not a formality: a 21-day
  // cycle with a 7-day period leaves nothing between a period and a 14-day
  // luteal phase, and a fixed five-day band would have been five days the
  // cycle does not contain. The ring normalises by its own total, so the
  // symptom would not have been an error. It would have been every other
  // band silently shrinking the moment the estimate was switched on.
  final ovular = showOvulation
      ? (CyclePhases.ovulationSpreadDays * 2 + 1).toDouble().clamp(
          0.0,
          betweenPhases,
        )
      : 0.0;
  final follicular = betweenPhases - ovular;

  return <RingBand>[
    RingBand(
      days: bleedDays,
      color: phases.menstrual,
      label: l10n.calendarPhasePeriod,
    ),
    RingBand(
      days: follicular,
      color: phases.follicular,
      label: l10n.calendarPhaseFollicular,
    ),
    RingBand(
      days: ovular,
      color: phases.ovular,
      label: l10n.logLegendOvulation,
    ),
    RingBand(
      days: luteal,
      color: phases.luteal,
      label: l10n.calendarPhaseLuteal,
    ),
  ];
}

/// How many days the user's periods usually run, from their own logs.
///
/// The median of the completed runs rather than the mean, so one long month
/// does not stretch the band.
///
/// Args:
///     logs (`List<DayLog>`): Every day the user has logged.
///
/// Returns:
///     double: The median run length, clamped to 1 to 12 days. Five when
///     there is nothing to go on: the ring has to be drawn from something,
///     and a wrong-looking band is better than no ring at all on a screen
///     where the numbers beside it are the real answer.
double _typicalBleedDays(List<DayLog> logs) {
  final bleeding = logs.where((log) => log.isBleedingDay).toList();
  if (bleeding.isEmpty) return 5;
  final runs = <int>[];
  var run = 1;
  for (var i = 1; i < bleeding.length; i++) {
    if (bleeding[i - 1].date.daysBetween(bleeding[i].date) <= 1) {
      run++;
    } else {
      runs.add(run);
      run = 1;
    }
  }
  runs
    ..add(run)
    ..sort();
  final middle = runs[runs.length ~/ 2].toDouble();
  return middle.clamp(1, 12);
}

/// "Good morning", and today's date under it.
///
/// Attributes:
///     today (CivilDate): The day to print.
class _Greeting extends ConsumerWidget {
  /// Creates the greeting.
  ///
  /// Args:
  ///     today (CivilDate): The day to print. The greeting itself is chosen
  ///         from the hour, which is read from the clock provider rather than
  ///         passed in, so it is frozen under test with everything else.
  const _Greeting({required this.today});

  /// The day to print.
  final CivilDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hour = ref.watch(clockProvider).nowUtc().toLocal().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => l10n.logGreetingMorning,
      >= 12 && < 18 => l10n.logGreetingAfternoon,
      _ => l10n.logGreetingEvening,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          greeting,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          today.full(context),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A week of dates, with marks under the days that have something logged.
///
/// It opens on the week today is in, steps a week per swipe, and opens a day
/// when one is tapped (ADR-0027). What it earns its place with is the marks: a
/// glance says whether a week has been logged, which is the question the
/// screen is otherwise silent about. A dot is a bleeding day, and the
/// calendar's open heart is a day intercourse was recorded on (ADR-0028).
///
/// Attributes:
///     today (CivilDate): The day the week is built around.
///     logs (`List<DayLog>`): Every day the user has logged.
class _WeekStrip extends StatefulWidget {
  /// Creates the strip.
  ///
  /// Args:
  ///     today (CivilDate): The day the week is built around. The strip runs
  ///         from the Sunday of that week, not from today.
  ///     logs (`List<DayLog>`): Every day the user has logged. Only whether
  ///         a day was a bleeding day, and whether intercourse was recorded on
  ///         it, reach the marks.
  const _WeekStrip({required this.today, required this.logs});

  /// The day the week is built around.
  final CivilDate today;

  /// Every day the user has logged.
  final List<DayLog> logs;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

/// State for [_WeekStrip]: which week is on screen.
///
/// The strip moves a whole week per swipe, in either direction, without limit.
/// Unbounded on purpose: the weeks before the first logged day are empty rather
/// than absent, and a strip that stopped at some particular Sunday would be
/// asserting a rule the app does not have. That is also why [_backToToday]
/// exists: with no end to reach, the way back has to be a control.
///
/// A drag and an [AnimatedSwitcher], not a `PageView`, which is how the
/// calendar steps months. A PageView is the obvious choice and the wrong one
/// here: it puts a second [Scrollable] inside the screen's own scroll view,
/// and it needs a fixed cross-axis height, which overflowed at the 200% text
/// scale `docs/PLAN.md` 2.4.4 requires. Stepping a whole week needs neither.
///
/// The row also moves under the finger while it is dragged (ADR-0028), by
/// less than the finger does, so a swipe is answered before the week changes.
/// That is all the drag adds: the week arriving is still brought in by the
/// switcher once the finger lifts, and a drag that was not a swipe lets the
/// row settle back where it was.
///
/// Attributes:
///     _offset (int): Weeks away from today's week, negative into the past.
///     _direction (int): Which way the last step went, so the week arriving
///         comes from the side it was pushed from.
///     _pull (double): How far the drag in progress has travelled.
///     _dragging (bool): Whether a finger is on the row.
class _WeekStripState extends State<_WeekStrip> {
  /// Weeks away from today's week, negative into the past.
  int _offset = 0;

  /// Which way the last step went, positive forward.
  int _direction = 1;

  /// How far the drag in progress has travelled, in logical pixels.
  ///
  /// Negative towards the next week, and zero whenever no finger is down.
  double _pull = 0;

  /// Whether a finger is on the row.
  ///
  /// While one is, the row is placed frame for frame rather than eased, since
  /// easing towards a finger that is still moving reads as lag.
  bool _dragging = false;

  /// How fast a horizontal fling has to be to count as a swipe.
  ///
  /// Below this the finger is resting rather than flicking, and the week stays
  /// where it is. In logical pixels per second.
  static const double _flingVelocity = 120;

  /// How far a drag has to travel to change the week without a flick.
  ///
  /// The row follows the finger, so a slow, deliberate drag that sprang back
  /// would read as the app refusing it. A cell is about this wide, which keeps
  /// a finger that wandered while pressing a date from turning the week. In
  /// logical pixels of finger travel once the drag has begun, not of row
  /// travel.
  static const double _commitDistance = 48;

  /// The furthest the row moves under a drag, however far the finger goes.
  ///
  /// In logical pixels. Small on purpose: the week arriving is not on screen
  /// until the finger lifts, so a row that travelled with the finger would
  /// uncover an empty space where the next week should be.
  static const double _pullLimit = 28;

  /// How much of the finger's first movement the row takes up.
  static const double _pullGain = 0.55;

  /// Return how far the row sits from rest for a drag of [pull].
  ///
  /// travel = limit * gain * |pull| / (gain * |pull| + limit)
  ///
  /// A little over half the finger's travel to begin with, flattening towards
  /// [_pullLimit] without reaching it, so the row never stops dead under a
  /// finger that is still moving.
  ///
  /// Args:
  ///     pull (double): The finger's travel, negative towards the next week.
  ///
  /// Returns:
  ///     double: The row's offset in logical pixels, with the sign of [pull].
  static double _travelFor(double pull) {
    final taken = pull.abs() * _pullGain;
    return pull.sign * _pullLimit * taken / (taken + _pullLimit);
  }

  /// Move the strip by whole weeks.
  ///
  /// Args:
  ///     by (int): How many weeks, positive forward. The sign is kept as
  ///         [_direction] so the transition leaves the way it was pushed.
  void _stepWeek(int by) {
    setState(() {
      _direction = by;
      _offset += by;
      // The week leaving keeps the place the finger left it in, because the
      // switcher holds the widget it was last built with. The one arriving
      // starts at rest.
      _pull = 0;
      _dragging = false;
    });
    _announce(_offset);
  }

  /// Step back to the week today is in.
  void _backToToday() {
    if (_offset == 0) return;
    setState(() {
      _direction = _offset > 0 ? -1 : 1;
      _offset = 0;
      _pull = 0;
      _dragging = false;
    });
    _announce(0);
  }

  /// End a drag: change the week if it was a swipe, and let the row go.
  ///
  /// Args:
  ///     velocity (double): How fast the finger left, in logical pixels per
  ///         second, negative towards the next week.
  void _release(double velocity) {
    // The flick is read first because it is the later intent: a row dragged
    // one way and flicked back the other was being put back.
    final int by;
    if (velocity <= -_flingVelocity) {
      by = 1;
    } else if (velocity >= _flingVelocity) {
      by = -1;
    } else if (_pull <= -_commitDistance) {
      by = 1;
    } else if (_pull >= _commitDistance) {
      by = -1;
    } else {
      by = 0;
    }
    if (by != 0) {
      _stepWeek(by);
      return;
    }
    setState(() {
      _pull = 0;
      _dragging = false;
    });
  }

  /// Say which week is now on screen.
  ///
  /// The week is the one thing here a screen reader cannot infer from what it
  /// is about to read: the same seven cells, with different dates in them.
  ///
  /// Args:
  ///     offset (int): The week now showing, as weeks from today's.
  void _announce(int offset) {
    if (!mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(
          context,
        ).logWeekOf(_sundayFor(offset).dayAndMonth(context)),
        Directionality.of(context),
      ),
    );
  }

  /// The Sunday that starts the week [offset] weeks from today's.
  ///
  /// Args:
  ///     offset (int): Weeks from today's week, negative into the past.
  ///
  /// Returns:
  ///     CivilDate: That week's Sunday.
  CivilDate _sundayFor(int offset) {
    // Weekday 1 is Monday, so this lands on the Sunday that starts the week.
    final thisWeek = widget.today.addDays(
      -(widget.today.toLocalMidnight().weekday % 7),
    );
    return thisWeek.addDays(offset * 7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final phases = PhaseColors.of(context);
    final start = _sundayFor(_offset);
    final bleeding = <CivilDate>{
      for (final log in widget.logs)
        if (log.isBleedingDay) log.date,
    };
    // Whether, never which answer: the mark is the calendar's, and says only
    // that something was recorded (ADR-0028).
    final intercourse = <CivilDate>{
      for (final log in widget.logs)
        if (log.intercourse != null) log.date,
    };
    // Following a finger is motion like any other, so it goes with the rest
    // when the device asks for none. The swipe still turns the week.
    final travel = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : _travelFor(_pull);
    // Only once the strip has left this week, so nothing is added to the
    // screen in the state it is almost always in.
    final Widget wayBack = _offset == 0
        ? const SizedBox(width: double.infinity)
        : Align(
            child: TextButton.icon(
              onPressed: _backToToday,
              icon: const Icon(Icons.today_outlined, size: 18),
              label: Text(l10n.logWeekBackToToday),
            ),
          );
    final grow = Motion.monthSlide(context);

    return Column(
      children: <Widget>[
        // A drag is a gesture, and a gesture is not an action: assistive
        // technology cannot perform one, so without these the week could not
        // be changed with a screen reader at all, and "Back to today" is no
        // way out because it only appears once the strip has already moved.
        // A `PageView` would have published its own scroll actions; this has
        // to publish them itself.
        Semantics(
          container: true,
          // Value, not label: increase and decrease move between values, and
          // the framework asserts that an action which changes a value comes
          // with the value it changes and the one it changes to.
          value: l10n.logWeekOf(start.dayAndMonth(context)),
          increasedValue: l10n.logWeekOf(
            start.addDays(7).dayAndMonth(context),
          ),
          decreasedValue: l10n.logWeekOf(
            start.addDays(-7).dayAndMonth(context),
          ),
          onIncrease: () => _stepWeek(1),
          onDecrease: () => _stepWeek(-1),
          child: GestureDetector(
            // Horizontal only, so the screen's vertical scroll is untouched: a
            // vertical drag never reaches this recogniser.
            onHorizontalDragUpdate: (details) => setState(() {
              _dragging = true;
              _pull += details.delta.dx;
            }),
            onHorizontalDragEnd: (details) =>
                _release(details.velocity.pixelsPerSecond.dx),
            child: AnimatedSwitcher(
              duration: Motion.monthSlide(context),
              switchInCurve: Motion.curve,
              switchOutCurve: Motion.curve,
              transitionBuilder: (child, animation) {
                final entering =
                    (child.key as ValueKey<int>?)?.value == _offset;
                // As the calendar's months do: the week arriving comes from the
                // side it was pushed from and the one leaving goes the other
                // way, so the pair reads as one movement.
                final from = entering ? _direction : -_direction;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(from.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    // The week on its way out keeps its cells until the
                    // transition ends, and a fade does not stop them being hit:
                    // without this there are fourteen tappable dates in seven
                    // columns for 180ms, and a tap can open a day a week away
                    // from the one under the finger.
                    child: IgnorePointer(ignoring: !entering, child: child),
                  ),
                );
              },
              // The key is on the week's outermost widget, which is what the
              // switcher compares, and the offset rides inside it so the week
              // leaving keeps the place it was dragged to.
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_offset),
                tween: Tween<double>(end: travel),
                // Placed, not eased, while the finger is down; eased only on
                // the way back to rest from a drag that was not a swipe.
                duration: _dragging ? Duration.zero : Motion.quick(context),
                curve: Motion.curve,
                builder: (context, dx, week) =>
                    Transform.translate(offset: Offset(dx, 0), child: week),
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _WeekDay(
                          date: start.addDays(i),
                          isToday: start.addDays(i) == widget.today,
                          bleeding: bleeding.contains(start.addDays(i)),
                          hasIntercourse: intercourse.contains(
                            start.addDays(i),
                          ),
                          accent: phases.menstrual,
                          theme: theme,
                          onTap: () => showDaySheet(context, start.addDays(i)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // No AnimatedSize at all with animations off, rather than one given a
        // zero duration. Its render object restarts its controller during
        // layout, a run of no length completes on the spot, and the listener
        // that marks it for layout then fires inside the layout it is in. The
        // framework asserts on that, and did so on every swipe away from this
        // week with "remove animations" on.
        if (grow == Duration.zero)
          wayBack
        else
          AnimatedSize(duration: grow, curve: Motion.curve, child: wayBack),
      ],
    );
  }
}

/// One day of the week strip: an initial, a number, and the marks under it.
///
/// Attributes:
///     date (CivilDate): The day this cell shows.
///     isToday (bool): Whether it is the current day.
///     bleeding (bool): Whether it was logged as a bleeding day.
///     hasIntercourse (bool): Whether intercourse was recorded on it.
///     accent (Color): The colour of the bleeding mark.
///     theme (ThemeData): The theme, resolved once by the strip.
///     onTap (VoidCallback): Opens this day.
class _WeekDay extends StatelessWidget {
  /// Creates one day of the strip.
  ///
  /// Args:
  ///     date (CivilDate): The day this cell shows.
  ///     isToday (bool): Whether it is the current day, which fills the
  ///         number's circle.
  ///     bleeding (bool): Whether it was logged as a bleeding day, which
  ///         puts a dot beneath.
  ///     hasIntercourse (bool): Whether intercourse was recorded, which puts
  ///         the calendar's open heart beneath. Not which answer was given.
  ///     accent (Color): The colour of the dot.
  ///     theme (ThemeData): The theme. Resolved once by the strip and passed
  ///         down rather than read seven times.
  ///     onTap (VoidCallback): Opens this day.
  const _WeekDay({
    required this.date,
    required this.isToday,
    required this.bleeding,
    required this.hasIntercourse,
    required this.accent,
    required this.theme,
    required this.onTap,
  });

  /// The day this cell shows.
  final CivilDate date;

  /// Whether it is the current day.
  final bool isToday;

  /// Whether it was logged as a bleeding day.
  final bool bleeding;

  /// Whether intercourse was recorded. Not which answer.
  final bool hasIntercourse;

  /// The colour of the dot beneath a bleeding day's number.
  final Color accent;

  /// The theme, resolved once by the strip.
  final ThemeData theme;

  /// Opens this day.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final initial = date.weekdayInitial(context);
    final l10n = AppLocalizations.of(context);
    var label = date.weekdayDayAndMonth(context);
    if (bleeding) label = l10n.logWeekBleedingSuffix(label);
    // "Intercourse logged", never which answer, in the calendar's own words:
    // a screen reader is audible to whoever is in the room.
    if (hasIntercourse) label = l10n.calendarCellIntercourseSuffix(label);
    if (isToday) label = l10n.calendarCellTodaySuffix(label);

    return Semantics(
      // One label for the whole cell, on every cell rather than only on
      // today's. Without it a screen reader reads the letter, the number and
      // the mark under them as three unrelated fragments, and it read them
      // that way on six of the seven cells, because the label used to be
      // conditional and the exclusion with it.
      label: label,
      button: true,
      excludeSemantics: true,
      // The whole cell, not the number inside it: a 30px circle is under the
      // 48dp the accessibility gate requires (`docs/PLAN.md` 2.4.4), and the
      // cell is as wide as a seventh of the screen.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: <Widget>[
            Text(
              initial,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? scheme.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                date.dayNumber(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isToday ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // Nine pixels whether or not anything is in them, so the row does
            // not shift the moment a day is logged, and the same nine it has
            // always had: four clear and a five-pixel dot. The heart is nine
            // tall and takes all of it. Marks sit on the bottom edge, so the
            // dots of a week stay on one line whichever days carry a heart.
            SizedBox(
              height: 9,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (bleeding)
                    SizedBox(
                      height: 5,
                      width: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (bleeding && hasIntercourse) const SizedBox(width: 3),
                  if (hasIntercourse) const IntercourseMarker(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ring, and what sits in the middle of it.
///
/// Attributes:
///     position (CyclePosition): Where today falls in the cycle.
///     prediction (PredictionResult?): The model's current belief.
///     logs (`List<DayLog>`): Every day the user has logged.
///     showOvulation (bool): Whether the estimate was opted into.
///     namePhases (bool): Whether the phase may be named.
class _Ring extends StatelessWidget {
  /// Creates the ring and its middle.
  ///
  /// Args:
  ///     position (CyclePosition): Where today falls in the cycle.
  ///     prediction (PredictionResult?): The model's current belief, used for
  ///         the band lengths and the countdown.
  ///     logs (`List<DayLog>`): Every day the user has logged.
  ///     showOvulation (bool): Whether the user opted into the estimate. It
  ///         reaches the bands only, never the countdown.
  ///     namePhases (bool): Whether the phase may be named in the middle.
  ///         False leaves the day of the cycle there on its own.
  const _Ring({
    required this.position,
    required this.prediction,
    required this.logs,
    required this.showOvulation,
    required this.namePhases,
  });

  /// Where today falls in the cycle.
  final CyclePosition position;

  /// The model's current belief.
  final PredictionResult? prediction;

  /// Every day the user has logged.
  final List<DayLog> logs;

  /// Whether the ovulation estimate was opted into.
  final bool showOvulation;

  /// Whether the phase may be named in the middle.
  final bool namePhases;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bands = _bandsFor(
      context: context,
      logs: logs,
      prediction: prediction,
      showOvulation: showOvulation,
    );

    final day = position.dayOfCycle;
    final phase = namePhases ? position.phase : null;
    final phaseLine = switch ((phase, day)) {
      (final CyclePhase p, final int d) => l10n.logPhaseAndDay(
        _phaseLabel(l10n, p),
        d,
      ),
      (null, final int d) => l10n.logDayOfCycleShort(d),
      _ => null,
    };
    // Deliberately *not* the phase colour. The phase colours are graphical
    // marks and are gated at 3:1; this is small bold text and needs 4.5, and
    // Rose & Plum's follicular pink lands at 3.51 against its surface. The
    // colour was never carrying the phase anyway. The word is right there,
    // the arc is behind it and the legend is under it, so it costs nothing to
    // paint this in a colour that is gated for text everywhere.
    final labelColor = theme.colorScheme.primary;

    final countdown = _countdown(context, prediction);

    return CycleRing(
      bands: bands,
      semanticsLabel: l10n.logRingLabel(
        <String>[
          ?phaseLine,
          '${countdown.headline} ${countdown.caption}',
        ].join('. '),
      ),
      // Only two short lines sit inside the circle. The sentence that explains
      // them is below it, where it has the width of the screen to wrap in.
      // Text in a circle has a fixed box, and a caption that grows is exactly
      // what makes one overflow.
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (phaseLine != null)
              Text(
                phaseLine.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              countdown.headline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Return the name of a phase.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     phase (CyclePhase): The phase to name.
  ///
  /// Returns:
  ///     String: The phase's name, in the user's language.
  static String _phaseLabel(AppLocalizations l10n, CyclePhase phase) =>
      switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriod,
        CyclePhase.follicular => l10n.calendarPhaseFollicular,
        CyclePhase.luteal => l10n.calendarPhaseLuteal,
      };
}

/// The two lines in the middle of the ring: a headline and its caption.
typedef _Countdown = ({String headline, String caption});

/// How far off the next period is, **always as a range**.
///
/// Derived from the 80% window and never from [Prediction.medianStart], so this
/// is the same claim the panel underneath makes, said in fewer words. A single
/// number here would be a bare date in disguise, which is the one presentation
/// `docs/PLAN.md` 6.2 rules out.
///
/// Measured against the window the period was first expected in, not the one
/// moved forward once it is late: a moved window always starts today or later,
/// so counting from it would say "any day now" for as long as the period
/// stayed away, which is the very thing ADR-0016 fixes.
///
/// Args:
///     context (BuildContext): For the translations and the clock.
///     result (PredictionResult?): The model's current belief.
///
/// Returns:
///     _Countdown: The two lines. A range of days before the window opens,
///     "any day now" inside it, "later than expected" past it, and for every
///     state with no window, what that state is in a few words.
_Countdown _countdown(BuildContext context, PredictionResult? result) {
  final l10n = AppLocalizations.of(context);
  final Prediction prediction;
  switch (result) {
    case Predicted(prediction: final shown) ||
        InsufficientData(populationPrior: final shown):
      prediction = shown;
    case LaterThanExpected(:final daysLate):
      return (
        headline: l10n.logCountdownLater,
        caption: l10n.logCountdownLaterCaption(daysLate),
      );
    case LostTrack():
      return (
        headline: l10n.logCountdownLostTrack,
        caption: l10n.logCountdownLostTrackCaption,
      );
    case TooIrregular():
      return (
        headline: l10n.logCountdownNoRange,
        caption: l10n.logCountdownNoRangeCaption,
      );
    case SuppressedByCondition():
      return (
        headline: l10n.logCountdownPaused,
        caption: l10n.logCountdownPausedCaption,
      );
    case DataInconsistent():
      return (
        headline: l10n.logCountdownCheckDates,
        caption: l10n.logCountdownCheckDatesCaption,
      );
    case NoData() || null:
      return (
        headline: l10n.logCountdownNothingYet,
        caption: l10n.logCountdownNothingYetCaption,
      );
  }
  final window = prediction.expectedWindow80;
  final today = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(clockProvider).today();
  final from = today.daysBetween(window.start);
  final to = today.daysBetween(window.end);
  if (to < 0) {
    return (
      headline: l10n.logCountdownLater,
      caption: l10n.logCountdownLaterCaption(-to),
    );
  }
  if (from <= 0) {
    return (
      headline: l10n.logCountdownNow,
      caption: l10n.logCountdownNowCaption,
    );
  }
  return (
    headline: l10n.logCountdownRange(from, to),
    caption: l10n.logCountdownCaption,
  );
}

/// What the current phase is, in one sentence, flat on the page.
///
/// Attributes:
///     phase (CyclePhase): The phase to name and explain.
class _PhaseNote extends StatelessWidget {
  /// Creates the note.
  ///
  /// Args:
  ///     phase (CyclePhase): The phase to name. Its explanation is one tap
  ///         away rather than printed here.
  const _PhaseNote({required this.phase});

  /// The phase to name and explain.
  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phases = PhaseColors.of(context);
    final label = _label(l10n, phase);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          InkWell(
            onTap: () => _explain(context, phase),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTheme.minTapTarget,
              ),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: switch (phase) {
                          CyclePhase.period => phases.menstrual,
                          CyclePhase.follicular => phases.follicular,
                          CyclePhase.luteal => phases.luteal,
                        },
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleSmall),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open the one-sentence explanation.
  ///
  /// Behind a tap rather than printed under the name, because the sentence is
  /// the same on every visit and the screen underneath it is the one somebody
  /// opened the app to use. The calendar already explains a phase this way, so
  /// this is the second place the gesture means the same thing rather than a
  /// second way of saying it.
  ///
  /// Args:
  ///     context (BuildContext): What to show the dialog over.
  ///     phase (CyclePhase): The phase to explain.
  ///
  /// Returns:
  ///     `Future<void>`: Completes when the dialog is closed.
  Future<void> _explain(BuildContext context, CyclePhase phase) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Scrollable, so a large text scale shrinks the dialog to fit rather
        // than overflowing it past the top of the screen and under a cutout.
        scrollable: true,
        title: Text(_label(l10n, phase)),
        content: Text(switch (phase) {
          CyclePhase.period => l10n.calendarPhasePeriodExplained,
          CyclePhase.follicular => l10n.calendarPhaseFollicularExplained,
          CyclePhase.luteal => l10n.calendarPhaseLutealExplained,
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  /// Return the name of a phase.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     phase (CyclePhase): The phase to name.
  ///
  /// Returns:
  ///     String: The phase's name, in the user's language.
  static String _label(AppLocalizations l10n, CyclePhase phase) =>
      switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriod,
        CyclePhase.follicular => l10n.calendarPhaseFollicular,
        CyclePhase.luteal => l10n.calendarPhaseLuteal,
      };
}
