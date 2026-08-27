import 'package:flutter/material.dart';
import 'package:period_tracker/features/common/card_entrance.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Reference notes on pain and movement across the cycle (AND-36).
///
/// The same shape as the body-composition reference, and the same rule
/// underneath it: this page describes a subject and never addresses the
/// reader's own body. What is different here is what the page had to refuse to
/// say.
///
/// **This section was asked for as "avoid exercising during menstruation".** It
/// does not say that, and no edit should put it back. A blanket instruction to
/// avoid exercise during a period is not supported by anything in
/// `docs/MOVEMENT_SOURCES.md`; the evidence runs the other way, and exercise is
/// among the better-evidenced things for menstrual cramps. Writing the
/// requested version would have told people to stop doing a thing that helps
/// them, on the authority of an app that cannot see them.
///
/// What actually varies across a cycle is **how movement feels** — pain,
/// tiredness, and how hard a given effort seems on the day. That is a
/// description, not a permission system, and the section is written as one.
///
/// Three things are stricter here than in most of the app:
///
/// - **Nothing is prescribed.** No sets, no repetitions, no intensities, no
///   durations, no schedule, no phase-by-phase plan. `movement_copy_test.dart`
///   fails on the vocabulary of one, and `movementNothingToFollowBody` says so
///   before any claim is named.
/// - **No numbers.** A digit here would be either a training figure or a pain
///   score, and the section is not allowed to hand out either.
/// - **No second person, at all.** Not "your period", and specifically not
///   *"listen to your body"* — the friendliest sentence in this subject area,
///   and still an instruction addressed to somebody this app cannot see.
///
/// Rest is written as a **permission rather than an instruction**, because an
/// instruction to rest is the same category error as an exercise prescription,
/// only kinder.
///
/// Every factual claim is listed with its source in `docs/MOVEMENT_SOURCES.md`,
/// and `movement_sources_test.dart` fails the build if a claim appears here
/// without one. The claims are marked `[VERIFY]` until someone has opened each
/// source and checked it — a release blocker, not a formality.
class MovementScreen extends StatelessWidget {
  /// Creates the pain-and-movement reference screen.
  const MovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.movementTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(l10n.movementIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            // Before any claim is made. Somebody who opened this expecting to
            // be handed a plan is told in the second paragraph that there is
            // no plan here, which is the honest thing to lead with when the
            // popular version of this subject is nothing but plans.
            const CardEntrance(index: 0, child: _NothingToFollow()),
            const SizedBox(height: 16),
            CardEntrance(
              index: 1,
              child: _Section(
                title: l10n.movementPainTitle,
                paragraphs: <String>[l10n.movementPainBody],
              ),
            ),
            CardEntrance(
              index: 2,
              child: _Section(
                title: l10n.movementNotAvoidedTitle,
                paragraphs: <String>[
                  l10n.movementNotAvoidedBody,
                  l10n.movementEvidenceBody,
                ],
              ),
            ),
            CardEntrance(
              index: 3,
              child: _Section(
                title: l10n.movementHowItFeelsTitle,
                paragraphs: <String>[l10n.movementHowItFeelsBody],
              ),
            ),
            CardEntrance(
              index: 4,
              child: _Section(
                title: l10n.movementRestTitle,
                paragraphs: <String>[l10n.movementRestBody],
              ),
            ),
            CardEntrance(
              index: 5,
              child: _Section(
                title: l10n.movementStopSignalsTitle,
                paragraphs: <String>[
                  l10n.movementStopSignalsBody,
                  l10n.movementAnaemiaBody,
                ],
              ),
            ),
            CardEntrance(
              index: 6,
              child: _Section(
                title: l10n.movementPhaseClaimsTitle,
                paragraphs: <String>[
                  l10n.movementPhaseClaimsBody,
                  l10n.movementContraceptionBody,
                ],
              ),
            ),
            CardEntrance(
              index: 7,
              child: _Section(
                title: l10n.movementSeeSomeoneTitle,
                paragraphs: <String>[l10n.movementSeeSomeoneBody],
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.movementSourcesNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The statement that this screen is not a plan and wants nothing entered.
class _NothingToFollow extends StatelessWidget {
  const _NothingToFollow();

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
                AppLocalizations.of(context).movementNothingToFollowBody,
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
