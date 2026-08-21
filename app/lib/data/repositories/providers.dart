import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/domain/cycles/condition_overlap.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/domain/predict/priors.dart';
import 'package:period_tracker/domain/predict/priors_bundled.dart';

/// The open database.
///
/// Deliberately has no default. Opening the database is asynchronous and can
/// fail in ways the app must render rather than swallow, so the bootstrap opens
/// it, handles the corrupt and newer-schema outcomes, and overrides this
/// provider with the result. A default here would be a second construction site
/// for the executor, which ADR-0004 rules out, and would let a widget silently
/// open a second connection to the same file.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden with the database opened by '
    'openAppDatabase(). See lib/data/db/connection.dart.',
  );
});

/// Source of the current date and time.
final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => const SystemClock(),
);

/// The app's structured logger.
final Provider<RingLogger> loggerProvider = Provider<RingLogger>(
  (ref) => RingLogger(clock: ref.watch(clockProvider)),
);

/// The population priors the prediction model runs with.
final Provider<ModelPriors> modelPriorsProvider = Provider<ModelPriors>(
  (ref) => bundledPriors,
);

/// Reads and writes day logs, and derives cycles from them.
final Provider<CycleRepository> cycleRepositoryProvider =
    Provider<CycleRepository>(
      (ref) => CycleRepository(
        database: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        logger: ref.watch(loggerProvider),
      ),
    );

/// Runs and caches the prediction.
final Provider<PredictionRepository> predictionRepositoryProvider =
    Provider<PredictionRepository>(
      (ref) => PredictionRepository(
        database: ref.watch(appDatabaseProvider),
        cycles: ref.watch(cycleRepositoryProvider),
        priors: ref.watch(modelPriorsProvider),
        logger: ref.watch(loggerProvider),
      ),
    );

/// Every logged day, oldest first, kept current as the database changes.
final StreamProvider<List<DayLog>> dayLogsProvider =
    StreamProvider<List<DayLog>>(
      (ref) => ref.watch(cycleRepositoryProvider).watchLogs(),
    );

/// Reads and writes recorded conditions.
final Provider<ConditionRepository> conditionRepositoryProvider =
    Provider<ConditionRepository>(
      (ref) => ConditionRepository(
        database: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
      ),
    );

/// Every recorded condition, kept current as the database changes.
final StreamProvider<List<ConditionRecord>> conditionsProvider =
    StreamProvider<List<ConditionRecord>>(
      (ref) => ref.watch(conditionRepositoryProvider).watchAll(),
    );

/// How many cycles were logged while each condition was recorded.
///
/// Presented and nothing more. This is the sentence a flag could not produce —
/// "these six cycles were logged while you were on hormonal contraception" —
/// and it is context for reading the user's own numbers, never an input to
/// them. See ADR-0010.
final FutureProvider<List<ConditionOverlap>> conditionOverlapsProvider =
    FutureProvider<List<ConditionOverlap>>((ref) async {
      final records = await ref.watch(conditionsProvider.future);
      final segmented = await ref.watch(cycleRepositoryProvider).cycles();
      return ConditionOverlaps.summarise(
        cycles: segmented.valueOrNull ?? const <CycleRecord>[],
        records: records,
      );
    });

/// Whether the flow control is collapsed to bleeding yes/no (AND-24).
///
/// A stream, so that turning the toggle on in settings changes the day editor
/// on the next frame rather than the next launch. The default while it loads is
/// the stored default, which is the fuller control: a screen that flickers from
/// simplified to graded on startup would look like it had discarded something.
final StreamProvider<bool> flowSimplifiedProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchFlowSimplified(),
);

/// Whether the calendar names the cycle phase (AND-25).
///
/// On by default: a phase name restates dates the user logged, which ADR-0007
/// separated from ovulation estimation precisely so that this one need not be
/// opted into.
final StreamProvider<bool> showCyclePhasesProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchShowCyclePhases(),
);

/// Whether an estimated ovulation range is shown (AND-25).
///
/// **Off by default, and the default is a safety property rather than a taste.**
/// `docs/PLAN.md` 6.2 requires ovulation estimation to be opt-in, and ADR-0007
/// was careful not to move that line. Changing this needs an ADR.
final StreamProvider<bool> showOvulationWindowProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(appDatabaseProvider).settingsDao.watchShowOvulationWindow(),
);

/// The current prediction, recomputed whenever the logs change.
///
/// Depends on [dayLogsProvider] rather than being invalidated by hand at every
/// write site. Forgetting one of those call sites is precisely how a stale
/// prediction survives an edit, so the dependency is expressed once, here.
final FutureProvider<PredictionResult> predictionProvider =
    FutureProvider<PredictionResult>((ref) async {
      // Establishes the dependency; the repository re-reads the logs itself.
      await ref.watch(dayLogsProvider.future);
      return ref.watch(predictionRepositoryProvider).current();
    });
