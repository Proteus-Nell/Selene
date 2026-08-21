import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/condition_overlap.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Long-term conditions and medication, with the dates they applied over.
///
/// The screen exists because the prediction model structurally cannot know any
/// of this (`docs/PLAN.md` 1081): hormonal contraception, pregnancy, PCOS,
/// thyroid disease and the rest each break the "cycles are a noisy
/// stationary-ish process" assumption the filter is built on, and the filter
/// has no way to see them.
///
/// **Recording them does not change the prediction**, and the subtitle says so
/// in the first sentence rather than burying it. The shipped priors were fitted
/// with no condition strata, so behaving differently for PCOS would be
/// inventing calibration and presenting it as a measurement (ADR-0010). What
/// the app can honestly do is hand the user the context to read their own
/// numbers, which is what the overlap count under each entry is for.
///
/// The single exception is an active pregnancy, which withholds the prediction
/// rather than changing it — a refusal to claim, not a different claim.
class ConditionsScreen extends ConsumerWidget {
  /// Creates the conditions screen.
  const ConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final records =
        ref.watch(conditionsProvider).valueOrNull ?? const <ConditionRecord>[];
    final overlaps =
        ref.watch(conditionOverlapsProvider).valueOrNull ??
        const <ConditionOverlap>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.conditionsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.conditionsAdd),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: <Widget>[
            Text(l10n.conditionsSubtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (records.isEmpty)
              Text(l10n.conditionsEmpty, style: theme.textTheme.bodyMedium)
            else
              for (final record in records)
                _ConditionTile(
                  record: record,
                  cyclesOverlapped: overlaps
                      .where((o) => o.condition == record.condition)
                      .map((o) => o.cycles)
                      .firstOrNull,
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<Condition>(
      context: context,
      isScrollControlled: true,
      // Both of these, and neither is optional here. `isScrollControlled` lets
      // the sheet grow to fit fourteen conditions, which means it reaches the
      // top of the screen — and there the title lands under the status bar and
      // the camera cutout, unreadable. `useSafeArea` is what keeps the route
      // itself inside the display cutout; a SafeArea *inside* the sheet does
      // not, because the route has already claimed the full height by then.
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: <Widget>[
                  // A visible way back. The sheet is dismissible by swipe and
                  // by tapping outside, but neither is discoverable, and
                  // neither is available to someone navigating with a screen
                  // reader or a switch device.
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: l10n.commonBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.conditionsAddTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final condition in Condition.values)
                    ListTile(
                      title: Text(conditionLabel(l10n, condition)),
                      onTap: () => Navigator.of(sheetContext).pop(condition),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    final today = ref.read(clockProvider).today();
    final start = await _pickDate(
      context,
      initial: today,
      // Nothing in this app accepts a future date. A condition that has not
      // started yet is a plan, not a record, and storing it would make
      // "currently active" depend on a date that has not happened.
      last: today,
    );
    if (start == null || !context.mounted) return;

    await ref
        .read(conditionRepositoryProvider)
        .add(condition: chosen, start: start);
    if (!context.mounted) return;
    showAppSnackBar(context, conditionLabel(l10n, chosen));
  }
}

/// One recorded condition, its dates, and what it overlapped.
class _ConditionTile extends ConsumerWidget {
  const _ConditionTile({required this.record, required this.cyclesOverlapped});

  final ConditionRecord record;
  final int? cyclesOverlapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final end = record.end;
    final overlapped = cyclesOverlapped;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    conditionLabel(l10n, record.condition),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (end == null)
                  Chip(
                    label: Text(l10n.conditionsOngoing),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              end == null
                  ? l10n.conditionsStarted(record.start.dayAndMonth(context))
                  : l10n.conditionsSpan(
                      record.start.dayAndMonth(context),
                      end.dayAndMonth(context),
                    ),
              style: theme.textTheme.bodyMedium,
            ),
            if (overlapped != null && overlapped > 0) ...<Widget>[
              const SizedBox(height: 4),
              // The sentence a flag could not have produced. It is context for
              // reading the user's own numbers, not an input to them.
              Text(
                l10n.conditionsOverlap(overlapped),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (end == null)
                  TextButton(
                    onPressed: () => _end(context, ref),
                    child: Text(l10n.conditionsEnd),
                  )
                else
                  TextButton(
                    onPressed: () =>
                        ref.read(conditionRepositoryProvider).reopen(record.id),
                    child: Text(l10n.conditionsReopen),
                  ),
                TextButton(
                  onPressed: () =>
                      ref.read(conditionRepositoryProvider).remove(record.id),
                  child: Text(l10n.conditionsRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final today = ref.read(clockProvider).today();
    final chosen = await _pickDate(
      context,
      initial: today,
      // Not before it started: an inverted span is always a mistake, and
      // accepting one would make every overlap count that reads it wrong.
      first: record.start,
      last: today,
    );
    if (chosen == null) return;
    await ref.read(conditionRepositoryProvider).end(id: record.id, end: chosen);
  }
}

/// The user-facing name of [condition].
///
/// Clinical names, deliberately. Softening "PCOS" into something vaguer would
/// leave the user unable to look it up anywhere else, which is its own kind of
/// unhelpful.
String conditionLabel(AppLocalizations l10n, Condition condition) =>
    switch (condition) {
      Condition.hormonalContraceptionCombined =>
        l10n.conditionHormonalContraceptionCombined,
      Condition.hormonalContraceptionProgestogen =>
        l10n.conditionHormonalContraceptionProgestogen,
      Condition.hormonalIud => l10n.conditionHormonalIud,
      Condition.contraceptiveImplant => l10n.conditionContraceptiveImplant,
      Condition.copperIud => l10n.conditionCopperIud,
      Condition.pregnancy => l10n.conditionPregnancy,
      Condition.postpartum => l10n.conditionPostpartum,
      Condition.breastfeeding => l10n.conditionBreastfeeding,
      Condition.pcos => l10n.conditionPcos,
      Condition.endometriosis => l10n.conditionEndometriosis,
      Condition.thyroidDisorder => l10n.conditionThyroidDisorder,
      Condition.perimenopause => l10n.conditionPerimenopause,
      Condition.uterineFibroids => l10n.conditionUterineFibroids,
      Condition.other => l10n.conditionOther,
    };

Future<CivilDate?> _pickDate(
  BuildContext context, {
  required CivilDate initial,
  required CivilDate last,
  CivilDate? first,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.toLocalMidnight(),
    firstDate: (first ?? initial.addDays(-3650)).toLocalMidnight(),
    lastDate: last.toLocalMidnight(),
  );
  return picked == null ? null : CivilDate.fromDateTime(picked);
}
