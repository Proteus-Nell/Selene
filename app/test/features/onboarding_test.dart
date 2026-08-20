// Onboarding (AND-12).
//
// The disclaimer is the first thing a new user sees, and docs/PLAN.md 6.2 is
// its copy spec. These tests pin the parts that would be tempting to soften:
// that the non-claims are on screen rather than behind a link, and that
// nothing here asks for a notification permission.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/onboarding/onboarding_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(OnboardingScreen(onFinished: () {}), database: db),
    );
    await tester.pumpAndSettle();
  }

  group('the disclaimer', () {
    testWidgets('is a screen the user reads, not a buried EULA', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.onboardingTitle), findsOneWidget);
      // All four non-claims are on this screen, not behind an expander, a
      // link, or a scroll-to-accept gate. The last of them can sit below the
      // fold on a short viewport, which is ordinary reading, so it is looked
      // for in the tree rather than only in the visible rect.
      for (final claim in <String>[
        l10n.onboardingNotContraception,
        l10n.onboardingNotMedical,
        l10n.onboardingNotDiagnostic,
        l10n.onboardingAlwaysARange,
      ]) {
        expect(find.text(claim, skipOffstage: false), findsOneWidget);
      }
      // The first one needs no scrolling at all.
      expect(find.text(l10n.onboardingNotContraception), findsOneWidget);
      // And nothing gates the button on having scrolled.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.onboardingAcknowledge),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('says the app is not contraception, in those words', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final text = l10nOf(tester).onboardingNotContraception.toLowerCase();
      expect(text, contains('not contraception'));
      // And never the inverse claim, which would move this app into
      // medical-device territory.
      expect(text, isNot(contains('safe day')));
      expect(text, isNot(contains('protected')));
    });

    testWidgets('uses gender-neutral language throughout', (tester) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      final copy = <String>[
        l10n.onboardingIntro,
        l10n.onboardingNotContraception,
        l10n.onboardingNotMedical,
        l10n.onboardingNotDiagnostic,
        l10n.onboardingAlwaysARange,
        l10n.onboardingFirstEntryBody,
      ].join(' ').toLowerCase();
      // Trans men and nonbinary people menstruate (docs/PLAN.md 6.3).
      expect(copy, isNot(contains('women')));
      expect(copy, isNot(contains('woman')));
      expect(copy, isNot(contains('she ')));
      expect(copy, isNot(contains('her ')));
    });

    testWidgets('never guesses at pregnancy', (tester) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      // A missed period is a data state, not a life event to comment on.
      // "pregnancy" may appear only inside the non-claim that rules it out.
      expect(l10n.onboardingIntro.toLowerCase(), isNot(contains('pregnan')));
      expect(
        l10n.onboardingFirstEntryBody.toLowerCase(),
        isNot(contains('pregnan')),
      );
    });
  });

  group('the flow', () {
    testWidgets('does not ask for a notification permission', (tester) async {
      // Asking at first launch gets denied by reflex, and Android 13+ makes
      // re-asking after a denial deliberately hard (2.4.3). The request belongs
      // in AND-17, after the first cycle is logged.
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.settingsReminderEnabled), findsNothing);
      expect(find.textContaining('otification'), findsNothing);

      await tester.tap(find.text(l10n.onboardingAcknowledge));
      await tester.pumpAndSettle();
      expect(find.textContaining('otification'), findsNothing);
    });

    testWidgets('reaches the first entry after acknowledging', (tester) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.onboardingAcknowledge));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingFirstEntryTitle), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets('one date is enough to reach a working state', (tester) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.onboardingAcknowledge));
      await tester.pumpAndSettle();

      // Pick a day from the inline picker, then save.
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(await db.dayLogDao.allLogs(), hasLength(1));
      expect(
        await db.settingsDao.readBool(
          SettingKey.onboardingComplete,
          orElse: false,
        ),
        isTrue,
      );
    });

    testWidgets('skipping still completes onboarding', (tester) async {
      // Someone who does not remember the date must not be stuck on this
      // screen: the app is usable with nothing logged, and says so.
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.onboardingAcknowledge));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.onboardingFirstEntrySkip));
      await tester.pumpAndSettle();

      expect(await db.dayLogDao.allLogs(), isEmpty);
      expect(
        await db.settingsDao.readBool(
          SettingKey.onboardingComplete,
          orElse: false,
        ),
        isTrue,
      );
    });
  });
}
