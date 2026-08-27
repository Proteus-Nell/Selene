import 'package:flutter/material.dart';
import 'package:period_tracker/features/common/card_entrance.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Reference notes on body composition and cycle hormones (AND-35).
///
/// The same shape as the nutrition reference, and the same rule underneath it:
/// this page explains a mechanism and never addresses the reader's own body.
/// *"Adipose tissue expresses aromatase"* is a statement about physiology.
/// *"Your body fat is raising your oestrogen"* is a claim about a person that
/// nothing in this app could establish, and on this subject it is also the
/// sentence most likely to do harm.
///
/// Three things are stricter here than anywhere else in the app, because weight
/// content in a cycle tracker is read by people for whom the subject is not
/// neutral:
///
/// - **Nothing is asked for.** No weight entry, no weight log, no BMI, no
///   schema change. There is not a single field on this screen, and
///   `weightNothingToEnterBody` says so before anything else is named.
/// - **No numbers.** `weight_copy_test.dart` fails on a digit anywhere in this
///   section's copy: a threshold, a range or a calorie figure is something to
///   measure a body against, and the safest number of them here is none.
/// - **No second person, at all.** Not "your", not "you". The test enforces it
///   as an absolute rather than as a judgement call, because the judgement call
///   is exactly what a hurried edit gets wrong.
///
/// Both directions are given evenhandedly. Too little body fat and too much
/// both reach the cycle, by different routes, and a reference that presented
/// only one of them is how this subject does damage.
///
/// Every factual claim is listed with its source in `docs/WEIGHT_SOURCES.md`,
/// and `weight_sources_test.dart` fails the build if a claim appears here
/// without one. The claims are marked `[VERIFY]` until someone has opened each
/// source and checked it — a release blocker, not a formality.
class WeightHormonesScreen extends StatelessWidget {
  /// Creates the body-composition reference screen.
  const WeightHormonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weightTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(l10n.weightIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            // Before any mechanism is named. A reader who opened this warily is
            // told in the second paragraph that there is nothing here to fill
            // in and nothing to score themselves against.
            const CardEntrance(index: 0, child: _NothingToEnter()),
            const SizedBox(height: 16),
            CardEntrance(
              index: 1,
              child: _Section(
                title: l10n.weightOestrogenTitle,
                paragraphs: <String>[
                  l10n.weightOestrogenBody,
                  l10n.weightOestrogenBalanceBody,
                ],
              ),
            ),
            CardEntrance(
              index: 2,
              child: _Section(
                title: l10n.weightEnergyTitle,
                paragraphs: <String>[
                  l10n.weightEnergyBody,
                  l10n.weightEnergyNotAScaleBody,
                ],
              ),
            ),
            CardEntrance(
              index: 3,
              child: _Section(
                title: l10n.weightInsulinTitle,
                paragraphs: <String>[l10n.weightInsulinBody],
              ),
            ),
            CardEntrance(
              index: 4,
              child: _Section(
                title: l10n.weightPcosTitle,
                paragraphs: <String>[
                  l10n.weightPcosBody,
                  l10n.weightPcosSpectrumBody,
                ],
              ),
            ),
            CardEntrance(
              index: 5,
              child: _Section(
                title: l10n.weightThyroidTitle,
                paragraphs: <String>[l10n.weightThyroidBody],
              ),
            ),
            CardEntrance(
              index: 6,
              child: _Section(
                title: l10n.weightChangeTitle,
                paragraphs: <String>[l10n.weightChangeBody],
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.weightSourcesNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The statement that this screen wants nothing from the reader.
class _NothingToEnter extends StatelessWidget {
  const _NothingToEnter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).weightNothingToEnterBody,
                style: theme.textTheme.bodyMedium,
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
