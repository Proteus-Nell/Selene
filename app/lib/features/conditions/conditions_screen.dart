/// Conditions screen.
///
/// Records long-term conditions and medication over the spans of days they
/// applied to, and says plainly that none of it reaches the prediction
/// (ADR-0010). What it does give back is the number of cycles each one
/// overlapped, which is context for reading the user's own figures.
///
/// Below them, the medicines the user takes, picked from the bundled US list,
/// with the times each is to be reminded of (ADR-0025), and a flag for each
/// pair whose labels connect them (ADR-0015), and for each medicine whose
/// label connects it with a recorded kind of contraception (ADR-0021). A flag
/// only informs, and offers the pair to a browser.
///
/// Includes:
///     - ConditionsScreen: The list, and the flow that adds to it.
///     - _ConditionTile: One record, its dates, and what it overlapped.
///     - _Medicines: The recorded medicines, and the flow that adds to them.
///     - _MedicineReminders: The times one medicine is to be reminded of.
///     - _Conflicts: A card for every pair of recorded medicines, and every
///       recorded kind of contraception with each medicine.
///     - _PairCard: One pair, flagged or not.
///     - _ConditionPairCard: One kind of contraception and one medicine.
///     - _spaced: The gap under a card in a list of them.
///     - conditionLabel: The user-facing name of a condition.
///     - _pickDate: The date picker both flows use.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/cycles/condition_overlap.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';
import 'package:period_tracker/features/lookup/medicine_picker.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/notifications/scheduler.dart';

/// Conditions screen: what was recorded, and over which days.
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
/// rather than changing it: a refusal to claim, not a different claim.
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
                _spaced(
                  _ConditionTile(
                    record: record,
                    cyclesOverlapped: overlaps
                        .where((o) => o.condition == record.condition)
                        .map((o) => o.cycles)
                        .firstOrNull,
                  ),
                ),
            const SizedBox(height: 24),
            const _Medicines(),
          ],
        ),
      ),
    );
  }

  /// Record a new condition, in two steps.
  ///
  /// Steps:
  ///     1. Offer the closed list of conditions in a sheet.
  ///     2. Ask when it started, no later than today.
  ///     3. Write it, and confirm by name.
  ///
  /// Either step can be abandoned and nothing is written. The `mounted` check
  /// after each await is what stops a write landing on a screen the user has
  /// already left.
  ///
  /// Args:
  ///     context (BuildContext): What to show the sheet and picker over.
  ///     ref (WidgetRef): For the clock and the condition repository.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the record is written, or as soon as
  ///     the user backs out of either step.
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<Condition>(
      context: context,
      isScrollControlled: true,
      // Both of these, and neither is optional here. `isScrollControlled` lets
      // the sheet grow to fit fourteen conditions, which means it reaches the
      // top of the screen, and there the title lands under the status bar and
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
///
/// Attributes:
///     record (ConditionRecord): The condition and its span.
///     cyclesOverlapped (int?): How many cycles fell inside that span.
class _ConditionTile extends ConsumerWidget {
  /// Creates a tile for one record.
  ///
  /// Args:
  ///     record (ConditionRecord): The condition and its span. An open span
  ///         is shown as ongoing and offers an end date rather than a reopen.
  ///     cyclesOverlapped (int?): How many cycles fell inside that span, or
  ///         null when the overlaps have not been read yet. Zero and null
  ///         both render nothing, because "overlapped no cycles" is not a
  ///         finding worth a line.
  const _ConditionTile({required this.record, required this.cyclesOverlapped});

  /// The condition and its span.
  final ConditionRecord record;

  /// How many cycles fell inside that span.
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

  /// Close an open record, at a date the user picks.
  ///
  /// Args:
  ///     context (BuildContext): What to show the picker over.
  ///     ref (WidgetRef): For the clock and the condition repository.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the record is closed, or at once if
  ///     the user dismissed the picker.
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

/// The medicines the user takes, and a way to add more.
///
/// Picked from the bundled US list rather than typed, because a typed name
/// cannot be compared with anything. Stored as a setting, so they travel in
/// exports and go with "delete everything" (ADR-0015). Like the conditions
/// above them, none of it reaches the prediction.
class _Medicines extends ConsumerWidget {
  /// Creates the section.
  const _Medicines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final recorded =
        ref.watch(recordedMedicinesProvider).valueOrNull ??
        const <RecordedMedicine>[];
    final reminders =
        ref.watch(medicineRemindersProvider).valueOrNull ??
        const <String, List<ReminderTime>>{};
    // The index says how each medicine is taken, and which ones a refresh of
    // the bundle dropped. Loaded only once there is something to say it of.
    final index = medicinesFetched && recorded.isNotEmpty
        ? ref.watch(medicineIndexProvider).valueOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.conditionsMedicinesHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.conditionsMedicinesIntro, style: body),
        const SizedBox(height: 8),
        if (!medicinesFetched)
          Text(l10n.conditionsMedicinesUnavailable, style: body)
        else ...<Widget>[
          if (recorded.isEmpty)
            Text(l10n.conditionsMedicinesEmpty, style: body),
          for (final medicine in recorded)
            _spaced(
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ListTile(
                      title: Text(medicine.name),
                      subtitle: switch (index) {
                        null => null,
                        final index => Text(switch (index.byKey(
                          medicine.key,
                        )) {
                          final entry? => medicineKind(l10n, entry),
                          null => l10n.conditionsMedicineGone,
                        }),
                      },
                      trailing: IconButton(
                        // Its reminders go with it.
                        onPressed: () => ref
                            .read(medicineListRepositoryProvider)
                            .remove(medicine.key),
                        icon: const Icon(Icons.close),
                        tooltip: l10n.checkerRemove(medicine.name),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _MedicineReminders(
                        medicine: medicine,
                        times:
                            reminders[medicine.key] ?? const <ReminderTime>[],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.checkerAdd),
          ),
          // A pair of medicines, or a recorded kind of contraception and a
          // medicine to compare it with (ADR-0021).
          if (recorded.length >= 2 ||
              (recorded.isNotEmpty &&
                  ref
                      .watch(recordedContraceptionProvider)
                      .isNotEmpty)) ...<Widget>[
            const SizedBox(height: 24),
            const _Conflicts(),
          ],
        ],
      ],
    );
  }

  /// Pick a medicine and record it, and say which.
  ///
  /// Args:
  ///     context (BuildContext): What to open the picker over.
  ///     ref (WidgetRef): For the medicine list.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once it is recorded, or at once if the
  ///     user went back without picking one.
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await pickMedicine(context);
    if (picked == null || !context.mounted) return;
    final added = await ref.read(medicineListRepositoryProvider).add(picked);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      added
          ? picked.name
          : AppLocalizations.of(context).checkerAlreadyAdded(picked.name),
    );
  }
}

/// The times one medicine is to be reminded of, and a way to add one.
///
/// Each time is a chip: tapped, it can be changed, and its cross takes it
/// off. Each goes off every day, up to [MedicineListRepository.maxReminders]
/// of them. Nothing here touches the platform's schedule: `NotificationSync`
/// watches the times and reschedules when they change (ADR-0025).
///
/// Attributes:
///     medicine (RecordedMedicine): The medicine they are for.
///     times (`List<ReminderTime>`): Its times, earliest first.
class _MedicineReminders extends ConsumerWidget {
  /// Creates the row.
  const _MedicineReminders({required this.medicine, required this.times});

  /// The medicine they are for.
  final RecordedMedicine medicine;

  /// Its times, earliest first.
  final List<ReminderTime> times;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = reminderTimeFormatter(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final time in times)
          InputChip(
            avatar: const Icon(Icons.alarm, size: 18),
            label: Text(format(time)),
            tooltip: l10n.conditionsMedicineReminderChange(format(time)),
            onPressed: () => _pick(context, ref, replacing: time),
            onDeleted: () => _save(ref, <ReminderTime>[
              for (final each in times)
                if (each != time) each,
            ]),
            deleteButtonTooltipMessage: l10n.conditionsMedicineReminderRemove(
              format(time),
            ),
          ),
        if (times.length < MedicineListRepository.maxReminders)
          ActionChip(
            avatar: const Icon(Icons.alarm_add, size: 18),
            label: Text(l10n.conditionsMedicineReminderAdd),
            onPressed: () => _pick(context, ref),
          ),
      ],
    );
  }

  /// Ask for a time, keep it, and say whether it can arrive.
  ///
  /// Setting a reminder is the moment a notification has been asked for, so
  /// it is when the permission is asked for too, if it has not been granted.
  /// Kept either way: once notifications are allowed, it arrives.
  ///
  /// Steps:
  ///     1. Ask for the time, and keep it.
  ///     2. Ask for the notification permission, if it has not been asked.
  ///     3. Ask about exact alarms, if they are not allowed (ADR-0026), which
  ///        is what decides whether this reminder lands on its minute.
  ///     4. Say what will actually happen, which is not the same sentence in
  ///        all three cases.
  ///
  /// Args:
  ///     context (BuildContext): What to open the picker over.
  ///     ref (WidgetRef): For the medicines and the scheduler.
  ///     replacing (ReminderTime?, optional): The time being changed, or
  ///         null for a new one. Defaults to null.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once it is kept and said, or at once if
  ///     the user went back without choosing.
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    ReminderTime? replacing,
  }) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: replacing == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: replacing.hour, minute: replacing.minute),
      helpText: l10n.conditionsMedicineReminderHelp,
    );
    if (picked == null || !context.mounted) return;
    final time = ReminderTime(picked.hour, picked.minute);
    await _save(ref, <ReminderTime>[
      for (final each in times)
        if (each != replacing) each,
      time,
    ]);
    if (!context.mounted) return;
    final scheduler = ref.read(notificationSchedulerProvider);
    final granted = await scheduler.requestPermissionForReminder();
    if (!context.mounted) return;
    if (!granted) {
      // Nothing can arrive at all, so the minute it would have arrived on is
      // not the thing to talk about.
      showAppSnackBar(context, l10n.conditionsMedicineReminderBlocked);
      return;
    }

    final onTime = await _offerExactReminders(context, ref, scheduler);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      onTime
          ? l10n.conditionsMedicineReminderSet(
              reminderTimeFormatter(context)(time),
            )
          : l10n.conditionsMedicineReminderSetLate(
              reminderTimeFormatter(context)(time),
            ),
    );
  }

  /// Ask for the exact-alarm permission, where it is worth asking.
  ///
  /// The moment it is in context: a user who has just named a time has said
  /// the time matters. Asked once (ADR-0026) — the row in Settings is where
  /// it lives afterwards — and not at all on a phone that already allows it,
  /// which includes every phone before Android 12.
  ///
  /// Granting it reschedules, because the reminder saved a moment ago was
  /// queued with the platform inexactly and nothing re-queues it by itself.
  ///
  /// Args:
  ///     context (BuildContext): What to open the dialog over.
  ///     ref (WidgetRef): For the reschedule.
  ///     scheduler (NotificationScheduler): Asked, and asked with.
  ///
  /// Returns:
  ///     `Future<bool>`: Whether reminders will now arrive on their minute.
  Future<bool> _offerExactReminders(
    BuildContext context,
    WidgetRef ref,
    NotificationScheduler scheduler,
  ) async {
    if (!await scheduler.shouldRequestExactReminders()) {
      return scheduler.exactRemindersAllowed();
    }
    if (!context.mounted) return false;

    final l10n = AppLocalizations.of(context);
    final wanted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsExactRemindersTitle),
        content: Text(l10n.settingsExactRemindersBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsExactRemindersAllow),
          ),
        ],
      ),
    );
    if (!(wanted ?? false)) {
      // Recorded without asking the platform, so the question does not come
      // back by itself. Settings still offers it.
      await scheduler.recordExactRemindersAsked();
      return false;
    }

    final allowed = await scheduler.requestExactReminders();
    if (allowed) {
      // What was queued a moment ago was queued roughly, and Android
      // re-queues nothing by itself.
      ref.read(notificationPreferencesRevisionProvider.notifier).state++;
    }
    return allowed;
  }

  /// Keep [next] as this medicine's times.
  Future<void> _save(WidgetRef ref, List<ReminderTime> next) =>
      ref.read(medicineListRepositoryProvider).setReminders(medicine.key, next);
}

/// A card for every pair of recorded medicines, and for every recorded kind
/// of contraception with every medicine: those the labels connect first,
/// flagged, then the rest.
///
/// Every pair can be looked up online, at the owner's direction, whether or
/// not the labels connect it. A pair with nothing found here is not thereby
/// cleared: the labels leave interactions out, and name many medicines by a
/// group this app does not know.
class _Conflicts extends ConsumerWidget {
  /// Creates the section.
  const _Conflicts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final medicines = ref.watch(recordedInteractionsProvider);
    final conditions = ref.watch(recordedConditionPairsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.conditionsConflictsHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        ...switch ((medicines, conditions)) {
          (AsyncError(), _) || (_, AsyncError()) => <Widget>[
            Text(l10n.checkerFailed, style: body),
          ],
          (
            AsyncData(value: final pairs),
            AsyncData(value: final kinds),
          ) =>
            _cards(l10n, body, pairs, kinds),
          _ => <Widget>[
            LinearProgressIndicator(semanticsLabel: l10n.checkerLoading),
          ],
        },
      ],
    );
  }

  /// The cards: the flagged ones first, medicine pairs before kinds, then
  /// the rest in the same order.
  List<Widget> _cards(
    AppLocalizations l10n,
    TextStyle? body,
    List<InteractionPair> pairs,
    List<ConditionPair> kinds,
  ) {
    final cards = <(bool, Widget)>[
      for (final pair in pairs) (pair.connected, _PairCard(pair: pair)),
      for (final pair in kinds)
        (pair.connected, _ConditionPairCard(pair: pair)),
    ];
    final flagged = cards.any((card) => card.$1);
    final unflagged = cards.any((card) => !card.$1);
    return <Widget>[
      if (flagged) ...<Widget>[
        Text(l10n.conditionsConflictsIntro, style: body),
        const SizedBox(height: 12),
      ],
      for (final (connected, card) in cards)
        if (connected) _spaced(card, gap: 12),
      for (final (connected, card) in cards)
        if (!connected) _spaced(card, gap: 12),
      if (unflagged) Text(l10n.checkerNothingFoundNote, style: body),
    ];
  }
}

/// One pair of recorded medicines, and where to read more about it.
///
/// A pair the labels connect is flagged, with what connects it, and opens
/// the checker, where each mention is quoted in full. Any other pair says the
/// labels do not connect it, and that the result is worth verifying. Either
/// way it can be searched for in the browser, after the usual confirmation.
///
/// It informs and nothing else, at the owner's direction. It never says to
/// stop or change anything, and `interaction_copy_test.dart` holds it to that.
///
/// Attributes:
///     pair (InteractionPair): The pair.
class _PairCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Args:
  ///     pair (InteractionPair): The pair.
  const _PairCard({required this.pair});

  /// The pair.
  final InteractionPair pair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (pair.connected) ...<Widget>[
                  Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    l10n.checkerPairTitle(pair.first.name, pair.second.name),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!pair.connected)
              Text(
                l10n.checkerNothingFoundPair,
                style: theme.textTheme.bodyMedium,
              ),
            for (final reason in interactionReasons(l10n, pair))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(reason, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => searchPairOnline(context, pair),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.conditionsConflictLookUp),
                ),
                if (pair.connected)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => InteractionCheckerScreen(
                          initial: <MedicineEntry>[pair.first, pair.second],
                        ),
                      ),
                    ),
                    child: Text(l10n.conditionsConflictLabels),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A recorded kind of contraception and a recorded medicine, and where to
/// read more about them.
///
/// As [_PairCard], with the kind compared as what every product of it shares
/// (ADR-0021), and the medicine's label the only one to read: the kind has
/// none of its own. It informs and nothing else.
///
/// Attributes:
///     pair (ConditionPair): The kind and the medicine.
class _ConditionPairCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Args:
  ///     pair (ConditionPair): The kind and the medicine.
  const _ConditionPairCard({required this.pair});

  /// The kind and the medicine.
  final ConditionPair pair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = conditionLabel(l10n, pair.condition.condition);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (pair.connected) ...<Widget>[
                  Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    l10n.checkerPairTitle(label, pair.medicine.name),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!pair.connected)
              Text(
                l10n.checkerNothingFoundPair,
                style: theme.textTheme.bodyMedium,
              ),
            for (final reason in conditionReasons(l10n, pair))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(reason, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () =>
                      searchConditionOnline(context, pair, label: label),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.conditionsConflictLookUp),
                ),
                if (pair.connected)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            ConditionPairScreen(pair: pair, label: label),
                      ),
                    ),
                    child: Text(l10n.conditionsConflictLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [card], with a gap under it.
///
/// The theme gives cards no margin, so that a card can sit flush where a
/// layout wants it to. In a list, cards with no gap between them read as one
/// block.
///
/// Args:
///     card (Widget): The card.
///     gap (double): The space under it. Defaults to 8.
Widget _spaced(Widget card, {double gap = 8}) => Padding(
  padding: EdgeInsets.only(bottom: gap),
  child: card,
);

/// Return the user-facing name of a condition.
///
/// Clinical names, deliberately. Softening "PCOS" into something vaguer would
/// leave the user unable to look it up anywhere else, which is its own kind of
/// unhelpful.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     condition (Condition): The condition to name.
///
/// Returns:
///     String: Its name, in the user's language. Exhaustive over the enum, so
///     a condition added later fails to compile until it is given a name.
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

/// Ask the user for a date.
///
/// Args:
///     context (BuildContext): What to show the picker over.
///     initial (CivilDate): The day the picker opens on.
///     last (CivilDate): The latest selectable day. Always today or earlier:
///         nothing in this app accepts a future date.
///     first (CivilDate?, optional): The earliest selectable day. Defaults to
///         null, which allows ten years back.
///
/// Returns:
///     `Future<CivilDate?>`: The chosen day, or null if the picker was
///     dismissed. Null means "no change", never "today".
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
