import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
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
import 'package:period_tracker/security/app_lock.dart';
import 'package:period_tracker/security/lock_controller.dart';

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

/// Asks the device to prove who is holding it (AND-29).
///
/// Overridden in tests with a fake, so the gate's behaviour — the sixty-second
/// grace period, the refusal path, the credential-removed path — is exercised
/// headless rather than only on a device.
final Provider<AppLockService> appLockServiceProvider =
    Provider<AppLockService>(
      (ref) => const LocalAuthService(),
    );

/// Holds the locked/unlocked state for the whole app.
final Provider<LockController> lockControllerProvider =
    Provider<LockController>(
      (ref) {
        final controller = LockController(
          service: ref.watch(appLockServiceProvider),
          clock: ref.watch(clockProvider),
          isEnabled: ref
              .watch(appDatabaseProvider)
              .settingsDao
              .readAppLockEnabled,
        );
        ref.onDispose(controller.dispose);
        return controller;
      },
    );

/// Whether the app requires an unlock before showing anything (AND-29).
final StreamProvider<bool> appLockEnabledProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchAppLockEnabled(),
);

/// Whether the user still needs telling that their old backups will not
/// restore (AND-28, ADR-0011).
///
/// A stream, so that exporting or dismissing takes the banner away on the next
/// frame rather than the next launch — a warning that survives the action it
/// asked for reads as the app not having noticed.
final StreamProvider<bool> needsReExportPromptProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(appDatabaseProvider).settingsDao.watchNeedsReExportPrompt(),
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

/// Whether the Learn tab appears in the navigation bar (AND-39).
///
/// **Off by default**, and unlike the ovulation window that default is a taste
/// rather than a safety property: the reference pages make no claim about the
/// reader, and every one of them is also listed in Settings. Turning the tab
/// off hides a route to the reading, not the reading.
final StreamProvider<bool> showLearnTabProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchShowLearnTab(),
);

/// Whether the companion sits at the end of the navigation bar (AND-37).
///
/// **Off by default.** The companion restates what the log already holds and
/// never guesses at a reason, so whether it is there at all is a preference.
final StreamProvider<bool> showCompanionProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchShowCompanion(),
);

/// The colour scheme the app is wearing (AND-39).
///
/// A stream, so that tapping a scheme in settings repaints the app on the next
/// frame. That immediacy is the whole point of the screen: a colour chosen
/// against a swatch and applied on the next launch is a colour nobody can
/// actually judge.
///
/// Falls back to [AppScheme.fallback] while the read is in flight and for a
/// stored name this build does not have.
final StreamProvider<AppScheme> colourSchemeProvider =
    StreamProvider<AppScheme>(
      (ref) => ref
          .watch(appDatabaseProvider)
          .settingsDao
          .watchRaw(SettingKey.colourScheme)
          .map(AppScheme.fromWireName),
    );

/// Whether the app follows the device theme, or is pinned light or dark.
///
/// Defaults to [ThemeMode.light] rather than following the device. The app is
/// read in daylight far more often than not, and a first launch that opens
/// dark because the phone is on a night schedule shows the palette at its
/// least representative. Following the device is still one tap away in
/// Appearance, and a stored choice always wins over this default.
///
/// An unrecognised stored value falls back to the same default rather than
/// throwing, for the same reason the scheme does.
final StreamProvider<ThemeMode> themeModeProvider = StreamProvider<ThemeMode>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchRaw(SettingKey.themeMode)
      .map(themeModeFromWireName),
);

/// The [ThemeMode] stored as [wireName], or [ThemeMode.light].
ThemeMode themeModeFromWireName(String? wireName) {
  for (final mode in ThemeMode.values) {
    if (mode.name == wireName) return mode;
  }
  return ThemeMode.light;
}

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
