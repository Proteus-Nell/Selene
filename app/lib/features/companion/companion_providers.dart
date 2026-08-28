import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';
import 'package:period_tracker/features/companion/companion_rules.dart';

/// What the companion currently knows (AND-37).
///
/// Assembled from providers that already exist rather than from a query of its
/// own: the companion is a reader of the app's state and must never become a
/// second opinion about it. If the log screen and the companion ever disagreed
/// about whether today is logged, this is the line that let them.
///
/// [CompanionState.notReady] while any of the three streams is still loading,
/// rather than defaulting to empty. Defaulting would have the companion say
/// "nothing is recorded yet" for a frame to a user with two years of history,
/// which is a small lie told confidently — the failure mode this project cares
/// about most.
final Provider<CompanionState> companionStateProvider =
    Provider<CompanionState>((ref) {
      final logs = ref.watch(dayLogsProvider);
      final prediction = ref.watch(predictionProvider);
      final conditions = ref.watch(conditionsProvider);
      if (!logs.hasValue || !prediction.hasValue || !conditions.hasValue) {
        return const CompanionState.notReady();
      }
      return CompanionState.of(
        logs: logs.requireValue,
        prediction: prediction.requireValue,
        conditions: conditions.requireValue,
        today: ref.watch(clockProvider).today(),
      );
    });

/// The single line the companion would say right now.
final Provider<CompanionLine> companionLineProvider = Provider<CompanionLine>(
  (ref) => CompanionRules.select(ref.watch(companionStateProvider)),
);
