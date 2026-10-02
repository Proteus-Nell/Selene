/// Learn screen.
///
/// Collects every reference page the app ships into one list, under headings
/// that separate the pages that explain from the one row that records
/// something. Built for AND-39, which took these pages out of Settings and
/// Insights, where neither of them belonged.
///
/// Includes:
///     - LearnScreen: The list itself.
///     - _LearnTile: One row, and the screen it pushes.
///     - _Heading: A section label above a group of rows.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';
import 'package:period_tracker/features/movement/movement_screen.dart';
import 'package:period_tracker/features/nutrition/nutrition_screen.dart';
import 'package:period_tracker/features/weight/weight_hormones_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Learn screen: everything the app has written down, in one place (AND-39).
///
/// Before this the reference pages were scattered: hygiene, nutrition and
/// conditions behind Settings, body composition and movement behind Insights.
/// None of those are settings and none of them are insights. They are reading,
/// and a user looking for what the app says about iron had to guess which of
/// two unrelated screens somebody had filed it under.
///
/// This tab is now the only way to them, at the owner's direction: they are
/// not listed in Settings, and Insights offers its two only while the tab is
/// switched on. Turning the tab off hides the pages, not just a route to them.
///
/// The subtitles are not decoration. Each one says what the page argues before
/// anyone taps it, which matters most for the two that answer a popular
/// question with "less than you would hope": somebody arriving at the movement
/// page hoping to be told which days to train on should be able to see that
/// they will not be.
class LearnScreen extends StatelessWidget {
  /// Creates the learn screen.
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learnTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                l10n.learnIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            _Heading(l10n.learnReferenceSection),
            _LearnTile(
              icon: Icons.search,
              title: l10n.settingsLookup,
              subtitle: l10n.settingsLookupSubtitle,
              destination: () => const LookupScreen(),
            ),
            _LearnTile(
              icon: Icons.eco_outlined,
              title: l10n.settingsNutrition,
              subtitle: l10n.settingsNutritionSubtitle,
              destination: () => const NutritionScreen(),
            ),
            _LearnTile(
              icon: Icons.directions_walk,
              title: l10n.movementEntryTitle,
              subtitle: l10n.movementEntrySubtitle,
              destination: () => const MovementScreen(),
            ),
            _LearnTile(
              icon: Icons.monitor_weight_outlined,
              title: l10n.weightEntryTitle,
              subtitle: l10n.weightEntrySubtitle,
              destination: () => const WeightHormonesScreen(),
            ),
            _Heading(l10n.learnYourRecordSection),
            // Conditions is the one row here that writes something. It sits
            // under its own heading rather than among the reading, because a
            // list where four rows explain and the fifth records is a list
            // somebody will tap the fifth of by mistake.
            _LearnTile(
              icon: Icons.medical_information_outlined,
              title: l10n.settingsConditions,
              subtitle: l10n.settingsConditionsSubtitle,
              destination: () => const ConditionsScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the list: an icon, a label, what the page argues, and where it
/// goes.
///
/// The destination is a builder rather than a widget so the screen behind the
/// row is constructed when somebody taps it, not when the list is laid out.
/// Seven screens built eagerly to render seven rows would be seven screens'
/// worth of work for the one a user wanted.
///
/// Attributes:
///     icon (IconData): The leading icon.
///     title (String): The row's label.
///     subtitle (String): What the page it opens argues.
///     destination (`Widget Function()`): Builds the screen to push.
class _LearnTile extends StatelessWidget {
  /// Creates a row that pushes what [destination] builds.
  ///
  /// Args:
  ///     icon (IconData): The leading icon.
  ///     title (String): The row's label.
  ///     subtitle (String): What the page it opens argues.
  ///     destination (`Widget Function()`): Builds the screen to push.
  const _LearnTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  /// The leading icon.
  final IconData icon;

  /// The row's label.
  final String title;

  /// What the page it opens argues, said before anyone taps it.
  final String subtitle;

  /// Builds the screen this row pushes, at the moment it is pushed.
  final Widget Function() destination;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => destination()),
    ),
  );
}

/// A section label above a group of rows.
///
/// Attributes:
///     label (String): The text, upper-cased for display.
class _Heading extends StatelessWidget {
  /// Creates a section label.
  ///
  /// Args:
  ///     label (String): The text. Upper-cased for display, so it is written
  ///         in the ARB in ordinary sentence case.
  const _Heading(this.label);

  /// The text of the label. Upper-cased for display.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
