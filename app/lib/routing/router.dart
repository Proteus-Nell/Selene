import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/onboarding/onboarding_screen.dart';
import 'package:period_tracker/features/settings/settings_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppScaffold(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.log,
                builder: (context, state) => const LogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.insights,
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
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

/// The persistent frame around the four main screens.
class AppScaffold extends StatelessWidget {
  /// Wraps [shell], the branch navigator go_router manages.
  const AppScaffold({required this.shell, super.key});

  /// The active branch.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.edit_calendar_outlined),
            selectedIcon: const Icon(Icons.edit_calendar),
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
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
