// Learn and the companion are opt-in, and hiding one must not move the others.
//
// The Learn tab is the interesting half. The shell keeps all five branches
// whatever the bar shows, so a hidden destination makes the index the user taps
// stop matching the branch behind it: with Learn gone, Settings is the fourth
// destination and the fifth branch. Getting that wrong is not a crash, it is a
// tap on Settings that opens Learn, which nothing else in the suite would
// notice — the destinations would still all be there and every screen would
// still build.
//
// So the case that matters here is not "is the tab hidden" but "does the tab
// after it still go where it says".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/companion/companion_dock.dart';
import 'package:period_tracker/features/learn/learn_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';
import 'package:period_tracker/routing/router.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// The real router and shell, over an in-memory database.
  ///
  /// Built from `routerProvider` rather than `buildAppScope` for the reason
  /// `tab_reset_test.dart` records: that helper awaits a drift read, and a
  /// future awaited before `pumpWidget` inside `testWidgets` completes on the
  /// real event loop, which the fake-async zone never turns.
  Future<void> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(testClock),
        quarantinedDatabaseProvider.overrideWithValue(null),
        onboardingCompleteProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await pumpFor(tester);
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  group('the Learn tab', () {
    testWidgets('is absent until it is switched on', (tester) async {
      await pumpApp(tester);
      expect(
        find.text(l10n(tester).navLearn),
        findsNothing,
        reason: 'Learn is opt-in, so a fresh install should not show the tab',
      );
    });

    testWidgets('appears once the preference is set', (tester) async {
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await pumpApp(tester);
      expect(find.text(l10n(tester).navLearn), findsOneWidget);
    });

    testWidgets('does not take the next tab with it when hidden', (
      tester,
    ) async {
      // The whole reason this file exists. Settings is the fifth branch and,
      // with Learn hidden, the fourth destination.
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navSettings));
      await pumpFor(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.byType(LearnScreen),
        findsNothing,
        reason:
            'tapping Settings opened Learn, which is the destination index '
            'being used as a branch index',
      );
    });

    testWidgets('still reaches Settings when it is shown', (tester) async {
      // The same tap with the mapping shifted the other way, so a fix that
      // hard-codes the hidden case does not pass.
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navSettings));
      await pumpFor(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(LearnScreen), findsNothing);
    });

    testWidgets('leaves its pages reachable from Settings', (tester) async {
      // Movement and body composition had no home outside the Learn tab. With
      // the tab off by default they would be unreachable, which is a feature
      // deleted by a preference rather than hidden by one.
      // Settings is a lazy ListView, so a row below the fold is not built at
      // all. Rather than scroll past each one in turn, the window is made tall
      // enough to hold the screen: what is being checked is that the rows
      // exist, not where they sit.
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navSettings));
      await pumpFor(tester);

      final strings = l10n(tester);
      for (final title in <String>[
        strings.settingsLookup,
        strings.settingsNutrition,
        strings.movementEntryTitle,
        strings.weightEntryTitle,
        strings.settingsConditions,
      ]) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: '"$title" is reachable only from the Learn tab',
        );
      }
    });
  });

  group('the companion', () {
    testWidgets('is absent until it is switched on', (tester) async {
      await pumpApp(tester);
      expect(find.byType(CompanionButton), findsNothing);
    });

    testWidgets('appears once the preference is set', (tester) async {
      await db.settingsDao.writeBool(SettingKey.showCompanion, value: true);
      await pumpApp(tester);
      expect(find.byType(CompanionButton), findsOneWidget);
    });

    testWidgets('hiding it leaves the navigation bar working', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navSettings));
      await pumpFor(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
