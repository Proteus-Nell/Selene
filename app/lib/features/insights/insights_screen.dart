/// Insights screen.
///
/// What the model believes, what the user's own cycles look like, and how
/// often the app has been right. The screen where overclaiming would do the
/// most damage, so no state on it is a dead end: every one shows the user
/// their own data even when no prediction can be made.
///
/// Includes:
///     - cyclesProvider: The cycles the screen draws.
///     - trackRecordProvider: The model's accuracy on this user's history.
///     - InsightsScreen: The screen itself, in order down the page.
///     - PermanentDisclaimer: The line that is always on it.
///     - _StatisticsCard: The user's own cycles, in figures.
///     - _TrackRecordCard: How often the app has been right.
///     - _LoggingCompleteness: How much of this cycle has been logged.
///     - _WeightReferenceLink: The way in to the body-composition reference.
///     - _MovementReferenceLink: The way in to the movement reference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/track_record.dart';
import 'package:period_tracker/features/common/card_entrance.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/next_period_panel.dart';
import 'package:period_tracker/features/insights/cycle_length_chart.dart';
import 'package:period_tracker/features/movement/movement_screen.dart';
import 'package:period_tracker/features/weight/weight_hormones_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The cycles the user has recorded, for the screen to draw.
final FutureProvider<List<CycleRecord>> cyclesProvider =
    FutureProvider<List<CycleRecord>>((ref) async {
      await ref.watch(dayLogsProvider.future);
      final result = await ref.watch(cycleRepositoryProvider).cycles();
      return result.valueOrNull ?? const <CycleRecord>[];
    });

/// The model's own accuracy on this user's history.
final FutureProvider<TrackRecord?> trackRecordProvider =
    FutureProvider<TrackRecord?>((ref) async {
      final cycles = await ref.watch(cyclesProvider.future);
      return SelfMetrics.evaluate(
        CycleFeatures.usableLengths(cycles),
        ref.watch(modelPriorsProvider),
      );
    });

/// Insights screen: what the model believes, said honestly.
///
/// The screen where overclaiming would do the most damage, and where risk R17
/// lives: a user with PCOS or in perimenopause who is told "we cannot predict
/// this" every cycle stops logging, which degrades the data and makes the state
/// permanent. So no state here is a dead end. Every one of them shows the user
/// their own cycles, their own variability, and the app's own track record.
class InsightsScreen extends ConsumerWidget {
  /// Creates the insights screen.
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prediction = ref.watch(predictionProvider);
    final cycles =
        ref.watch(cyclesProvider).valueOrNull ?? const <CycleRecord>[];
    final statistics = CycleFeatures.summarise(cycles);
    // Body composition and movement are shown only to someone who has
    // switched the Learn tab on and revealed them there, here as in Learn.
    final references =
        (ref.watch(showLearnTabProvider).valueOrNull ?? false) &&
        (ref.watch(revealHiddenReferenceProvider).valueOrNull ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            // Permanent, on the screen itself, not behind an "about" link.
            const CardEntrance(index: 0, child: PermanentDisclaimer()),
            const SizedBox(height: 16),
            CardEntrance(
              index: 1,
              child: prediction.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Text(l10n.errorGeneric),
                data: (result) => NextPeriodPanel(result: result),
              ),
            ),
            const SizedBox(height: 24),
            CardEntrance(
              index: 2,
              child: _StatisticsCard(statistics: statistics),
            ),
            const SizedBox(height: 24),
            CardEntrance(index: 3, child: CycleLengthChart(cycles: cycles)),
            const SizedBox(height: 24),
            const CardEntrance(index: 4, child: _TrackRecordCard()),
            if (references) ...<Widget>[
              const SizedBox(height: 24),
              // Last, deliberately, and both of them. Everything above is this
              // user's own data; the references are general reading that
              // happens to be shown to someone tracking a cycle, and putting
              // either higher would make it look like a response to the
              // figures above it (AND-35, AND-36).
              const CardEntrance(index: 5, child: _WeightReferenceLink()),
              const SizedBox(height: 16),
              const CardEntrance(index: 6, child: _MovementReferenceLink()),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one-line disclaimer that is always on this screen.
///
/// On the screen itself rather than behind an "about" link, and above the
/// prediction rather than under it. A caveat the reader has to go and find is
/// a caveat that does not qualify anything.
class PermanentDisclaimer extends StatelessWidget {
  /// Creates the disclaimer.
  const PermanentDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).insightsDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The user's own cycles, in figures.
///
/// Each line is arithmetic over what the user logged and none of it is a
/// prediction. Lines whose figure cannot be computed are absent rather than
/// rendered with a dash, and with fewer than two cycles the card says so
/// instead of printing a median of one.
///
/// Attributes:
///     statistics (CycleStatistics): The summary to print.
class _StatisticsCard extends StatelessWidget {
  /// Creates the statistics card.
  ///
  /// Args:
  ///     statistics (CycleStatistics): The summary to print, already computed
  ///         by [CycleFeatures.summarise].
  const _StatisticsCard({required this.statistics});

  /// The summary to print.
  final CycleStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final median = statistics.medianLengthDays;
    final spread = statistics.medianAbsoluteDeviationDays;
    final shortest = statistics.shortestLengthDays;
    final longest = statistics.longestLengthDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.insightsYourCyclesTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.insightsCyclesRecorded(statistics.completedCycles)),
        if (median != null)
          Text(l10n.insightsTypicalLength(formatDays(median))),
        if (spread != null) Text(l10n.insightsVariability(formatDays(spread))),
        if (shortest != null &&
            longest != null &&
            statistics.completedCycles > 1)
          Text(l10n.insightsRange(shortest, longest)),
        if (statistics.completedCycles < 2)
          Text(
            l10n.insightsNotEnoughForStats,
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// How often the app has been right, on this user's own history.
///
/// The app's accuracy rather than the user's regularity, and the distinction
/// is the point: a number that reads as a score for the person would be an
/// engagement mechanic on data that must not carry one (`docs/PLAN.md`
/// 2.4.1). Until there is enough history it says so rather than printing a
/// figure computed from two cycles.
class _TrackRecordCard extends ConsumerWidget {
  /// Creates the track record card.
  const _TrackRecordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final record = ref.watch(trackRecordProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.insightsTrackRecordTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (record == null)
          Text(l10n.insightsTrackRecordNotYet)
        else ...<Widget>[
          Text(
            l10n.insightsTrackRecordScore(
              record.predictions,
              record.withinTolerance,
              record.toleranceDays,
            ),
          ),
          Text(
            l10n.insightsTrackRecordError(
              formatDays(record.meanAbsoluteErrorDays),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          l10n.insightsTrackRecordExplain,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const _LoggingCompleteness(),
      ],
    );
  }
}

/// How much of the current cycle has been logged.
///
/// A count of days out of days, never a streak and never a percentage with a
/// target beside it. It is there so the reader can weigh the figures above it,
/// not so the app can ask them for more (`docs/PLAN.md` 2.4.1).
class _LoggingCompleteness extends ConsumerWidget {
  /// Creates the completeness line.
  const _LoggingCompleteness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final logs = ref.watch(dayLogsProvider).valueOrNull ?? const <DayLog>[];
    final cycles =
        ref.watch(cyclesProvider).valueOrNull ?? const <CycleRecord>[];
    if (cycles.isEmpty) return const SizedBox.shrink();

    final start = cycles.last.startDate;
    final today = ref.watch(clockProvider).today();
    final total = start.daysBetween(today) + 1;
    if (total < 1) return const SizedBox.shrink();
    final logged = logs
        .where((log) => log.date.isBetweenInclusive(start, today))
        .length;

    // Stated as a count, never as a streak or a percentage with a target.
    // Engagement mechanics are inappropriate on this data (2.4.1).
    return Text(
      l10n.insightsLoggingCompleteness(logged, total),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// The way in to the body-composition reference (AND-35).
///
/// A row rather than a paragraph, because the reference is a place to go and
/// not a thing this screen is saying. The subtitle names the mechanisms so that
/// someone for whom this subject is not neutral can decide before opening it,
/// rather than finding out on the other side of a tap.
class _WeightReferenceLink extends StatelessWidget {
  /// Creates the row.
  const _WeightReferenceLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(l10n.weightEntryTitle),
        subtitle: Text(l10n.weightEntrySubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const WeightHormonesScreen(),
          ),
        ),
      ),
    );
  }
}

/// The way in to the pain-and-movement reference (AND-36).
///
/// Same shape as the row above it, and the subtitle does the same job: it says
/// what the page argues before anyone taps it. That matters more here than
/// usual, because the popular version of this subject is a plan and this page
/// is the opposite of one. Somebody arriving hoping to be told which days to
/// exercise on should be able to see that they will not be.
class _MovementReferenceLink extends StatelessWidget {
  /// Creates the row.
  const _MovementReferenceLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(l10n.movementEntryTitle),
        subtitle: Text(l10n.movementEntrySubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => const MovementScreen()),
        ),
      ),
    );
  }
}
