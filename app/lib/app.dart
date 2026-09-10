import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/core/theme.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/routing/router.dart';
import 'package:period_tracker/security/lock_gate.dart';

/// The application widget.
///
/// Deliberately thin: it wires the router, the themes and localisation, and
/// nothing else. Everything with behaviour lives behind a provider so that a
/// widget test can replace it.
class PeriodTrackerApp extends ConsumerWidget {
  /// Creates the app.
  const PeriodTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both fall back while the read is in flight rather than holding a blank
    // frame. A splash screen to avoid one repaint of a colour is a worse trade
    // than the repaint (AND-39).
    final scheme =
        ref.watch(colourSchemeProvider).valueOrNull ?? AppScheme.fallback;
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(scheme),
      darkTheme: AppTheme.dark(scheme),
      // Night has no light half — choosing it *is* choosing dark, and the
      // appearance screen says so rather than leaving a control that does
      // nothing.
      themeMode: scheme.forcesDark ? ThemeMode.dark : mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // Wrapped around the router's output rather than around MaterialApp, so
      // the lock screen gets the app's theme and localisations, and so it
      // covers every route including ones added later. Gating screen by screen
      // would leave the answer to whoever adds the next one.
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
    );
  }
}

/// Shown when the database was written by a newer build of the app.
///
/// A whole separate app, without a [ProviderScope] holding a database, because
/// in this state there is no database to hold: opening the file read-write
/// would drop whatever the newer schema knows about. The only honest thing to
/// render is an explanation.
class UnreadableDataApp extends StatelessWidget {
  /// Creates the screen for a stored schema of [storedVersion].
  const UnreadableDataApp({
    required this.storedVersion,
    required this.supportedVersion,
    super.key,
  });

  /// Schema version found on the device.
  final int storedVersion;

  /// Newest version this build understands.
  final int supportedVersion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.system_update,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.bootstrapNewerSchemaTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.bootstrapNewerSchemaBody(
                          storedVersion,
                          supportedVersion,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
