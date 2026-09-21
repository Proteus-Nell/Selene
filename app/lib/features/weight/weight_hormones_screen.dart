/// Body composition and cycle hormones reference (AND-35).
///
/// Explains the routes by which body fat reaches the cycle, in both
/// directions, and asks for nothing in return. No weight entry, no BMI, no
/// field of any kind, and no sentence addressed to the reader's own body.
///
/// Includes:
///     - WeightHormonesScreen: The reference page, and its sections in order.
///     - _Section: One heading and its paragraphs.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/features/common/card_entrance.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Weight and hormones screen: how body composition reaches the cycle.
///
/// The same shape as the nutrition reference (AND-35), and the same rule
/// underneath it: this page explains a mechanism and never addresses the
/// reader's own body. *"Adipose tissue expresses aromatase"* is a statement
/// about physiology. *"Your body fat is raising your oestrogen"* is a claim
/// about a person that nothing in this app could establish, and on this
/// subject it is also the sentence most likely to do harm.
///
/// Three things are stricter here than anywhere else in the app, because weight
/// content in a cycle tracker is read by people for whom the subject is not
/// neutral:
///
/// - **Nothing is asked for.** No weight entry, no weight log, no BMI, no
///   schema change. There is not a single field on this screen, and nothing
///   here invites the reader to produce a number about themselves.
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
/// source and checked it. That is a release blocker, not a formality.
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
            CardEntrance(
              index: 0,
              child: _Section(
                title: l10n.weightOestrogenTitle,
                paragraphs: <String>[
                  l10n.weightOestrogenBody,
                  l10n.weightOestrogenBalanceBody,
                ],
              ),
            ),
            CardEntrance(
              index: 1,
              child: _Section(
                title: l10n.weightEnergyTitle,
                paragraphs: <String>[
                  l10n.weightEnergyBody,
                  l10n.weightEnergyNotAScaleBody,
                ],
              ),
            ),
            CardEntrance(
              index: 2,
              child: _Section(
                title: l10n.weightInsulinTitle,
                paragraphs: <String>[l10n.weightInsulinBody],
              ),
            ),
            CardEntrance(
              index: 3,
              child: _Section(
                title: l10n.weightPcosTitle,
                paragraphs: <String>[
                  l10n.weightPcosBody,
                  l10n.weightPcosSpectrumBody,
                ],
              ),
            ),
            CardEntrance(
              index: 4,
              child: _Section(
                title: l10n.weightThyroidTitle,
                paragraphs: <String>[l10n.weightThyroidBody],
              ),
            ),
            CardEntrance(
              index: 5,
              child: _Section(
                title: l10n.weightChangeTitle,
                paragraphs: <String>[l10n.weightChangeBody],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One section of the reference: a heading and its paragraphs.
///
/// Attributes:
///     title (String): The heading.
///     paragraphs (`List<String>`): The body, one paragraph per entry.
class _Section extends StatelessWidget {
  /// Creates a section.
  ///
  /// Args:
  ///     title (String): The heading.
  ///     paragraphs (`List<String>`): The body, one paragraph per entry.
  const _Section({required this.title, required this.paragraphs});

  /// The heading.
  final String title;

  /// The body, rendered as one paragraph per entry.
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
