import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/core/theme.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';

/// The day every screen test is pinned to.
final FixedClock testClock = FixedClock.iso('2026-06-30');

/// Wraps [child] in everything a screen needs, over an in-memory database.
///
/// One harness rather than a set-up copied into each test file: the overrides
/// are the contract between the UI and the data layer, and duplicating them
/// means half the suite quietly testing a different app.
Widget harness(
  Widget child, {
  required AppDatabase database,
  Clock? clock,
  RingLogger? logger,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool accessibleNavigation = false,
}) {
  final resolvedClock = clock ?? testClock;
  // The container is owned by the test rather than by a ProviderScope widget,
  // and disposed in a tear-down. That is not a style preference: drift's stream
  // queries schedule a zero-duration timer when their subscription is
  // cancelled, and a ProviderScope disposes its providers while the framework
  // is tearing the tree down at the end of the test body, which is *before*
  // flutter_test checks for pending timers. The result is a failure that looks
  // like the screen's fault and then wedges the test runner for minutes.
  // Disposing after the check moves the timer out of the way.
  final container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(resolvedClock),
      loggerProvider.overrideWithValue(
        logger ?? RingLogger(clock: resolvedClock),
      ),
      quarantinedDatabaseProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: textScaler,
          accessibleNavigation: accessibleNavigation,
        ),
        child: child,
      ),
    ),
  );
}

/// The localisations, reached from a pumped widget tree.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Logs a history whose observed cycle lengths are [lengths].
///
/// The last bleeding day lands [endingDaysAgo] before the test clock's today,
/// so no day is written in the future. Returns the most recent period start.
Future<CivilDate> seedHistory(
  AppDatabase database,
  List<int> lengths, {
  int endingDaysAgo = 0,
  int bleedingDays = 4,
  CivilDate? today,
}) async {
  final now = today ?? testClock.today();
  final total = lengths.fold<int>(0, (sum, length) => sum + length);
  final lastStart = now.addDays(-endingDaysAgo - (bleedingDays - 1));
  final logs = <DayLog>[];
  var start = lastStart.addDays(-total);
  for (final length in lengths) {
    for (var i = 0; i < bleedingDays; i++) {
      logs.add(
        DayLog(date: start.addDays(i), flow: FlowIntensity.medium),
      );
    }
    start = start.addDays(length);
  }
  for (var i = 0; i < bleedingDays; i++) {
    logs.add(
      DayLog(date: lastStart.addDays(i), flow: FlowIntensity.medium),
    );
  }
  await database.dayLogDao.saveAll(logs);
  return lastStart;
}

/// A fresh in-memory database.
AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());
