import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/companion/companion_dock.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/learn/learn_screen.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/onboarding/onboarding_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/notifications/notification_sync.dart';

/// Where each screen lives.
///
/// Paths as constants rather than string literals at every call site: a typo in
/// a literal is a runtime 404 that only shows up when someone taps that one
/// button.
abstract final class Routes {
  /// First-run disclaimer and first entry.
  static const String onboarding = '/onboarding';

  /// Today's state and the primary logging action. The app's home.
  static const String log = '/log';

  /// Month grid.
  static const String calendar = '/calendar';

  /// Prediction, history and self-metrics.
  static const String insights = '/insights';

  /// The reference pages, collected (AND-39).
  static const String learn = '/learn';

  /// Data controls, privacy text and the activity log.
  static const String settings = '/settings';
}

/// Decides whether navigation to [state] may proceed.
///
/// Returns null to allow, or a path to redirect to.
typedef RouteGuard = String? Function(
  BuildContext context,
  GoRouterState state,
);

/// The navigation guard. Currently a no-op that allows everything.
///
/// The hook exists now because the deferred app lock (`docs/DECISIONS.md`,
/// "Deferred note: App lock") is specified to enforce itself as a route guard,
/// and it is the one enforcement point a deep link cannot go around. Adding it
/// later would mean finding every navigation path; adding the seam now costs a
/// provider override.
final Provider<RouteGuard> routeGuardProvider = Provider<RouteGuard>(
  (ref) =>
      (context, state) => null,
);

/// Whether the user has finished onboarding.
///
/// Read once at startup and overridden by the bootstrap, rather than watched:
/// the answer only changes when the user finishes onboarding, and that path
/// navigates explicitly.
final Provider<bool> onboardingCompleteProvider = Provider<bool>(
  (ref) => false,
);

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

/// One navigator key per branch, so a tab can be emptied when it is opened.
///
/// Needed because every screen under a tab is pushed imperatively with
/// `Navigator.push` rather than declared as a `GoRoute`. `goBranch` moves
/// go_router's own location, and an imperatively pushed route is not part of
/// that: it sits on the branch's `Navigator` and stays there. Resetting a tab
/// therefore means popping its navigator, which needs a handle on it.
final List<GlobalKey<NavigatorState>> _branchKeys =
    List<GlobalKey<NavigatorState>>.generate(
      5,
      (index) => GlobalKey<NavigatorState>(debugLabel: 'branch$index'),
    );

/// Builds the app's router.
GoRouter buildRouter(Ref ref) {
  final onboarded = ref.watch(onboardingCompleteProvider);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: onboarded ? Routes.log : Routes.onboarding,
    redirect: (context, state) => ref.read(routeGuardProvider)(context, state),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppScaffold(shell: shell),
        // A cross-fade instead of go_router's plain IndexedStack (AND-34). The
        // five tabs are peers, not a stack, so nothing slides sideways: a
        // horizontal transition tells the user they have gone deeper into
        // something, and moving between the calendar and settings is not that.
        navigatorContainerBuilder: _fadeThroughBranches,
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _branchKeys[0],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.log,
                builder: (context, state) => const LogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchKeys[1],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchKeys[2],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.insights,
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchKeys[3],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.learn,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _branchKeys[4],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The router, rebuilt if the onboarding state is overridden.
final Provider<GoRouter> routerProvider = Provider<GoRouter>(buildRouter);

/// The persistent frame around the main screens.
///
/// The shell always holds five branches, whatever the navigation bar shows.
/// Learn being optional is a question of which destinations are offered, not of
/// how many navigators exist: dropping a branch would renumber the others, move
/// every `_branchKeys` index, and rebuild the router the moment the preference
/// changed. The branch stays, the destination goes, and [_visibleBranches] maps
/// what the user taps back to the branch it belongs to.
class AppScaffold extends ConsumerWidget {
  /// Wraps [shell], the branch navigator go_router manages.
  const AppScaffold({required this.shell, super.key});

  /// The active branch.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final showLearn = ref.watch(showLearnTabProvider).valueOrNull ?? false;
    final showCompanion = ref.watch(showCompanionProvider).valueOrNull ?? false;
    final branches = _visibleBranches(showLearn: showLearn);
    // The Learn branch can be the one in view when the preference is turned
    // off from Settings — which is itself a different tab, so in practice this
    // is the deep-link and restore case. Falling back to the first destination
    // beats a NavigationBar with selectedIndex pointing at nothing.
    final selected = branches.indexOf(shell.currentIndex);
    return Scaffold(
      // Wrapped here rather than in a screen: the requirement is to reschedule
      // on every prediction change, and a screen only does that while it is on
      // top.
      body: NotificationSync(child: shell),
      // The companion shares the bar rather than floating above the content
      // (AND-37). Everything inside this Scaffold's body is a screen somebody
      // is reading, including the ones pushed on top of a branch, so the one
      // place a persistent presence can sit without covering something is the
      // furniture around them.
      bottomNavigationBar: CompanionDock(
        showCompanion: showCompanion,
        navigationBar: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected,
          // Always the branch's initial location, not only when the tab
          // already selected is tapped again. A stateful shell otherwise
          // keeps each branch's navigation stack, so leaving Learn from
          // inside "Look something up" and coming back later drops the
          // reader into that page rather than the list they were expecting
          // — and the same for Settings and Insights, which also have pages
          // under them. Tapping a tab now means the same thing every time.
          //
          // What this gives up is resuming a sub-page after a glance at
          // another tab. That is a real loss, and it is the smaller one:
          // arriving somewhere you did not ask for is more disorienting than
          // having to tap once more to get back.
          onDestinationSelected: (index) {
            // The tapped destination is an index into what is on screen, which
            // is not the branch index once Learn is hidden.
            final branch = branches[index];
            // Empty the branch first, then switch to it. `goBranch` alone is
            // not enough: it sets go_router's location, and the reference
            // pages are pushed imperatively, so they outlive it and the
            // reader lands back on whichever one they left.
            _branchKeys[branch].currentState?.popUntil(
              (route) => route.isFirst,
            );
            shell.goBranch(branch, initialLocation: true);
          },
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.schedule_outlined),
              selectedIcon: const Icon(Icons.schedule),
              label: l10n.navLog,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: l10n.navCalendar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: l10n.navInsights,
            ),
            if (showLearn)
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: l10n.navLearn,
              ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// The branch index behind each destination the navigation bar is showing.
///
/// The shell's branches never change; the destinations do. Returning the
/// mapping rather than recomputing an offset at each call site is what stops a
/// hidden Learn tab turning a tap on Settings into a jump to Learn.
List<int> _visibleBranches({required bool showLearn}) => <int>[
  0,
  1,
  2,
  if (showLearn) 3,
  4,
];

/// Builds the container that holds the branch navigators (AND-34).
///
/// Replaces `StatefulShellRoute.indexedStack`, which switches branches on the
/// frame the tab is tapped. The branches themselves are unchanged: every one
/// stays alive with its own navigation stack, which is the whole reason for a
/// stateful shell.
Widget _fadeThroughBranches(
  BuildContext context,
  StatefulNavigationShell shell,
  List<Widget> children,
) => _FadeThroughBranches(currentIndex: shell.currentIndex, children: children);

/// Cross-fades one branch out and the next in, over [Motion.standard].
///
/// The outgoing branch leaves over the first third and the incoming arrives
/// over the rest, rather than both sitting half-transparent on top of each
/// other, which is what makes a cross-fade look like a rendering fault.
///
/// Every child is wrapped identically whatever its state, and the wrappers only
/// change their flags. Swapping one widget for another around a branch would
/// mean tearing that branch's `Navigator` down and rebuilding it every time the
/// user changed tab, which is the one thing a stateful shell exists to avoid.
///
/// Off-branch children are `Offstage`, exactly as `IndexedStack` leaves them.
/// That is load-bearing rather than an optimisation: an offstage subtree is
/// skipped by every default `Finder`, so the five screens do not all answer a
/// `find.text` at once — and the branch on its way out stops being offstage for
/// only as long as it is still being painted.
class _FadeThroughBranches extends StatefulWidget {
  const _FadeThroughBranches({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<_FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<_FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  /// Runs 0 to 1 on a branch change, and rests at 1.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Opacity of the branch being entered: nothing until the handover.
  late final CurvedAnimation _arriving = CurvedAnimation(
    parent: _controller,
    curve: const Interval(_handover, 1, curve: Motion.curve),
  );

  /// Opacity of the branch being left: gone by the handover.
  late final CurvedAnimation _leavingFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, _handover, curve: Motion.curve),
  );

  /// The branch being left. Null once it has finished leaving.
  int? _leaving;

  @override
  void didUpdateWidget(_FadeThroughBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _leaving = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _arriving.dispose();
    _leavingFade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.duration = Motion.standard(context);
    // Rebuilt on every tick so that the frame the transition finishes is also
    // the frame the branch left behind goes offstage again. With animations
    // off the controller is already complete here, so it never appears at all.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final leaving = _controller.isCompleted ? null : _leaving;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (var index = 0; index < widget.children.length; index++)
              _branch(index, leaving: leaving),
          ],
        );
      },
    );
  }

  Widget _branch(int index, {required int? leaving}) {
    final active = index == widget.currentIndex;
    return Offstage(
      key: ValueKey<int>(index),
      offstage: !active && index != leaving,
      child: TickerMode(
        enabled: active,
        // On its way out and no longer the screen the user is on: it must not
        // take a tap meant for what is arriving over it, and a screen reader
        // must never be handed two screens at once.
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: FadeTransition(
              opacity: active ? _arriving : ReverseAnimation(_leavingFade),
              child: widget.children[index],
            ),
          ),
        ),
      ),
    );
  }

  /// Where the outgoing branch has finished leaving and the next starts to
  /// arrive.
  static const double _handover = 0.3;
}
