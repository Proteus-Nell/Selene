import 'package:flutter/material.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/domain/cycles/cycle_phase.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Where the user is in their cycle, in one line (AND-25, ADR-0007).
///
/// Two claims of very different weight sit next to each other here, and keeping
/// them distinguishable is the point of the widget.
///
/// The **day of the cycle** and the **phase name** restate dates the user
/// logged. "Day 14, follicular" is arithmetic and a label for it; ADR-0007
/// amended assumption A5 to permit exactly that, because a user who cannot see
/// where they are in their own cycle has to go and find it out somewhere less
/// careful.
///
/// The **ovulation estimate** is an inference, and it is the one `docs/PLAN.md`
/// 6.2 gates. It appears only when the user has switched it on, it is always a
/// range, and the sentence saying what it is not travels with it on the screen
/// rather than behind a link. The strip never names ovulation otherwise, never
/// calls a day safe, and never uses the word fertile — `copy_test.dart` fails
/// the build on all three rather than trusting review to catch them.
class PhaseStrip extends StatelessWidget {
  /// Shows [position], as far as it is willing to say anything.
  const PhaseStrip({required this.position, super.key});

  /// Where the user is, per [CyclePhases.on].
  final CyclePosition position;

  @override
  Widget build(BuildContext context) {
    // Keyed on the phase and nothing else (AND-34). The day number changes
    // every night and the strip must not cross-fade for that: an animation
    // that fires on a rebuild teaches the reader to ignore it, and this is the
    // one place in the app where a change of state is worth pointing at.
    // `AnimatedSwitcher` compares keys, so an identical key is a plain swap.
    return AnimatedSwitcher(
      duration: Motion.standard(context),
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      // Full width, so the strip keeps the left edge it has as a direct child
      // of the calendar's list. Without it the switcher's Stack loosens the
      // constraints and the whole strip shrink-wraps and centres.
      child: SizedBox(
        key: ValueKey<CyclePhase?>(position.phase),
        width: double.infinity,
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = position.dayOfCycle;

    if (day == null) {
      // Nothing logged, or the trail has gone cold. Said plainly rather than
      // rendered as an empty strip, which reads as a bug.
      return Text(
        l10n.calendarPhaseUnknown,
        style: theme.textTheme.bodySmall,
      );
    }

    final phase = position.phase;
    final estimate = position.ovulationEstimate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Wrap rather than Row: at 200% text scale "Day 24 of your cycle" and a
        // phase chip do not fit side by side on a phone, and a Row would clip
        // rather than reflow.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.calendarPhaseDay(day),
              style: theme.textTheme.titleSmall,
            ),
            if (phase != null)
              ActionChip(
                // Tapping explains it. The explanation is one plain sentence,
                // and it is reachable rather than assumed: "luteal" is a word
                // most people have not been given a definition for.
                onPressed: () => _explain(context, phase),
                avatar: const Icon(Icons.info_outline, size: 18),
                label: Text(_phaseLabel(l10n, phase)),
                // No compact density here, unlike the chips elsewhere in the
                // app. Compact renders this at 40dp tall, four short of the
                // 48dp minimum tap target, and a11y_test.dart failed on it —
                // the chips it is modelled on are not tap targets in the same
                // way, and copying their density copied the wrong property.
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        if (estimate != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.calendarOvulationTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.calendarOvulationRange(
              estimate.start.dayAndMonth(context),
              estimate.end.dayAndMonth(context),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          // On the screen, under the number it qualifies. A caveat behind a
          // link is a caveat nobody reads, and this is the one claim on this
          // screen that carries safety weight.
          Text(
            l10n.calendarOvulationCaveat,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _explain(BuildContext context, CyclePhase phase) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_phaseLabel(l10n, phase)),
        content: Text(_phaseExplanation(l10n, phase)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  static String _phaseLabel(AppLocalizations l10n, CyclePhase phase) =>
      switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriod,
        CyclePhase.follicular => l10n.calendarPhaseFollicular,
        CyclePhase.luteal => l10n.calendarPhaseLuteal,
      };

  static String _phaseExplanation(AppLocalizations l10n, CyclePhase phase) =>
      switch (phase) {
        CyclePhase.period => l10n.calendarPhasePeriodExplained,
        CyclePhase.follicular => l10n.calendarPhaseFollicularExplained,
        CyclePhase.luteal => l10n.calendarPhaseLutealExplained,
      };
}
