import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Override> overrides = const <Override>[],
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
      // Last, so a caller can replace any of the above. Added for the app lock,
      // whose service is a platform channel and has to be faked per test.
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // `builder`, not a MediaQuery around `home`, and copyWith rather than a
      // fresh MediaQueryData. Both matter and both were wrong here.
      //
      // `builder` inserts above the Navigator, so routes pushed on top of the
      // home screen see this too. Wrapped around `home` it sat *below* the
      // Navigator, which meant every dialog and bottom sheet in the suite was
      // laid out at 1.0 regardless of what a test asked for — a text-scale test
      // that opened a dialog was asserting about unscaled text.
      //
      // copyWith keeps the view's own size, padding and devicePixelRatio. The
      // fresh MediaQueryData that used to be here reported a size of zero to
      // everything below it.
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          accessibleNavigation: accessibleNavigation,
        ),
        child: navigator!,
      ),
      home: child,
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

/// Registers the bundled Figtree faces with the engine, for this test file.
///
/// `flutter test` does not load the fonts declared in pubspec.yaml. Anything
/// asking for a family it does not know gets Ahem, whose glyphs are solid
/// rectangles — so without this the goldens are pages of black bars, and a
/// change that halved the line height would not move a pixel of them.
///
/// **Called only from the golden tests, deliberately.** It is tempting to put
/// this in a `flutter_test_config.dart` and have the whole suite render the
/// real typeface, and that breaks `a11y_test.dart` — not because the app is
/// wrong but because of how `textContrastGuideline` measures. It takes the
/// pixels under a semantics node, splits them into a light group and a dark
/// group, and compares the *most frequent* colour in each. Ahem's fat solid
/// glyphs make the text the mode of the dark group, so the ratio it reports is
/// the one between the two theme tokens, which is the thing worth asserting.
/// Real text at 14px is thin and anti-aliased: its edge pixels outnumber its
/// cores, and on a selected chip the mode of the light group came back as the
/// 1px *border* and the mode of the dark group as the *fill*. It reported
/// 3.75:1 for a pair that is 9.66:1, having never sampled a glyph.
///
/// So the two are measuring different things and both are worth having. The
/// goldens show what the app looks like; `a11y_test.dart` and `theme_test.dart`
/// hold the colour pairs, on a font whose pixels are unambiguous.
Future<void> loadBundledFonts() async {
  final figtree = FontLoader('Figtree');
  for (final weight in const <int>[400, 500, 600, 700]) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    figtree.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await figtree.load();
}
