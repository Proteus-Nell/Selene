import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/nutrition_hint.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/card_entrance.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Reference notes on iron and magnesium (AND-27).
///
/// The whole feature turns on one distinction, and every piece of copy here was
/// written against it. *"Heavy menstrual bleeding is a recognised cause of iron
/// deficiency anaemia"* is a statement about physiology. *"You are low in
/// iron"* is a diagnosis of a person, from data that cannot support one. This
/// screen contains only the first kind, and `nutrition_copy_test.dart` fails
/// the build on the vocabulary of the second: "you have", "you are deficient",
/// "diagnos-", "you should take".
///
/// Every factual claim on this page is listed with its source in
/// `docs/NUTRITION_SOURCES.md`, and `nutrition_sources_test.dart` fails the
/// build if a claim appears here without one. An uncited health claim in a
/// health app is exactly what that test exists to make impossible.
///
/// The claims are marked `[VERIFY]` in the sources file until someone has
/// opened each source and checked it — the same convention `PLAN.md` uses for
/// the priors figures. That is a release blocker, not a formality.
class NutritionScreen extends ConsumerWidget {
  /// Creates the nutrition reference screen.
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final logs = ref.watch(dayLogsProvider).valueOrNull ?? const <DayLog>[];
    final today = ref.watch(clockProvider).today();
    final showHint = NutritionHints.fatigueWithHeavyFlow(logs, today);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nutritionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(l10n.nutritionIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            // Above the reference text when it applies, because a reader who
            // came here because of the hint should not have to scroll past
            // three nutrients to find it. It is one card and it appears at most
            // once — see NutritionHints for why the threshold is three days.
            if (showHint) ...<Widget>[
              const CardEntrance(index: 0, child: _Hint()),
              const SizedBox(height: 16),
            ],
            CardEntrance(
              index: showHint ? 1 : 0,
              child: _Section(
                title: l10n.nutritionIronTitle,
                paragraphs: <String>[
                  l10n.nutritionIronBody,
                  l10n.nutritionIronDiagnosisNote,
                  l10n.nutritionIronSourcesBody,
                  l10n.nutritionIronCautionBody,
                ],
              ),
            ),
            CardEntrance(
              index: showHint ? 2 : 1,
              child: _Section(
                title: l10n.nutritionVitaminCTitle,
                paragraphs: <String>[l10n.nutritionVitaminCBody],
              ),
            ),
            CardEntrance(
              index: showHint ? 3 : 2,
              child: _Section(
                title: l10n.nutritionMagnesiumTitle,
                paragraphs: <String>[
                  l10n.nutritionMagnesiumBody,
                  l10n.nutritionMagnesiumEvidenceBody,
                  l10n.nutritionMagnesiumCreamBody,
                ],
              ),
            ),
            CardEntrance(
              index: showHint ? 4 : 3,
              child: _Section(
                title: l10n.nutritionZincTitle,
                paragraphs: <String>[l10n.nutritionZincBody],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.nutritionSourcesNote,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one thing the app says about a pattern the user logged.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.nutritionHintTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  // Pinned verbatim by nutrition_copy_test.dart. It observes
                  // two things the user logged and points at a human; it names
                  // no nutrient, no deficiency and no supplement, and it does
                  // not say what the pattern means, because it cannot know.
                  Text(
                    l10n.nutritionHintBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final paragraph in paragraphs) ...<Widget>[
            Text(paragraph, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
