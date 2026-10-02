// The Learn tab is opt-in, and hiding it must not move the other tabs.
//
// The shell keeps all five branches
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

    testWidgets('keeps its pages out of Settings', (tester) async {
      // At the owner's direction, the reference pages and conditions and
      // medication are shown only to someone who has switched this tab on.
      // Settings is a lazy ListView, so a row below the fold is not built at
      // all. Rather than scroll past each one in turn, the window is made tall
      // enough to hold the screen: what is being checked is that the rows are
      // absent, not where they would sit.
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navSettings));
      await pumpFor(tester);

      for (final title in _pages(l10n(tester))) {
        expect(
          find.text(title),
          findsNothing,
          reason: '"$title" is listed in Settings',
        );
      }
    });

    testWidgets('holds every one of those pages once they are revealed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
      await db.settingsDao.writeBool(
        SettingKey.revealHiddenReference,
        value: true,
      );
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navLearn));
      await pumpFor(tester);

      expect(find.byType(LearnScreen), findsOneWidget);
      for (final title in _pages(l10n(tester))) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: '"$title" is missing from the Learn tab',
        );
      }
    });
  });

  group('the pages Learn keeps back', () {
    /// Holds the Learn tab down for [hold], then lets go and opens Learn.
    Future<void> holdLearn(WidgetTester tester, Duration hold) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(l10n(tester).navLearn)),
      );
      await tester.pump(hold);
      await gesture.up();
      // Long enough for the tab's tooltip and the message to go again.
      await pumpFor(tester, 6);
      await tester.tap(find.text(l10n(tester).navLearn));
      await pumpFor(tester);
      expect(find.byType(LearnScreen), findsOneWidget);
    }

    setUp(() async {
      await db.settingsDao.writeBool(SettingKey.showLearnTab, value: true);
    });

    testWidgets('are not listed until the tab is held', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(l10n(tester).navLearn));
      await pumpFor(tester);
      final strings = l10n(tester);
      expect(find.text(strings.settingsLookup), findsOneWidget);
      expect(find.text(strings.settingsConditions), findsOneWidget);
      for (final title in _keptBack(strings)) {
        expect(find.text(title), findsNothing, reason: '"$title" is listed');
      }
    });

    testWidgets('are listed once the tab is held for ten seconds', (
      tester,
    ) async {
      await pumpApp(tester);
      await holdLearn(tester, revealHold);
      for (final title in _keptBack(l10n(tester))) {
        expect(find.text(title), findsOneWidget, reason: '"$title" is not');
      }
    });

    testWidgets('stay back after a shorter hold', (tester) async {
      await pumpApp(tester);
      await holdLearn(tester, revealHold - const Duration(seconds: 1));
      for (final title in _keptBack(l10n(tester))) {
        expect(find.text(title), findsNothing, reason: '"$title" is listed');
      }
    });

    testWidgets('go back once the tab is held again', (tester) async {
      await db.settingsDao.writeBool(
        SettingKey.revealHiddenReference,
        value: true,
      );
      await pumpApp(tester);
      await holdLearn(tester, revealHold);
      for (final title in _keptBack(l10n(tester))) {
        expect(find.text(title), findsNothing, reason: '"$title" is listed');
      }
    });
  });
}

/// The pages the Learn tab is the only way to.
List<String> _pages(AppLocalizations strings) => <String>[
  strings.settingsLookup,
  ..._keptBack(strings),
  strings.settingsConditions,
];

/// The pages Learn lists only once its tab has been held.
List<String> _keptBack(AppLocalizations strings) => <String>[
  strings.settingsNutrition,
  strings.movementEntryTitle,
  strings.weightEntryTitle,
];
