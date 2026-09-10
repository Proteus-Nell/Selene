import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/theme.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/next_period_panel.dart';
import 'package:period_tracker/features/today/cycle_ring.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The top of the home screen: where you are, and when the next one is due.
///
/// Everything here restates something the app already knows — the ring is the
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
  // symptom would not have been an error — it would have been every other
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
/// does not stretch the band. Falls back to five, which is the middle of the
/// usual range, when there is nothing to go on — the ring has to be drawn from
/// something, and a wrong-looking band is better than no ring at all on a
/// screen where the numbers beside it are the real answer.
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
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.today});

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

/// The seven days around today, with a mark under the ones logged as bleeding.
///
/// Not interactive: tapping a day would be a second, worse calendar, and the
/// calendar is one tab away. What it earns its place with is the marks — a
/// glance says whether this week has been logged, which is the question the
/// screen is otherwise silent about.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today, required this.logs});

  final CivilDate today;
  final List<DayLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phases = PhaseColors.of(context);
    // Weekday 1 is Monday, so this lands on the Sunday that starts the week.
    final start = today.addDays(-(today.toLocalMidnight().weekday % 7));
    final bleeding = <CivilDate>{
      for (final log in logs)
        if (log.isBleedingDay) log.date,
    };

    return Row(
      children: <Widget>[
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _WeekDay(
              date: start.addDays(i),
              isToday: start.addDays(i) == today,
              bleeding: bleeding.contains(start.addDays(i)),
              accent: phases.menstrual,
              theme: theme,
            ),
          ),
      ],
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.isToday,
    required this.bleeding,
    required this.accent,
    required this.theme,
  });

  final CivilDate date;
  final bool isToday;
  final bool bleeding;
  final Color accent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final initial = date.weekdayInitial(context);
    final l10n = AppLocalizations.of(context);
    var label = date.weekdayDayAndMonth(context);
    if (bleeding) label = l10n.logWeekBleedingSuffix(label);
    if (isToday) label = l10n.calendarCellTodaySuffix(label);

    return Semantics(
      // One label for the whole cell, on every cell rather than only on
      // today's. Without it a screen reader reads the letter, the number and
      // the mark under them as three unrelated fragments — and it read them
      // that way on six of the seven cells, because the label used to be
      // conditional and the exclusion with it.
      label: label,
      excludeSemantics: true,
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
          const SizedBox(height: 4),
          // Reserved whether or not it is filled, so the row does not shift
          // by four pixels the moment a day is logged.
          SizedBox(
            height: 5,
            width: 5,
            child: bleeding
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The ring, and what sits in the middle of it.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.position,
    required this.prediction,
    required this.logs,
    required this.showOvulation,
    required this.namePhases,
  });

  final CyclePosition position;
  final PredictionResult? prediction;
  final List<DayLog> logs;
  final bool showOvulation;
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
    // colour was never carrying the phase anyway — the word is right there,
    // the arc is behind it and the legend is under it — so it costs nothing to
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
      // them is below it, where it has the width of the screen to wrap in —
      // text in a circle has a fixed box and a caption that grows is exactly
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

  static String _phaseLabel(AppLocalizations l10n, CyclePhase phase) =>
      switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriod,
        CyclePhase.follicular => l10n.calendarPhaseFollicular,
        CyclePhase.luteal => l10n.calendarPhaseLuteal,
      };
}

/// The two lines in the middle of the ring.
typedef _Countdown = ({String headline, String caption});

/// How far off the next period is, **always as a range**.
///
/// Derived from the 80% window and never from [Prediction.medianStart], so this
/// is the same claim the panel underneath makes, said in fewer words. A single
/// number here would be a bare date in disguise, which is the one presentation
/// `docs/PLAN.md` 6.2 rules out.
_Countdown _countdown(BuildContext context, PredictionResult? result) {
  final l10n = AppLocalizations.of(context);
  final window = switch (result) {
    Predicted(:final prediction) => prediction.window80,
    InsufficientData(:final populationPrior) => populationPrior.window80,
    _ => null,
  };
  if (window == null) {
    return (
      headline: l10n.logCountdownNothingYet,
      caption: l10n.logCountdownNothingYetCaption,
    );
  }
  final today = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(clockProvider).today();
  final from = today.daysBetween(window.start);
  final to = today.daysBetween(window.end);
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
class _PhaseNote extends StatelessWidget {
  const _PhaseNote({required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phases = PhaseColors.of(context);
    return FlatNote(
      dividerAbove: true,
      swatch: switch (phase) {
        CyclePhase.period => phases.menstrual,
        CyclePhase.follicular => phases.follicular,
        CyclePhase.luteal => phases.luteal,
      },
      title: switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriod,
        CyclePhase.follicular => l10n.calendarPhaseFollicular,
        CyclePhase.luteal => l10n.calendarPhaseLuteal,
      },
      body: switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriodExplained,
        CyclePhase.follicular => l10n.calendarPhaseFollicularExplained,
        CyclePhase.luteal => l10n.calendarPhaseLutealExplained,
      },
    );
  }
}
