import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// A maximal run of bleeding days, before it is interpreted as a cycle.
///
/// Exposed because the calendar needs to shade the actual bleeding days, which
/// is not the same as the cycle span.
@immutable
class BleedingEpisode {
  /// Creates an episode covering [start] to [end] inclusive.
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

/// Turns an unordered pile of day logs into an ordered list of cycles.
///
/// The transformation is: day logs, filtered to bleeding days, grouped into
/// [BleedingEpisode]s, then paired up so that each episode's cycle ends where
/// the next one begins. The final cycle has no `nextStartDate` and is therefore
/// still in progress, which matters because an incomplete cycle is not an
/// observation the prediction model may learn from.
///
/// Validity is *not* assigned here. Segmentation answers "what cycles are
/// these", and `validation.dart` answers "should the model trust them".
abstract final class Segmentation {
  /// Segments [logs] into cycles.
  ///
  /// Input may be in any order. Returns [Err] with
  /// [DataInconsistency.duplicateDate] if two entries share a date, because that
  /// means the storage layer let through something it should have rejected and
  /// silently picking a winner would hide a real bug.
  ///
  /// Empty input yields an empty list, not an error: a new user has no cycles
  /// yet, which is a normal state rather than a failure.
  static Result<List<CycleRecord>, DataInconsistency> segment(
    Iterable<DayLog> logs,
  ) {
    final episodesResult = bleedingEpisodes(logs);
    return episodesResult.map(_episodesToCycles);
  }

  /// Extracts the bleeding episodes from [logs], oldest first.
  ///
  /// Two rules do the work here, both from [CycleRules]:
  ///
  /// * bleeding days separated by no more than
  ///   [CycleRules.maxGapWithinEpisodeDays] belong to the same episode, because
  ///   a lighter unlogged day mid-period is common;
  /// * episodes whose starts are closer than
  ///   [CycleRules.minDaysBetweenEpisodes] are merged, because bleeding that
  ///   resumes that soon is the same period returning rather than a new cycle.
  ///
  /// Note that [FlowIntensity.spotting] is not bleeding, so mid-cycle spotting
  /// never opens an episode at all.
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

  /// Whether the app should admit it has lost track of the current cycle.
  ///
  /// True when the newest log is more than [CycleRules.lostTrackAfterDays] old.
  /// Extrapolating past that point yields a confident wrong answer, which is the
  /// failure mode this whole project is most concerned with.
  static bool hasLostTrack({
    required Iterable<DayLog> logs,
    required CivilDate today,
  }) {
    if (logs.isEmpty) return false;
    final newest = logs.map((log) => log.date).reduce((a, b) => a > b ? a : b);
    return newest.daysBetween(today) > CycleRules.lostTrackAfterDays;
  }

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
