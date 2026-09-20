/// Log screen.
///
/// The app's home: today's state, one primary action, and the day editor
/// beneath it. The tap budgets in `docs/PLAN.md` 2.4.2 are this screen's
/// specification, because sparse logs degrade prediction quality directly.
///
/// Includes:
///     - LogScreen: The screen itself.
///     - _LogScreenState: The chosen day, and the write the button makes.
///     - _TodayState: Today's state, in a sentence.
///     - _DaySelector: The inline day choices beside the action.
///     - _ReExportBanner: The one-time warning about pre-AND-28 backups.
///     - _RecoveryBanner: The notice that a damaged database was quarantined.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/chip_motion.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/log/day_editor.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/features/today/today_hero.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';

/// Log screen: today's state, and one action.
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

/// State for [LogScreen]: which day the button will write, and the write.
///
/// Attributes:
///     _daysBack (int): How many days back the primary action will write.
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

  /// Record a period start, and offer to undo it.
  ///
  /// Steps:
  ///     1. Read whatever is already logged for the day.
  ///     2. Write the start, or report why it was refused.
  ///     3. Offer an undo that restores exactly step 1's state.
  ///
  /// The undo restores the previous log rather than deleting the day, because
  /// the day may have carried symptoms that had nothing to do with the flow.
  /// Deleting would take those with it.
  ///
  /// Args:
  ///     date (CivilDate): The day to mark as a period start.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the write has been reported, whether
  ///     it succeeded or was refused. The undo itself runs later, if at all.
  Future<void> _logStart(CivilDate date) async {
    final repository = ref.read(cycleRepositoryProvider);
    final previous = await repository.logFor(date);
    final result = await repository.markPeriodStart(date);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (result.isErr) {
      showAppSnackBar(
        context,
        _messageFor(result.errorOrNull!.rejection, l10n),
      );
      return;
    }
    showAppSnackBar(
      context,
      l10n.logEntrySaved,
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
    );
  }

  /// Return what to tell the user about a refused write.
  ///
  /// Args:
  ///     rejection (WriteRejection): Why the repository refused.
  ///     l10n (AppLocalizations): The translations.
  ///
  /// Returns:
  ///     String: A sentence naming the reason where the user can act on it,
  ///     and the generic error where they cannot: `duplicateInBatch` and
  ///     `dayNotLogged` are unreachable from this button, so a specific
  ///     message for either would be a sentence about the app's own bug.
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
      // No app bar. The screen names itself in the greeting, and a title bar
      // saying "Today" above a date saying today was the app talking to itself
      // (AND-39). The tab is still labelled, so nothing is lost.
      body: SafeArea(
        // A scroll view over a Column rather than a ListView, since the hero
        // arrived above the controls (AND-39). A ListView builds only what is
        // near the viewport, and the ring is tall enough to push the primary
        // action past it, which means the button does not exist until the
        // user scrolls, and neither does anything a screen reader or a test
        // would go looking for. The content here is bounded, so building all
        // of it costs nothing worth having.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _RecoveryBanner(),
              const _ReExportBanner(),
              const TodayHero(),
              const SizedBox(height: 24),
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
      ),
    );
  }

  /// Return the wording for one of the day offsets.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     daysBack (int): How many days back, 0 for today.
  ///
  /// Returns:
  ///     String: "Today", "Yesterday", or a count of days.
  static String _offsetLabel(AppLocalizations l10n, int daysBack) =>
      switch (daysBack) {
        0 => l10n.logDayToday,
        1 => l10n.logDayYesterday,
        _ => l10n.logDaysAgo(daysBack),
      };
}

/// Today's state in a sentence, above the action.
///
/// One of three sentences: nothing logged yet, a welcome back after a long
/// silence, or which day of the current period this is. None of them counts
/// the silence or asks for anything (`docs/PLAN.md` 2.4.1).
///
/// Attributes:
///     entries (`List<DayLog>`): Every day the user has logged, oldest first.
///     today (CivilDate): The current day.
class _TodayState extends StatelessWidget {
  /// Creates the state line.
  ///
  /// Args:
  ///     entries (`List<DayLog>`): Every day the user has logged, oldest
  ///         first. The order matters: the newest entry is read off the end.
  ///     today (CivilDate): The current day.
  const _TodayState({required this.entries, required this.today});

  /// Every day the user has logged, oldest first.
  final List<DayLog> entries;

  /// The current day.
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

  /// Return the start of the most recent run of bleeding days.
  ///
  /// Walks backwards from the newest bleeding day and stops at the first gap
  /// wider than [CycleRules.maxGapWithinEpisodeDays], so a one-day pause in
  /// the middle of a period does not split it into two.
  ///
  /// Args:
  ///     entries (`List<DayLog>`): Every day the user has logged, oldest
  ///         first.
  ///
  /// Returns:
  ///     CivilDate?: The first day of that run, or null if nothing has been
  ///     logged as bleeding.
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
///
/// Attributes:
///     today (CivilDate): The day the offsets count back from.
///     selected (int): Which offset is chosen.
///     onSelected (`ValueChanged<int>`): Reports a new choice.
///     offsets (`List<int>`): The offsets to offer, in days back.
class _DaySelector extends StatelessWidget {
  /// Creates the day selector.
  ///
  /// Args:
  ///     today (CivilDate): The day the offsets count back from.
  ///     selected (int): Which offset is chosen, in days back.
  ///     onSelected (`ValueChanged<int>`): Reports a new choice.
  ///     offsets (`List<int>`): The offsets to offer, in days back. Fixed
  ///         choices rather than a stepper, for the arithmetic reason at
  ///         [_LogScreenState._offsets].
  const _DaySelector({
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.offsets,
  });

  /// The day the offsets count back from.
  final CivilDate today;

  /// Which offset is chosen, in days back.
  final int selected;

  /// Reports a new choice.
  final ValueChanged<int> onSelected;

  /// The offsets to offer, in days back.
  final List<int> offsets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final offset in offsets)
          ChipMotion(
            selected: selected == offset,
            builder: (context, checkSlot) => ChoiceChip(
              avatar: checkSlot,
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
          ),
      ],
    );
  }
}

/// Tells the user, once, that backups taken before this release will not
/// restore (AND-28).
///
/// This banner is the whole mitigation for ADR-0011. The decision to refuse v1
/// files was taken knowing that this app has no cloud and no Play Store
/// restore, so the export *is* the recovery path (risk R8). Every file a user
/// saved before updating is now unrestorable, and that is defensible only if
/// they are told while they still have a working phone to export from.
/// Discovering it after losing the phone is not a trade-off anyone agreed to.
///
/// Shown on the log screen rather than in settings, because it has to reach
/// someone who never opens settings; that is most people, and settings is
/// exactly where a user who already backs up regularly would find it anyway.
///
/// It goes away when the user exports **or** dismisses. Dismissing counts: the
/// release notes carry the same message, and a warning that returns every
/// launch is one people learn to tap past without reading, which would cost it
/// the one audience it has.
class _ReExportBanner extends ConsumerWidget {
  /// Creates the banner.
  const _ReExportBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defaults to hidden while the preference loads. Erring the other way
    // would flash a data-loss warning at every user on every cold start.
    final needed = ref.watch(needsReExportPromptProvider).valueOrNull ?? false;
    if (!needed) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.reExportTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.reExportBody),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                // Navigating does not acknowledge: only a completed export
                // does. Otherwise a user who taps through and then changes
                // their mind loses the warning without ever having a new file.
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
                  child: Text(l10n.reExportAction),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(appDatabaseProvider)
                      .settingsDao
                      .acknowledgeExportFormat(),
                  child: Text(l10n.reExportDismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells the user their data was quarantined, rather than looking empty.
///
/// A database this build could not open is moved aside rather than deleted,
/// and the app starts on an empty one. Without this banner that reads as
/// every entry having vanished, which is the same thing happening for a
/// reason nobody has been given.
class _RecoveryBanner extends ConsumerWidget {
  /// Creates the banner.
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
