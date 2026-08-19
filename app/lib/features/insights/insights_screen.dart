import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/track_record.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/insights/cycle_length_chart.dart';
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

/// What the model currently believes, said honestly.
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            // Permanent, on the screen itself, not behind an "about" link.
            const PermanentDisclaimer(),
            const SizedBox(height: 16),
            prediction.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Text(l10n.errorGeneric),
              data: (result) => _PredictionCard(result: result),
            ),
            const SizedBox(height: 24),
            _StatisticsCard(statistics: statistics),
            const SizedBox(height: 24),
            CycleLengthChart(cycles: cycles),
            const SizedBox(height: 24),
            const _TrackRecordCard(),
          ],
        ),
      ),
    );
  }
}

/// The one-line disclaimer that is always on this screen.
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

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Exhaustive by construction: PredictionResult is sealed, so a state added
    // later cannot quietly render as nothing.
    return switch (result) {
      Predicted(:final prediction) => _Window(
        prediction: prediction,
        subtitle: l10n.insightsBasedOnCycles(prediction.basis.cyclesUsed),
      ),
      InsufficientData(:final populationPrior) => _Window(
        prediction: populationPrior,
        subtitle: l10n.insightsNotPersonalisedYet(5),
      ),
      TooIrregular() => _Message(
        title: l10n.insightsTooIrregularTitle,
        body: l10n.insightsTooIrregularBody,
        icon: Icons.show_chart,
      ),
      LostTrack(:final daysSinceLastLog) => _Message(
        title: l10n.insightsLostTrackTitle,
        body: l10n.insightsLostTrackBody(daysSinceLastLog),
        icon: Icons.history,
      ),
      NoData() => _Message(
        title: l10n.insightsNoDataTitle,
        body: l10n.insightsNoDataBody,
        icon: Icons.edit_calendar_outlined,
      ),
      DataInconsistent(:final reason) => _Message(
        title: l10n.insightsInconsistentTitle,
        body: reason == DataInconsistency.clockWentBackwards
            ? l10n.insightsClockChanged
            : l10n.insightsInconsistentBody,
        icon: Icons.warning_amber_outlined,
        emphasis: theme.colorScheme.error,
      ),
    };
  }
}

/// A predicted window. Never a bare date: the range is the headline.
class _Window extends StatelessWidget {
  const _Window({required this.prediction, required this.subtitle});

  final Prediction prediction;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.insightsNextPeriodTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            // The range is the largest thing on the card, and the single most
            // likely day is a supporting line beneath it. Reversing that
            // emphasis is the everyday form of overclaiming (6.2).
            Text(
              l10n.insightsWindowRange(
                prediction.window80.start.dayAndMonth(context),
                prediction.window80.end.dayAndMonth(context),
              ),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(l10n.insightsFourInFive, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              l10n.insightsMostLikely(
                prediction.medianStart.dayAndMonth(context),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              l10n.insightsHalfTheTime(
                prediction.window50.start.dayAndMonth(context),
                prediction.window50.end.dayAndMonth(context),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Chip(
                  label: Text(_confidenceLabel(l10n, prediction.confidence)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  static String _confidenceLabel(
    AppLocalizations l10n,
    Confidence confidence,
  ) => switch (confidence) {
    Confidence.high => l10n.insightsConfidenceHigh,
    Confidence.medium => l10n.insightsConfidenceMedium,
    Confidence.low => l10n.insightsConfidenceLow,
  };
}

/// A state with no window, which still has to say something useful.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.icon,
    this.emphasis,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                icon,
                color: emphasis ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.statistics});

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

class _TrackRecordCard extends ConsumerWidget {
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

class _LoggingCompleteness extends ConsumerWidget {
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
