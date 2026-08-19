import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
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
