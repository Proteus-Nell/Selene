/// Next period panel.
///
/// The single presentation of what the model believes, shared by every screen
/// that shows it. `docs/PLAN.md` 6.2 fixes the shape: the range is the
/// headline and the most likely day is a line beneath it. One widget means one
/// shape, which is the point.
///
/// Includes:
///     - NextPeriodPanel: The panel, and the switch over prediction states.
///     - _Window: A predicted range, never a bare date.
///     - _Message: A state with no window, saying something useful anyway.
///     - _Flat: The hairline block both are drawn in.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Next period panel: the one presentation the app gives its own prediction.
///
/// Shared by the insights screen and the calendar rather than written twice.
/// `docs/PLAN.md` 6.2 is specific about the shape. The range is the headline,
/// the single most likely day is a supporting line beneath it, and the
/// everyday way that rule erodes is a second screen rendering "the same thing"
/// a little more confidently. There is one widget, so there is one shape.
///
/// Attributes:
///     result (PredictionResult): What the model currently believes.
///     dense (bool): Whether to render the shortened form.
class NextPeriodPanel extends StatelessWidget {
  /// Renders [result], densely when [dense] is set.
  ///
  /// Args:
  ///     result (PredictionResult): What the model currently believes.
  ///     dense (bool, optional): Whether to render the shortened form used
  ///         beside the calendar. Defaults to false.
  const NextPeriodPanel({required this.result, this.dense = false, super.key});

  /// What the model currently believes.
  final PredictionResult result;

  /// Whether to render the shortened form used beside the calendar.
  ///
  /// Drops the confidence chip, the 50% window and the basis line. The
  /// calendar has the month itself to carry, and the insights screen is where
  /// the working is shown. What it does **not** drop is the range headline or the
  /// "four in five cycles" line beneath it, because those are the two things
  /// 6.2 requires and a "compact" variant is exactly where they would be lost.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Exhaustive by construction: PredictionResult is sealed, so a state added
    // later cannot quietly render as nothing.
    return switch (result) {
      Predicted(:final prediction) => _Window(
        dense: dense,
        prediction: prediction,
        subtitle: l10n.insightsBasedOnCycles(prediction.basis.cyclesUsed),
      ),
      InsufficientData(:final populationPrior) => _Window(
        dense: dense,
        prediction: populationPrior,
        subtitle: l10n.insightsNotPersonalisedYet,
      ),
      TooIrregular() => _Message(
        dense: dense,
        title: l10n.insightsTooIrregularTitle,
        body: l10n.insightsTooIrregularBody,
        icon: Icons.show_chart,
      ),
      LostTrack(:final daysSinceLastPeriod) => _Message(
        dense: dense,
        title: l10n.insightsLostTrackTitle,
        body: l10n.insightsLostTrackBody(daysSinceLastPeriod),
        icon: Icons.history,
      ),
      // Late enough that a moved range would be too wide to help. Says when it
      // was expected instead, which is the one thing still worth knowing.
      LaterThanExpected(:final expectedWindow80) => _Message(
        dense: dense,
        title: l10n.insightsLaterTitle,
        body: l10n.insightsLaterBody(
          expectedWindow80.start.dayAndMonth(context),
          expectedWindow80.end.dayAndMonth(context),
        ),
        icon: Icons.schedule,
      ),
      NoData() => _Message(
        dense: dense,
        title: l10n.insightsNoDataTitle,
        body: l10n.insightsNoDataBody,
        icon: Icons.edit_calendar_outlined,
      ),
      // A prediction is withheld rather than unavailable, and the difference
      // is worth the user's attention: nothing is missing and nothing has been
      // lost. The message says how to get predictions back, because a state
      // with no way out of it reads as a broken app.
      SuppressedByCondition() => _Message(
        dense: dense,
        title: l10n.insightsSuppressedPregnancyTitle,
        body: l10n.insightsSuppressedPregnancyBody,
        icon: Icons.pause_circle_outline,
      ),
      DataInconsistent(:final reason) => _Message(
        dense: dense,
        title: l10n.insightsInconsistentTitle,
        body: reason == DataInconsistency.clockWentBackwards
            ? l10n.insightsClockChanged
            : l10n.insightsInconsistentBody,
        icon: Icons.warning_amber_outlined,
        emphasis: theme.colorScheme.error,
      ),
    };
  }
}

/// A predicted window. Never a bare date: the range is the headline.
///
/// Attributes:
///     prediction (Prediction): The windows and the most likely day.
///     subtitle (String): What the prediction rests on, shown when not dense.
///     dense (bool): Whether to drop everything below the most likely day.
class _Window extends StatelessWidget {
  /// Creates the window block.
  ///
  /// Args:
  ///     prediction (Prediction): The windows and the most likely day.
  ///     subtitle (String): What the prediction rests on.
  ///     dense (bool): Whether to drop the 50% window, the confidence chip
  ///         and the subtitle. Never the range or the line under it.
  const _Window({
    required this.prediction,
    required this.subtitle,
    required this.dense,
  });

  /// The windows and the most likely day.
  final Prediction prediction;

  /// What the prediction rests on, shown only in the full form.
  final String subtitle;

  /// Whether to render the shortened form.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Flat on the page rather than in a card (AND-39). A card says the thing
    // inside it can be acted on, and this one cannot: it is the app telling
    // the reader what it believes. The hairline keeps it a block without
    // drawing a box round a paragraph.
    return _Flat(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.insightsNextPeriodTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            // The range is the largest thing on the card, and the single most
            // likely day is a supporting line beneath it. Reversing that
            // emphasis is the everyday form of overclaiming (6.2).
            Text(
              l10n.insightsWindowRange(
                prediction.window80.start.dayAndMonth(context),
                prediction.window80.end.dayAndMonth(context),
              ),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            // Past the window it was first expected in, the range has moved
            // forward and is not the four-in-five range it was. Backtested on
            // the synthetic population, a range moved past a regular user's
            // window held the period far less often than four times in five
            // (ADR-0016), so the line that says so is not shown, and neither
            // is a single most likely day or a confidence label.
            if (prediction.isLate) ...<Widget>[
              Text(l10n.insightsLateRange, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                l10n.insightsLateNotLogged,
                style: theme.textTheme.bodyMedium,
              ),
            ] else ...<Widget>[
              Text(l10n.insightsFourInFive, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                l10n.insightsMostLikely(
                  prediction.medianStart.dayAndMonth(context),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              if (!dense) ...<Widget>[
                Text(
                  l10n.insightsHalfTheTime(
                    prediction.window50.start.dayAndMonth(context),
                    prediction.window50.end.dayAndMonth(context),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Chip(
                      label: Text(
                        _confidenceLabel(l10n, prediction.confidence),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ],
            if (!dense) ...<Widget>[
              const SizedBox(height: 8),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  /// Return the label for a confidence level.
  ///
  /// Args:
  ///     l10n (AppLocalizations): The translations.
  ///     confidence (Confidence): The level to name.
  ///
  /// Returns:
  ///     String: The level's name, in the user's language.
  static String _confidenceLabel(
    AppLocalizations l10n,
    Confidence confidence,
  ) => switch (confidence) {
    Confidence.high => l10n.insightsConfidenceHigh,
    Confidence.medium => l10n.insightsConfidenceMedium,
    Confidence.low => l10n.insightsConfidenceLow,
  };
}

/// A state with no window, which still has to say something useful.
///
/// Every one of these says what is missing and what would fix it. A state the
/// user has no way out of reads as a broken app rather than as a refusal to
/// guess.
///
/// Attributes:
///     title (String): What the state is.
///     body (String): What to do about it, shown when not dense.
///     icon (IconData): The icon beside the title.
///     dense (bool): Whether to drop the body.
///     emphasis (Color?): Overrides the icon's colour.
class _Message extends StatelessWidget {
  /// Creates the message block.
  ///
  /// Args:
  ///     title (String): What the state is.
  ///     body (String): What to do about it.
  ///     icon (IconData): The icon beside the title.
  ///     dense (bool): Whether to drop the body and show the title alone.
  ///     emphasis (Color?, optional): The icon's colour. Defaults to null,
  ///         which uses the scheme's primary; the inconsistent-data state
  ///         passes the error colour instead.
  const _Message({
    required this.title,
    required this.body,
    required this.icon,
    required this.dense,
    this.emphasis,
  });

  /// What the state is.
  final String title;

  /// What to do about it, shown only in the full form.
  final String body;

  /// The icon beside the title.
  final IconData icon;

  /// Whether to render the shortened form.
  final bool dense;

  /// The icon's colour, or null for the scheme's primary.
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Flat(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                icon,
                color: emphasis ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  if (!dense) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block that is only being read: no fill, no border, one hairline above.
///
/// The panel used to be a [Card], and a card is a promise that what is inside
/// it can be acted on. Everything here is the app stating what it believes, and
/// a filled rounded box round a paragraph is one more edge the eye has to get
/// past before it reaches the sentence (AND-39).
///
/// Attributes:
///     child (Widget): What the hairline sits above.
class _Flat extends StatelessWidget {
  /// Draws a hairline above [child].
  ///
  /// Args:
  ///     child (Widget): What the hairline sits above.
  const _Flat({required this.child});

  /// What the hairline sits above.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        child,
      ],
    );
  }
}
