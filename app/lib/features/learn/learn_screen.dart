import 'package:flutter/material.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';
import 'package:period_tracker/features/movement/movement_screen.dart';
import 'package:period_tracker/features/nutrition/nutrition_screen.dart';
import 'package:period_tracker/features/weight/weight_hormones_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Everything the app has written down, in one place (AND-39).
///
/// Before this the reference pages were scattered: hygiene, nutrition and
/// conditions behind Settings, body composition and movement behind Insights.
/// None of those are settings and none of them are insights — they are reading,
/// and a user looking for what the app says about iron had to guess which of
/// two unrelated screens somebody had filed it under.
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

class _LearnTile extends StatelessWidget {
  const _LearnTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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

class _Heading extends StatelessWidget {
  const _Heading(this.label);

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
