import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/scheduler.dart';

/// Builds the notification wording from the current localisations.
///
/// The window body names the predicted range rather than a single date, for the
/// same reason the UI does: a bare date on a lock screen claims a precision the
/// model does not have (`docs/PLAN.md` 6.2).
NotificationCopy buildNotificationCopy(
  BuildContext context,
  PredictionResult result,
) {
  final l10n = AppLocalizations.of(context);
  final window = switch (result) {
    Predicted(:final prediction) => prediction.window80,
    InsufficientData(:final populationPrior) => populationPrior.window80,
    TooIrregular() || LostTrack() || NoData() || DataInconsistent() => null,
  };
  return NotificationCopy(
    channelPredictionsName: l10n.notificationChannelPredictions,
    channelPredictionsDescription:
        l10n.notificationChannelPredictionsDescription,
    channelRemindersName: l10n.notificationChannelReminders,
    channelRemindersDescription: l10n.notificationChannelRemindersDescription,
    genericTitle: l10n.notificationGenericTitle,
    genericBody: l10n.notificationGenericBody,
    windowOpeningTitle: l10n.notificationWindowOpeningTitle,
    windowOpeningBody: window == null
        ? l10n.notificationGenericBody
        : l10n.notificationWindowOpeningBody(
            window.start.dayAndMonth(context),
            window.end.dayAndMonth(context),
          ),
    likelyStartedTitle: l10n.notificationLikelyStartedTitle,
    likelyStartedBody: l10n.notificationLikelyStartedBody,
    nudgeTitle: l10n.notificationNudgeTitle,
    nudgeBody: l10n.notificationNudgeBody,
    lateNoticeTitle: l10n.notificationLateNoticeTitle,
    lateNoticeBody: l10n.notificationLateNoticeBody,
    logAction: l10n.notificationLogAction,
  );
}

/// Keeps the platform's schedule in step with the prediction.
///
/// Wraps the app's main frame rather than living in a screen, because the
/// requirement is "reschedule on every prediction change and every edit", and a
/// screen only reschedules while it is on top. Anything that changes a day log
/// changes the prediction, and this watches the prediction.
class NotificationSync extends ConsumerStatefulWidget {
  /// Wraps [child].
  const NotificationSync({required this.child, super.key});

  /// The subtree this sits in front of.
  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  bool _prepared = false;
  bool _missedReminder = false;

  Future<void> _sync(PredictionResult result) async {
    final scheduler = ref.read(notificationSchedulerProvider);
    if (!mounted) return;
    final copy = buildNotificationCopy(context, result);

    if (!_prepared) {
      _prepared = true;
      await scheduler.prepare(copy);
    }

    final planned = await scheduler.reschedule(result, copy: copy);
    final missed = await scheduler.checkForMissedReminder(planned);
    if (mounted && missed != _missedReminder) {
      setState(() => _missedReminder = missed);
    }
    if (mounted) await _offerPermission(scheduler);
  }

  /// Asks for permission once, in context, after a cycle has been logged.
  Future<void> _offerPermission(NotificationScheduler scheduler) async {
    final settings = ref.read(appDatabaseProvider).settingsDao;
    final asked = await settings.readBool(
      SettingKey.notificationPermissionAsked,
      orElse: false,
    );
    if (asked || !await scheduler.shouldRequestPermission()) return;
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final wanted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsNotificationPermissionTitle),
        content: Text(l10n.settingsNotificationPermissionBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsNotificationPermissionAllow),
          ),
        ],
      ),
    );
    // Recorded either way. Asking again after a decline is how an app trains
    // someone to decline reflexively, and Android 13+ makes the second request
    // close to unanswerable anyway.
    await settings.writeBool(
      SettingKey.notificationPermissionAsked,
      value: true,
    );
    if (wanted ?? false) await scheduler.requestPermissionIfEarned();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PredictionResult>>(predictionProvider, (
      previous,
      next,
    ) {
      final result = next.valueOrNull;
      if (result != null) unawaited(_sync(result));
    });

    if (!_missedReminder) return widget.child;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        // The fallback for a reminder that never arrived: several manufacturers
        // silently kill scheduled alarms to save battery (risk R12), so the app
        // says so in place rather than pretending it reminded them.
        MaterialBanner(
          content: Text(l10n.logMissedReminder),
          actions: <Widget>[
            TextButton(
              onPressed: () => setState(() => _missedReminder = false),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
