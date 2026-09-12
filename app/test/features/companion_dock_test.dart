// The companion as a piece of interface (AND-37).
//
// Four claims are load-bearing here, and each one is a property of the layout
// or of the widget tree rather than something to eyeball:
//
//   * it covers nothing. The brief was a persistent presence that blocks no
//     content and hides no tap target, and a floating badge cannot promise
//     either — it sits over the last line of every scrolled list and over the
//     conditions screen's extended button. Giving it a slot in the bar makes
//     "covers nothing" a fact about the rectangles, and the rectangles are
//     asserted below;
//   * it is a control, so it has a name a screen reader can announce, a 48dp
//     target, and a suggestion that is readable rather than painted;
//   * it says nothing at all until it is tapped, and what it says can be
//     dismissed;
//   * its idle animation collapses under "remove animations" and stops when
//     the app is not in front of anyone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/companion/companion_dock.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';
import 'package:period_tracker/features/companion/companion_providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

import 'companion_lines_test.dart' show everythingItCanSay;
import 'harness.dart';

/// A screen shaped like the app's shell: content, and the dock underneath it.
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: const Placeholder(key: ValueKey<String>('body')),
      bottomNavigationBar: CompanionDock(
        navigationBar: NavigationBar(
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.edit_calendar_outlined),
              label: l10n.navLog,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              label: l10n.navCalendar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              label: l10n.navInsights,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpShell(
    WidgetTester tester, {
    CompanionLine? line,
    bool disableAnimations = true,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(
        const _Shell(),
        database: db,
        disableAnimations: disableAnimations,
        textScaler: textScaler,
        overrides: <Override>[
          if (line != null) companionLineProvider.overrideWithValue(line),
        ],
      ),
    );
    if (disableAnimations) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('where it sits', () {
    testWidgets('is beside the navigation bar and not on top of it', (
      tester,
    ) async {
      await pumpShell(tester);
      final companion = tester.getRect(find.byType(CompanionButton));
      final bar = tester.getRect(find.byType(NavigationBar));
      expect(
        companion.overlaps(bar),
        isFalse,
        reason:
            'The companion is over the navigation bar, which means it is over '
            'a tap target. It has a slot of its own precisely so that it is '
            'not.',
      );
    });

    testWidgets('is below the content rather than over it', (tester) async {
      await pumpShell(tester);
      final companion = tester.getRect(find.byType(CompanionButton));
      final body = tester.getRect(find.byKey(const ValueKey<String>('body')));
      expect(
        companion.top,
        greaterThanOrEqualTo(body.bottom),
        reason:
            'The companion has moved into the body, so it is now covering the '
            'end of whatever the user is reading. It belongs in the furniture, '
            'not over the page.',
      );
    });

    testWidgets('meets the tap target floor', (tester) async {
      await pumpShell(tester);
      final size = tester.getSize(find.byType(CompanionButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('and the four destinations still fit beside it at 200%', (
      tester,
    ) async {
      // The companion takes its width from the navigation bar. Four labels in
      // the space that is left, at the largest scale the plan requires, is the
      // arrangement most likely to overflow.
      await pumpShell(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
      expect(find.byType(CompanionButton), findsOneWidget);
    });
  });

  group('what it says', () {
    testWidgets('says nothing at all until it is tapped', (tester) async {
      // It is on every screen in the app. A suggestion painted beside it would
      // be a sentence about the user's cycle, permanently on display, over the
      // shoulder of whoever is standing behind them.
      await pumpShell(tester, line: CompanionLine.cramps);
      for (final sentence in everythingItCanSay.values) {
        expect(find.text(sentence), findsNothing);
      }
    });

    testWidgets('shows the current line when tapped', (tester) async {
      await pumpShell(tester, line: CompanionLine.cramps);
      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();
      expect(
        find.text(everythingItCanSay[CompanionLine.cramps]!),
        findsOneWidget,
      );
    });

    testWidgets('can be dismissed', (tester) async {
      await pumpShell(tester, line: CompanionLine.nothingToPointAt);
      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.companionDismiss));
      await tester.pumpAndSettle();
      expect(
        find.text(everythingItCanSay[CompanionLine.nothingToPointAt]!),
        findsNothing,
      );
    });

    // Two tests here checked that the citation note appeared under a line
    // carrying a health claim and not under one claiming nothing. That note
    // named a file in the source repository and was removed at the owner's
    // direction, so there is no longer a note to place or withhold.
    // `CompanionLine.carriesHealthClaim` still exists and is still asserted
    // in `companion_sources_test.dart`, which is where the split is now held.

    testWidgets('reads the user own state rather than a fixed answer', (
      tester,
    ) async {
      // The provider chain, unmocked: a symptom written to the database, and
      // the line the rules pick for it.
      await db.dayLogDao.saveAll(<DayLog>[
        DayLog(
          date: testClock.today(),
          symptoms: const <Symptom, SymptomSeverity>{
            Symptom.cramps: SymptomSeverity.moderate,
          },
        ),
      ]);
      await pumpShell(tester);
      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();
      expect(
        find.text(everythingItCanSay[CompanionLine.cramps]!),
        findsOneWidget,
      );
    });
  });

  group('to a screen reader', () {
    testWidgets('it is a named button, and its suggestion is readable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, line: CompanionLine.cramps);

      // Named the way every other icon-only control in this app is named — an
      // IconButton tooltip, which Flutter puts into the node a screen reader
      // announces. Asserted on the semantics node rather than on the widget,
      // because a tooltip that never reaches the tree is decoration.
      final l10n = l10nOf(tester);
      expect(find.byTooltip(l10n.companionLabel), findsOneWidget);
      final node = tester.getSemantics(find.byType(CompanionButton));
      expect(
        '${node.label} ${node.tooltip}',
        contains(l10n.companionLabel),
        reason:
            'The companion has no name in the semantics tree. It is a control '
            'on every screen in the app, and an unlabelled control is an '
            'unusable one.',
      );

      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(everythingItCanSay[CompanionLine.cramps]!),
        findsOneWidget,
        reason:
            'The suggestion is not in the semantics tree, so it is a picture '
            'of a sentence rather than a sentence.',
      );
      handle.dispose();
    });

    testWidgets('meets the guidelines, with and without the sheet open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, line: CompanionLine.heavyBleeding);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(find.byType(CompanionButton));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('the idle animation', () {
    testWidgets('is a multiple of the standard token, and collapses with it', (
      tester,
    ) async {
      // Derived rather than declared, so "remove animations" reaches it for
      // free: zero times anything is zero.
      late BuildContext moving;
      late BuildContext still;
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: <Widget>[
            MediaQuery(
              data: const MediaQueryData(),
              child: Builder(
                builder: (context) {
                  moving = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  still = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      );
      expect(
        CompanionBreath.of(moving),
        Motion.standard(moving) * CompanionBreath.standards,
      );
      expect(
        CompanionBreath.of(still),
        Duration.zero,
        reason:
            'The breath survives "remove animations". Motion in the corner of '
            'every screen is the worst possible place to ignore that setting.',
      );
    });

    testWidgets('runs no ticker at all with animations off', (tester) async {
      await pumpShell(tester);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            'Something is still animating with animations disabled. The mark '
            'is meant to be painted at rest and left alone.',
      );
      // And the drawing is still there. Nothing in this app may need an
      // animation to have run in order to be visible.
      expect(find.byType(CompanionMark), findsWidgets);
    });

    testWidgets('breathes when it is allowed to', (tester) async {
      await pumpShell(tester, disableAnimations: false);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('stops when the app goes behind something', (tester) async {
      await pumpShell(tester, disableAnimations: false);
      expect(tester.hasRunningAnimations, isTrue);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            'It is still animating behind the recent-apps switcher, or behind '
            'the system credential prompt the app lock puts up. Both are '
            'frames nobody can see.',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'it never started again after coming back',
      );
    });
  });
}
