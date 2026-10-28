/// Riverpod providers for the data layer.
///
/// Wires the database, the repositories and the stored preferences into the
/// widget tree, so a screen reads what it needs without knowing how any of it
/// is constructed. Preferences are exposed as streams, so changing one in
/// settings reaches the screen it controls on the next frame.
///
/// [appDatabaseProvider] deliberately has no default: the bootstrap opens the
/// database, handles the failure outcomes, and overrides it.
///
/// Includes:
///     - appDatabaseProvider and the four repository providers.
///     - The day-log, cycle, prediction and condition read providers.
///     - The recorded medicines, their reminder times, what their labels say
///       about each other, and what they say about the recorded kinds of
///       contraception.
///     - One provider per stored preference.
///     - themeModeFromWireName: Resolves a stored theme mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/data/transfer/protected_backup.dart';
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
/// fail in ways the app must render rather than swallow, so the bootstrap
/// opens it, handles the corrupt and newer-schema outcomes, and overrides this
/// provider with the result. A default here would be a second construction
/// site for the executor, which ADR-0004 rules out, and would let a widget
/// silently open a second connection to the same file.
///
/// Throws:
///     UnimplementedError: If read without the bootstrap's override.
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

/// Seals and opens passphrase-protected backups (ADR-0019).
///
/// A provider so a widget test can swap in a sealer with a low iteration count
/// that runs on the test's own isolate, where it can be waited for.
final Provider<BackupSealer> backupSealerProvider = Provider<BackupSealer>(
  (ref) => const BackupSealer(),
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
/// Presented and nothing more. This is the sentence a flag could not produce,
/// "these six cycles were logged while you were on hormonal contraception",
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

/// Reads and writes the medicines recorded under Conditions and medication.
final Provider<MedicineListRepository> medicineListRepositoryProvider =
    Provider<MedicineListRepository>(
      (ref) =>
          MedicineListRepository(ref.watch(appDatabaseProvider).settingsDao),
    );

/// The recorded medicines, in the order added, kept current as they change.
final StreamProvider<List<RecordedMedicine>> recordedMedicinesProvider =
    StreamProvider<List<RecordedMedicine>>(
      (ref) => ref.watch(medicineListRepositoryProvider).watch(),
    );

/// The times each recorded medicine is to be reminded of, by its key, kept
/// current as they change (ADR-0025).
final StreamProvider<Map<String, List<ReminderTime>>>
medicineRemindersProvider = StreamProvider<Map<String, List<ReminderTime>>>(
  (ref) => ref.watch(medicineListRepositoryProvider).watchReminders(),
);

/// What the recorded medicines' labels say about each other: the conflict
/// flags under Conditions and medication (ADR-0014, ADR-0015).
///
/// Loads the medicines index and each recorded medicine's label, so only the
/// screen that shows the flags watches it, and both are dropped when it
/// closes. A medicine the bundle no longer lists is left out of the
/// comparison; the screen says so under its name.
final AutoDisposeFutureProvider<List<InteractionPair>>
recordedInteractionsProvider =
    FutureProvider.autoDispose<List<InteractionPair>>((
      ref,
    ) async {
      final recorded = await ref.watch(recordedMedicinesProvider.future);
      if (recorded.length < 2) return const <InteractionPair>[];
      final index = await ref.watch(medicineIndexProvider.future);
      final medicines = <MedicineEntry>[
        for (final medicine in recorded) ?index.byKey(medicine.key),
      ];
      return ref.watch(medicineBundleProvider).interactions(medicines);
    });

/// The recorded kinds of contraception the conflict flags compare: the
/// combined pill, the mini pill, the hormonal IUD and the implant, while a
/// record of one runs today (ADR-0021).
///
/// Each kind once, in the order first recorded. The other conditions have no
/// ingredients to count as, and take no part.
final AutoDisposeProvider<List<ConditionKind>> recordedContraceptionProvider =
    Provider.autoDispose<List<ConditionKind>>((ref) {
      final records =
          ref.watch(conditionsProvider).valueOrNull ??
          const <ConditionRecord>[];
      final today = ref.watch(clockProvider).today();
      final table = ref.watch(medicineBundleProvider).groups;
      final kinds = <ConditionKind>[];
      for (final record in records) {
        final kind = table.conditions[record.condition];
        if (kind != null && record.isActiveOn(today) && !kinds.contains(kind)) {
          kinds.add(kind);
        }
      }
      return List<ConditionKind>.unmodifiable(kinds);
    });

/// What the recorded medicines' labels say about the recorded kinds of
/// contraception: the conflict flags for a combined pill recorded among the
/// conditions and rifampin among the medicines (ADR-0021).
///
/// A kind counts as what every product of it shares, since the record does
/// not say which product. One whose own product is among the medicines is
/// left out: that medicine stands for it, with its own label.
final AutoDisposeFutureProvider<List<ConditionPair>>
recordedConditionPairsProvider =
    FutureProvider.autoDispose<List<ConditionPair>>((ref) async {
      final kinds = ref.watch(recordedContraceptionProvider);
      final recorded = await ref.watch(recordedMedicinesProvider.future);
      if (kinds.isEmpty || recorded.isEmpty) return const <ConditionPair>[];
      final index = await ref.watch(medicineIndexProvider.future);
      final medicines = <MedicineEntry>[
        for (final medicine in recorded) ?index.byKey(medicine.key),
      ];
      return ref.watch(medicineBundleProvider).conditions(kinds, medicines);
    });

/// Whether the flow control is collapsed to bleeding yes/no (AND-24).
///
/// A stream, so that turning the toggle on in settings changes the day editor
/// on the next frame rather than the next launch. The default while it loads
/// is the stored default, which is the fuller control: a screen that flickers
/// from simplified to graded on startup would look like it had discarded
/// something.
final StreamProvider<bool> flowSimplifiedProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchFlowSimplified(),
);

/// Whether temperatures are shown in degrees Fahrenheit (ADR-0020).
///
/// Display only: they are stored in Celsius either way.
final StreamProvider<bool> temperatureFahrenheitProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(appDatabaseProvider).settingsDao.watchTemperatureFahrenheit(),
);

/// Asks the device to prove who is holding it (AND-29).
///
/// Overridden in tests with a fake, so the gate's behaviour is exercised
/// headless rather than only on a device: the sixty-second grace period, the
/// refusal path, and the credential-removed path.
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
/// A stream, so that exporting or dismissing takes the banner away on the
/// next frame rather than the next launch. A warning that survives the action
/// it asked for reads as the app not having noticed.
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
/// reader. The tab is the only way to them, and to conditions and medication,
/// so turning it off hides all of them, at the owner's direction.
final StreamProvider<bool> showLearnTabProvider = StreamProvider<bool>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao.watchShowLearnTab(),
);

/// Whether Learn lists Supplements, Pain and movement, and Body composition.
///
/// **Off by default**, at the owner's direction, with no switch for it:
/// holding the Learn tab for ten seconds turns it on, and again turns it off.
final StreamProvider<bool> revealHiddenReferenceProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(appDatabaseProvider).settingsDao.watchRevealHiddenReference(),
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

/// Resolve a stored theme mode name back to a [ThemeMode].
///
/// Falls back rather than throwing, because the value comes off disk and a
/// database written by a build with a mode this one lacks must still open.
///
/// Args:
///     wireName (String?): The stored name, or null when nothing is stored.
///
/// Returns:
///     ThemeMode: The matching mode, or [ThemeMode.light] when the name is
///     absent or unknown. Light is the default the app ships with.
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
