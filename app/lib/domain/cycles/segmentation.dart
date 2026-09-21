/// Cycle segmentation.
///
/// Turns an unordered pile of day logs into an ordered list of cycles. Answers
/// what the cycles are; `validation.dart` answers whether the model should
/// trust them.
///
/// Pipeline:
///     1. Filter the logs to bleeding days.
///     2. Group those days into episodes, tolerating a short gap inside one.
///     3. Merge episodes that start too soon after the previous one.
///     4. Pair each episode with the next, so one cycle ends where the next
///        begins.
///
/// Includes:
///     - BleedingEpisode: A maximal run of bleeding days.
///     - Segmentation: The pipeline above, plus the lost-track check.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// Bleeding episode: a maximal run of bleeding days.
///
/// Exposed because the calendar needs to shade the actual bleeding days, which
/// is not the same as the cycle span.
///
/// Attributes:
///     start (CivilDate): First bleeding day.
///     end (CivilDate): Last bleeding day, inclusive.
@immutable
class BleedingEpisode {
  /// Creates an episode covering [start] to [end] inclusive.
  ///
  /// Args:
  ///     start (CivilDate): First bleeding day.
  ///     end (CivilDate): Last bleeding day, inclusive.
  const BleedingEpisode(this.start, this.end);

  /// First bleeding day.
  final CivilDate start;

  /// Last bleeding day.
  final CivilDate end;

  /// Number of days covered, counted inclusively.
  int get lengthInDays => start.daysBetween(end) + 1;

  @override
  bool operator ==(Object other) =>
      other is BleedingEpisode && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start.toIso8601()}..${end.toIso8601()}';
}

/// Segmentation: day logs in, ordered cycles out.
///
/// The transformation is: day logs, filtered to bleeding days, grouped into
/// [BleedingEpisode]s, then paired up so that each episode's cycle ends where
/// the next one begins. The final cycle has no `nextStartDate` and is
/// therefore still in progress, which matters because an incomplete cycle is
/// not an observation the prediction model may learn from.
///
/// Validity is *not* assigned here. Segmentation answers "what cycles are
/// these", and `validation.dart` answers "should the model trust them".
abstract final class Segmentation {
  /// Segment day logs into cycles.
  ///
  /// Empty input yields an empty list, not an error: a new user has no cycles
  /// yet, which is a normal state rather than a failure.
  ///
  /// Args:
  ///     logs (`Iterable<DayLog>`): Every logged day, in any order.
  ///
  /// Returns:
  ///     `Result<List<CycleRecord>, DataInconsistency>`: The cycles oldest
  ///     first, or [DataInconsistency.duplicateDate] when two entries share a
  ///     date. That means the storage layer let through something it should
  ///     have rejected, and silently picking a winner would hide a real bug.
  static Result<List<CycleRecord>, DataInconsistency> segment(
    Iterable<DayLog> logs,
  ) {
    final episodesResult = bleedingEpisodes(logs);
    return episodesResult.map(_episodesToCycles);
  }

  /// Extract the bleeding episodes from the logs, oldest first.
  ///
  /// Two rules do the work here, both from [CycleRules]:
  ///
  /// * bleeding days separated by no more than
  ///   [CycleRules.maxGapWithinEpisodeDays] belong to the same episode,
  ///   because a lighter unlogged day mid-period is common;
  /// * episodes whose starts are closer than
  ///   [CycleRules.minDaysBetweenEpisodes] are merged, because bleeding that
  ///   resumes that soon is the same period returning rather than a new cycle.
  ///
  /// Note that [FlowIntensity.spotting] is not bleeding, so mid-cycle spotting
  /// never opens an episode at all.
  ///
  /// Args:
  ///     logs (`Iterable<DayLog>`): Every logged day, in any order.
  ///
  /// Returns:
  ///     `Result<List<BleedingEpisode>, DataInconsistency>`: The episodes
  ///     oldest first, or [DataInconsistency.duplicateDate].
  static Result<List<BleedingEpisode>, DataInconsistency> bleedingEpisodes(
    Iterable<DayLog> logs,
  ) {
    final seen = <int>{};
    for (final log in logs) {
      if (!seen.add(log.date.epochDay)) {
        return const Err<List<BleedingEpisode>, DataInconsistency>(
          DataInconsistency.duplicateDate,
        );
      }
    }

    final bleeding =
        logs.where((log) => log.isBleedingDay).map((log) => log.date).toList()
          ..sort();

    if (bleeding.isEmpty) {
      return const Ok<List<BleedingEpisode>, DataInconsistency>(
        <BleedingEpisode>[],
      );
    }

    // Pass one: group into runs, tolerating small gaps inside a period.
    final runs = <BleedingEpisode>[];
    var runStart = bleeding.first;
    var runEnd = bleeding.first;
    for (final date in bleeding.skip(1)) {
      if (runEnd.daysBetween(date) <= CycleRules.maxGapWithinEpisodeDays + 1) {
        runEnd = date;
      } else {
        runs.add(BleedingEpisode(runStart, runEnd));
        runStart = date;
        runEnd = date;
      }
    }
    runs.add(BleedingEpisode(runStart, runEnd));

    // Pass two: absorb a run that starts too soon after the previous one.
    final merged = <BleedingEpisode>[runs.first];
    for (final run in runs.skip(1)) {
      final previous = merged.last;
      if (previous.start.daysBetween(run.start) <
          CycleRules.minDaysBetweenEpisodes) {
        merged[merged.length - 1] = BleedingEpisode(previous.start, run.end);
      } else {
        merged.add(run);
      }
    }
    return Ok<List<BleedingEpisode>, DataInconsistency>(merged);
  }

  /// Report whether the app should admit it has lost track.
  ///
  /// Extrapolating past [CycleRules.lostTrackAfterDays] yields a confident
  /// wrong answer, which is the failure mode this whole project is most
  /// concerned with.
  ///
  /// Args:
  ///     logs (`Iterable<DayLog>`): Every logged day, in any order.
  ///     today (CivilDate): The day to measure staleness against.
  ///
  /// Returns:
  ///     bool: True when the newest log is older than the threshold. False
  ///     for an empty history, which is untracked rather than lost.
  static bool hasLostTrack({
    required Iterable<DayLog> logs,
    required CivilDate today,
  }) {
    if (logs.isEmpty) return false;
    final newest = logs.map((log) => log.date).reduce((a, b) => a > b ? a : b);
    return newest.daysBetween(today) > CycleRules.lostTrackAfterDays;
  }

  /// Pair each episode with the next, so one cycle ends where the next
  /// begins.
  ///
  /// Args:
  ///     episodes (`List<BleedingEpisode>`): The merged episodes, oldest
  ///         first.
  ///
  /// Returns:
  ///     `List<CycleRecord>`: One cycle per episode. The last has a null
  ///     `nextStartDate` and is therefore still in progress.
  static List<CycleRecord> _episodesToCycles(List<BleedingEpisode> episodes) {
    return <CycleRecord>[
      for (var i = 0; i < episodes.length; i++)
        CycleRecord(
          startDate: episodes[i].start,
          bleedingEndDate: episodes[i].end,
          nextStartDate: i + 1 < episodes.length ? episodes[i + 1].start : null,
        ),
    ];
  }
}
