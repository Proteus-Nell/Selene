/// One day, opened from the Today tab's date row.
///
/// A past day opens locked (ADR-0027): what was recorded is shown as text, and
/// the editor is not built at all until the lock is lifted. Locked means
/// locked, rather than an editor behind a dimmed layer: a control that is on
/// screen and inert is still reachable by a screen reader, and `IgnorePointer`
/// does not take its actions away.
///
/// Today opens straight into the editor, because the Today tab is where today
/// is logged and asking about the day the screen is named after would be
/// noise. A future day opens into neither: `CycleRepository` refuses a
/// future-dated write, so offering an editor would be offering a control whose
/// every use fails.
///
/// Includes:
///     - showDaySheet: Opens the sheet for one date.
///     - _DaySheet: One day, locked or not.
///     - _DaySheetState: Whether the lock has been lifted on this sheet.
///     - _LockBar: The lock, and the two ways past it.
///     - _StandDownNote: That the lock is standing down, and until when.
///     - _DaySummary: What was recorded, as text.
///     - _Line: One labelled line of that summary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/temperature.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/log_labels.dart';
import 'package:period_tracker/features/log/day_editor.dart';
import 'package:period_tracker/features/today/past_edit_guard.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Open the sheet for [date].
///
/// Args:
///     context (BuildContext): What to show the sheet over.
///     date (CivilDate): The day to open.
///
/// Returns:
///     `Future<void>`: Completes when the sheet closes. The editor writes as
///     it goes, so there is nothing to collect.
Future<void> showDaySheet(BuildContext context, CivilDate date) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // As the calendar's sheet does: the route has to be kept inside the
      // cutout, and a SafeArea inside the sheet is too late because the route
      // has already claimed the full height.
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _DaySheet(date: date),
    );

/// The sheet for one day.
///
/// Attributes:
///     date (CivilDate): The day being shown.
class _DaySheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const _DaySheet({required this.date});

  /// The day being shown.
  final CivilDate date;

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

/// State for [_DaySheet]: whether the user has lifted the lock.
///
/// Held here rather than in the guard, so unlocking one day does not unlock
/// the next one opened. The guard decides whether a lock is needed at all;
/// this remembers that it was answered for this sheet.
///
/// Attributes:
///     _unlocked (bool): Whether the editor has been asked for.
class _DaySheetState extends ConsumerState<_DaySheet> {
  /// Whether the user has lifted the lock on this sheet.
  bool _unlocked = false;

  /// Lift the lock, and count the day towards the bulk-edit offer.
  ///
  /// The count is of days unlocked rather than of writes that followed,
  /// because the unlock is the friction the stand-down exists to relieve: a
  /// user who opens four days to correct them has met it four times whether or
  /// not the fourth needed a change in the end.
  ///
  /// Says nothing: the editor appearing where the summary was is the whole
  /// confirmation, and a message about it would have nowhere to go. A snack
  /// bar belongs to the ScaffoldMessenger below this route and renders behind
  /// the sheet, which is why the note the stand-down needs is drawn inside the
  /// sheet instead.
  void _unlock() {
    final now = ref.read(clockProvider).nowUtc();
    final guard = ref.read(pastEditGuardProvider.notifier);
    guard.state = guard.state.changed(widget.date, now);
    setState(() => _unlocked = true);
  }

  /// Stand the lock down for half an hour.
  ///
  /// The half hour is said by [_StandDownNote], which stays on screen for as
  /// long as it lasts rather than for as long as a snack bar would.
  void _standDown() {
    final now = ref.read(clockProvider).nowUtc();
    final guard = ref.read(pastEditGuardProvider.notifier);
    guard.state = guard.state.standingDownFrom(now);
    setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final clock = ref.watch(clockProvider);
    final today = clock.today();
    final logs = ref.watch(dayLogsProvider).valueOrNull ?? const <DayLog>[];
    final existing = logs.where((log) => log.date == widget.date).firstOrNull;
    final guard = ref.watch(pastEditGuardProvider);
    final now = clock.nowUtc();

    final isFuture = widget.date.epochDay > today.epochDay;
    final locked =
        !_unlocked && guard.locks(widget.date, today: today, now: now);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.date.full(context),
                        style: theme.textTheme.titleLarge,
                      ),
                      if (!isFuture && widget.date != today)
                        Text(
                          l10n.logDayRelativeDaysAgo(
                            today.epochDay - widget.date.epochDay,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonClose),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isFuture)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.logDayFutureUnrecordable,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...<Widget>[
              if (locked)
                _LockBar(
                  offersStandDown: guard.offersStandDown(now),
                  onUnlock: _unlock,
                  onStandDown: _standDown,
                )
              // Drawn whenever the stand-down is in force, not only on the
              // sheet that asked for it: it is the only place the half hour is
              // stated, and it answers the question the missing lock raises on
              // every past day opened until it expires.
              else if (guard.standingDown(now))
                _StandDownNote(until: guard.standDownUntil!),
              Flexible(
                child: SingleChildScrollView(
                  child: locked
                      ? _DaySummary(log: existing)
                      : DayEditor(date: widget.date, existing: existing),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The lock on a past day, and the two ways past it.
///
/// Says what changing a past day does rather than asking whether the user
/// means it: the button beside it is the question, and a dialog asking the
/// same thing in other words would be two questions for one answer.
///
/// Attributes:
///     offersStandDown (bool): Whether to offer the half hour.
///     onUnlock (VoidCallback): Lifts the lock for this day.
///     onStandDown (VoidCallback): Lifts it for half an hour.
class _LockBar extends StatelessWidget {
  /// Creates the bar.
  ///
  /// Args:
  ///     offersStandDown (bool): Whether more than three days have been
  ///         changed inside ten minutes, which is the only time the half hour
  ///         is offered.
  ///     onUnlock (VoidCallback): Lifts the lock for this day only.
  ///     onStandDown (VoidCallback): Lifts it for half an hour.
  const _LockBar({
    required this.offersStandDown,
    required this.onUnlock,
    required this.onStandDown,
  });

  /// Whether to offer the half hour.
  final bool offersStandDown;

  /// Lifts the lock for this day.
  final VoidCallback onUnlock;

  /// Lifts the lock for half an hour.
  final VoidCallback onStandDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.logDayLockedTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onUnlock, child: Text(l10n.logDayUnlock)),
            ],
          ),
          // Only once the user has shown they are working through days rather
          // than fixing one, and never as a permanent setting: half an hour,
          // then the lock is back without being asked for.
          if (offersStandDown)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onStandDown,
                child: Text(l10n.logDayStandDown),
              ),
            ),
        ],
      ),
    );
  }
}

/// Says the lock is standing down, and until when.
///
/// Inside the sheet rather than in a snack bar, which would belong to the
/// ScaffoldMessenger below this route and render behind it. It is also the
/// only statement of the half hour anywhere, so it has to survive longer than
/// a snack bar would: it is drawn on every past day opened until the
/// stand-down expires.
///
/// Attributes:
///     until (DateTime): When the lock comes back, as a UTC instant.
class _StandDownNote extends StatelessWidget {
  /// Creates the note.
  ///
  /// Args:
  ///     until (DateTime): When the lock comes back, as a UTC instant. Shown
  ///         as a local clock time.
  const _StandDownNote({required this.until});

  /// When the lock comes back, as a UTC instant.
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.lock_open_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.logDayStandDownDone(
                TimeOfDay.fromDateTime(until.toLocal()).format(context),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What was recorded for a day, as text.
///
/// Read-only by construction rather than by being disabled, which is what
/// makes the lock a lock. Intercourse is listed with everything else, at the
/// owner's direction.
///
/// A consumer, because two display preferences decide how the same stored
/// values are *said*, and the editor one tap away honours both: a temperature
/// is shown in the unit the user reads, and flow is named by intensity only
/// where they have not simplified it to bleeding or not. Saying it differently
/// here would read as the app having changed its mind about what it recorded.
///
/// Attributes:
///     log (DayLog?): The day's entry, or null when nothing is recorded.
class _DaySummary extends ConsumerWidget {
  /// Creates the summary.
  ///
  /// Args:
  ///     log (DayLog?): The entry to describe, or null for a day with none.
  const _DaySummary({required this.log});

  /// The day's entry, or null when nothing is recorded.
  final DayLog? log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entry = log;
    if (entry == null || entry.isEmpty) {
      return Text(
        l10n.logDayNothingRecorded,
        style: theme.textTheme.bodyMedium,
      );
    }

    // Both default to the unsimplified, Celsius reading while the preference
    // loads, which is what the editor defaults to as well.
    final simplified = ref.watch(flowSimplifiedProvider).valueOrNull ?? false;
    final fahrenheit =
        ref.watch(temperatureFahrenheitProvider).valueOrNull ?? false;

    final symptoms = <String>[
      for (final symptom in entry.symptoms.entries)
        if (symptom.value != SymptomSeverity.none)
          l10n.logDaySymptomWithSeverity(
            symptomLabel(l10n, symptom.key),
            severityLabel(l10n, symptom.value),
          ),
    ];
    final temperature = entry.basalTemperatureCelsius;
    final progesterone = entry.progesteroneValue;
    final measurements = <String>[
      if (temperature != null)
        l10n.logDayTemperatureWithUnit(
          Temperature.toShown(
            temperature,
            fahrenheit: fahrenheit,
          ).toStringAsFixed(1),
          temperatureUnitLabel(l10n, fahrenheit: fahrenheit),
        ),
      if (entry.cervicalMucus != null) mucusLabel(l10n, entry.cervicalMucus!),
      if (entry.pdgStrip != null) pdgLabel(l10n, entry.pdgStrip!),
      if (progesterone != null && entry.progesteroneUnit != null)
        [
          progesterone.toStringAsFixed(1),
          progesteroneUnitLabel(l10n, entry.progesteroneUnit!),
        ].join(' '),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (entry.flow != FlowIntensity.none)
          _Line(
            label: l10n.logFlowTitle,
            // Named by intensity only where the user has not put that
            // vocabulary away (AND-24).
            value: simplified
                ? l10n.logBleedingYes
                : flowLabel(l10n, entry.flow),
          ),
        if (symptoms.isNotEmpty)
          _Line(
            label: l10n.logDaySymptomsRecorded,
            value: symptoms.join(', '),
          ),
        if (entry.intercourse != null)
          _Line(
            label: l10n.logIntercourseTitle,
            value: switch (entry.intercourse!) {
              Intercourse.protected => l10n.logIntercourseProtected,
              Intercourse.unprotected => l10n.logIntercourseUnprotected,
            },
          ),
        if (measurements.isNotEmpty)
          _Line(
            label: l10n.logMeasurementsTitle,
            value: measurements.join(', '),
          ),
      ],
    );
  }
}

/// One labelled line of the summary.
///
/// Attributes:
///     label (String): What the value is.
///     value (String): The value itself.
class _Line extends StatelessWidget {
  /// Creates a line.
  ///
  /// Args:
  ///     label (String): What the value is, in the words the editor uses.
  ///     value (String): The value itself.
  const _Line({required this.label, required this.value});

  /// What the value is.
  final String label;

  /// The value itself.
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
