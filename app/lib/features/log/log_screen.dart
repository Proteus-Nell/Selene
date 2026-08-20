import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/log/day_editor.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';

/// The app's home: today's state and one action.
///
/// The tap budgets in `docs/PLAN.md` 2.4.2 are the specification for this
/// screen, and `log_screen_test.dart` counts the taps rather than trusting the
/// layout to have kept them. They matter because sparse logs degrade prediction
/// quality directly: a missed start becomes a merged 60-day pseudo-cycle, which
/// the filter correctly treats as an outlier and answers by widening the
/// interval. Low friction is a data-quality requirement here, not polish.
///
/// The case being designed for is "I am two days late noticing", which is why
/// the day selector sits inline beside the primary action and is reachable
/// before committing, rather than behind a modal date picker.
///
/// One inherited constraint shapes the copy: no streaks, no guilt, no
/// loss-aversion (2.4.1). A gap in logging may mean pregnancy, loss, illness,
/// or simply not wanting to think about it, and none of those deserve a nudge.
class LogScreen extends ConsumerStatefulWidget {
  /// Creates the log screen.
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  /// How many days back the primary action will write. 0 is today.
  int _daysBack = 0;

  /// The choices offered inline beside the primary action.
  ///
  /// Four fixed options rather than a stepper, and the reason is arithmetic:
  /// a stepper costs one tap per day, so backdating three days would take four
  /// taps against a budget of three. This meets the budget for the whole 1-to-3
  /// day range in two.
  static const List<int> _offsets = <int>[0, 1, 2, 3];

  Future<void> _logStart(CivilDate date) async {
    final repository = ref.read(cycleRepositoryProvider);
    final previous = await repository.logFor(date);
    final result = await repository.markPeriodStart(date);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    if (result.isErr) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_messageFor(result.errorOrNull!.rejection, l10n)),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.logEntrySaved),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () async {
            if (previous == null) {
              await repository.deleteDay(date);
            } else {
              await repository.upsert(previous);
            }
          },
        ),
      ),
    );
  }

  String _messageFor(WriteRejection rejection, AppLocalizations l10n) =>
      switch (rejection) {
        WriteRejection.dateInFuture => l10n.errorWriteRefusedFuture,
        WriteRejection.dayAlreadyLogged ||
        WriteRejection.overlapsExistingEntries => l10n.errorWriteRefusedExists,
        WriteRejection.duplicateInBatch ||
        WriteRejection.dayNotLogged => l10n.errorGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(clockProvider).today();
    final logs = ref.watch(dayLogsProvider);
    final selected = today.addDays(-_daysBack);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            const _RecoveryBanner(),
            Text(
              l10n.logTodayIs(today.weekdayDayAndMonth(context)),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            logs.when(
              loading: () => const SizedBox(height: 24),
              error: (error, stack) => Text(l10n.errorGeneric),
              data: (entries) => _TodayState(entries: entries, today: today),
            ),
            const SizedBox(height: 20),
            Text(l10n.logWhenDidItStart, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DaySelector(
              today: today,
              selected: _daysBack,
              onSelected: (value) => setState(() => _daysBack = value),
              offsets: _offsets,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _logStart(selected),
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(
                  _daysBack == 0
                      ? l10n.logPeriodStartedToday
                      : l10n.logPeriodStartedOnDay(
                          _offsetLabel(l10n, _daysBack),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            logs.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (entries) => DayEditor(
                date: today,
                existing: entries
                    .where((e) => e.date == today)
                    .cast<DayLog?>()
                    .firstWhere((e) => true, orElse: () => null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _offsetLabel(AppLocalizations l10n, int daysBack) =>
      switch (daysBack) {
        0 => l10n.logDayToday,
        1 => l10n.logDayYesterday,
        _ => l10n.logDaysAgo(daysBack),
      };
}

/// Today's state in a sentence, above the action.
class _TodayState extends StatelessWidget {
  const _TodayState({required this.entries, required this.today});

  final List<DayLog> entries;
  final CivilDate today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Text(
        l10n.logNothingLoggedYet,
        style: theme.textTheme.bodyMedium,
      );
    }

    final newest = entries.last.date;
    final silence = newest.daysBetween(today);
    if (silence > CycleRules.lostTrackAfterDays) {
      // No guilt, no streak, no "you missed 74 days". A gap may mean pregnancy,
      // loss, illness or simply not wanting to think about it (2.4.1).
      return Text(l10n.logWelcomeBack, style: theme.textTheme.bodyMedium);
    }

    final lastStart = _mostRecentStart(entries);
    if (lastStart == null) {
      return Text(l10n.logNothingLoggedYet, style: theme.textTheme.bodyMedium);
    }
    return Text(
      l10n.logDayInProgress(lastStart.daysBetween(today) + 1),
      style: theme.textTheme.bodyMedium,
    );
  }

  /// The start of the most recent run of bleeding days.
  static CivilDate? _mostRecentStart(List<DayLog> entries) {
    final bleeding = entries.where((e) => e.isBleedingDay).toList();
    if (bleeding.isEmpty) return null;
    var start = bleeding.last.date;
    for (var i = bleeding.length - 2; i >= 0; i--) {
      final gap = bleeding[i].date.daysBetween(start);
      if (gap > CycleRules.maxGapWithinEpisodeDays + 1) break;
      start = bleeding[i].date;
    }
    return start;
  }
}

/// The inline day choices beside the primary action.
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.offsets,
  });

  final CivilDate today;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<int> offsets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final offset in offsets)
          ChoiceChip(
            selected: selected == offset,
            onSelected: (_) => onSelected(offset),
            // The date is in the label, not only the relative wording, so the
            // announcement is unambiguous when the phone has been sitting
            // unopened over midnight.
            label: Text(
              switch (offset) {
                0 => l10n.logDayToday,
                1 => l10n.logDayYesterday,
                _ => l10n.logDaysAgo(offset),
              },
            ),
            tooltip: today.addDays(-offset).full(context),
          ),
      ],
    );
  }
}

/// Tells the user their data was quarantined, rather than looking empty.
class _RecoveryBanner extends ConsumerWidget {
  const _RecoveryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(quarantinedDatabaseProvider) == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.bootstrapRecoveredTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.bootstrapRecoveredBody),
          ],
        ),
      ),
    );
  }
}
