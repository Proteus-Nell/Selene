// Leaving a tab and coming back lands on that tab's main page (AND-39).
//
// This exists because the first attempt at it did not work on a device and
// shipped anyway, having been written without a test. `goBranch` with
// `initialLocation: true` moves go_router's own location, and every screen
// under a tab here is pushed with `Navigator.push` rather than declared as a
// `GoRoute`. An imperatively pushed route is not part of that location, so it
// outlived the call and the reader was put back where they had been.
//
// So the flow below is the one a person performs, not the API call that was
// supposed to implement it: open a tab, go into a page under it, leave for
// another tab, come back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/learn/learn_screen.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';
import 'package:period_tracker/routing/router.dart';

import 'harness.dart';

/// Pumps a fixed number of frames rather than settling.
///
/// `pumpAndSettle` never returns against the real shell: the companion in the
/// bottom bar animates while it is idle, so the tree is never quiet. The smoke
/// flow pumps for a fixed span for the same reason.
Future<void> pumpFor(WidgetTester tester, [int seconds = 1]) async {
  await tester.pump();
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  /// The real router and the real shell, over an in-memory database.
  ///
  /// Built from `routerProvider` rather than through `buildAppScope`, which is
  /// asynchronous: awaiting a drift read before `pumpWidget` never returns
  /// inside `testWidgets`, because that future completes on the real event
  /// loop and only `runAsync` turns it. Onboarding is overridden instead,
  /// which is the one thing that read decides.
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

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await pumpFor(tester);
  }

  /// Scrolls to a row and opens it.
  ///
  /// `scrollUntilVisible` rather than `ensureVisible`: these are lazy lists,
  /// so a row far enough down has not been built yet and there is no element
  /// to ensure the visibility of. Settings' Appearance row is one.
  Future<void> openRow(WidgetTester tester, String label) async {
    final row = find.text(label);
    if (row.evaluate().isEmpty) {
      await tester.scrollUntilVisible(row, 120);
      await pumpFor(tester);
    }
    await tester.ensureVisible(row);
    await pumpFor(tester);
    await tester.tap(row);
    await pumpFor(tester);
  }

  testWidgets('Learn comes back to its list, not the page left open', (
    tester,
  ) async {
    await pumpApp(tester);
    final strings = l10n(tester);

    await tapTab(tester, strings.navLearn);
    expect(find.byType(LearnScreen), findsOneWidget);

    await openRow(tester, strings.settingsLookup);
    expect(find.byType(LookupScreen), findsOneWidget);

    await tapTab(tester, strings.navCalendar);
    await tapTab(tester, strings.navLearn);

    expect(
      find.byType(LookupScreen),
      findsNothing,
      reason: 'Learn reopened on the page that was left behind',
    );
    expect(find.byType(LearnScreen), findsOneWidget);
  });

  testWidgets('Settings does the same', (tester) async {
    // The rule is every tab, so it is checked on more than the one it was
    // reported against.
    await pumpApp(tester);
    final strings = l10n(tester);

    await tapTab(tester, strings.navSettings);
    await openRow(tester, strings.settingsAppearance);
    expect(find.text(strings.appearanceSchemeNote), findsOneWidget);

    await tapTab(tester, strings.navLog);
    await tapTab(tester, strings.navSettings);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.text(strings.appearanceSchemeNote),
      findsNothing,
      reason: 'Settings reopened on the appearance page',
    );
  });

  testWidgets('tapping the tab already open empties it too', (tester) async {
    await pumpApp(tester);
    final strings = l10n(tester);

    await tapTab(tester, strings.navLearn);
    await openRow(tester, strings.settingsLookup);
    expect(find.byType(LookupScreen), findsOneWidget);

    await tapTab(tester, strings.navLearn);
    expect(find.byType(LookupScreen), findsNothing);
  });
}
