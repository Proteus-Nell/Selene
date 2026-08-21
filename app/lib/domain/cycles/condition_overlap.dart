import 'package:meta/meta.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';

/// How many of a user's cycles were logged while a condition was running.
///
/// This is the entire reason the conditions table stores **spans rather than
/// flags**. A flag says "you are on the pill"; it cannot say "these six cycles
/// were logged while you were", and the moment it is switched off it takes the
/// interpretation of every one of those cycles with it.
///
/// The count is presented and nothing more. Nothing here is fed to the
/// prediction model — the shipped priors were fitted with no condition strata,
/// so making the filter behave differently for PCOS would be inventing
/// calibration and presenting it as a measurement (ADR-0010). What this does
/// instead is hand the user the context to interpret their own numbers, which
/// is a thing the app can honestly do.
@immutable
final class ConditionOverlap {
  /// Creates an overlap summary.
  const ConditionOverlap({required this.condition, required this.cycles});

  /// The condition the cycles overlapped.
  final Condition condition;

  /// How many completed cycles overlapped it.
  final int cycles;

  @override
  bool operator ==(Object other) =>
      other is ConditionOverlap &&
      other.condition == condition &&
      other.cycles == cycles;

  @override
  int get hashCode => Object.hash(condition, cycles);

  @override
  String toString() => 'ConditionOverlap(${condition.name}, $cycles)';
}

/// Counts cycles against recorded conditions.
abstract final class ConditionOverlaps {
  /// How many of [cycles] overlapped each condition in [records].
  ///
  /// A cycle counts if the condition was active on **any** day of it, not only
  /// on its start. Someone who begins hormonal contraception mid-cycle has that
  /// cycle affected by it, and requiring the start day to fall inside the span
  /// would drop exactly the cycle a reader is most likely to be asking about.
  ///
  /// Spans of the same condition are summed rather than reported separately:
  /// the sentence this feeds is "these six cycles were logged while you were on
  /// hormonal contraception", which is about the condition, not the episode.
  /// Counted with a set so a cycle spanning two episodes of the same condition
  /// is not counted twice.
  static List<ConditionOverlap> summarise({
    required List<CycleRecord> cycles,
    required List<ConditionRecord> records,
  }) {
    final counted = <Condition, Set<int>>{};
    for (final record in records) {
      for (var i = 0; i < cycles.length; i++) {
        final cycle = cycles[i];
        if (_overlaps(record, cycle)) {
          (counted[record.condition] ??= <int>{}).add(i);
        }
      }
    }
    final summaries = <ConditionOverlap>[
      for (final entry in counted.entries)
        ConditionOverlap(condition: entry.key, cycles: entry.value.length),
    ]..sort((a, b) => b.cycles.compareTo(a.cycles));
    return summaries;
  }

  static bool _overlaps(ConditionRecord record, CycleRecord cycle) {
    // A cycle in progress has no next start and so no length. It is counted
    // from its start day up to today's edge of the condition rather than being
    // skipped: the cycle a user is in right now is the one they are most likely
    // to be asking about, and dropping it would make the count quietly lag by
    // one for as long as the condition is running.
    final length = cycle.lengthInDays;
    final last = length == null ? null : cycle.startDate.addDays(length - 1);
    if (last != null && last < record.start) return false;
    if (last == null && record.end != null && record.end! < cycle.startDate) {
      return false;
    }
    final end = record.end;
    return end == null || cycle.startDate <= end;
  }
}
