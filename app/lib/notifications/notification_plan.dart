import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/domain/cycles/cycle_rules.dart';
import 'package:period_tracker/domain/models/prediction.dart';

/// The two channels notifications are delivered on.
///
/// Two, not one, and this is the whole reason the enum exists. Android lets a
/// user mute a channel; if predictions and the logging nudge shared one, a user
/// annoyed by the nudge would mute the predictions along with it. Channel
/// granularity is the difference between "I turned off one thing" and "I turned
/// off the app" (`docs/PLAN.md` 2.4.3, risk R15).
enum NotificationChannelId {
  /// Everything about a predicted window. On by default.
  predictions('predictions'),

  /// The optional logging nudge. Off by default.
  reminders('reminders');

  const NotificationChannelId(this.id);

  /// The Android channel id. Stable: changing it orphans the user's settings
  /// for that channel and silently resets their choices.
  final String id;
}

/// What a scheduled notification is for.
enum NotificationKind {
  /// The predicted window is about to open.
  windowOpening(NotificationChannelId.predictions, 1001),

  /// The window is open and nothing has been logged.
  likelyStarted(NotificationChannelId.predictions, 1002),

  /// Nothing has been logged for a while and a cycle is in progress.
  loggingNudge(NotificationChannelId.reminders, 1003),

  /// The window closed a while ago with nothing logged.
  lateNotice(NotificationChannelId.predictions, 1004);

  const NotificationKind(this.channel, this.id);

  /// Which channel this kind is delivered on.
  final NotificationChannelId channel;

  /// The notification id, fixed per kind.
  ///
  /// Fixed rather than incrementing, so rescheduling replaces the previous one
  /// instead of stacking a second copy of the same reminder.
  final int id;
}

/// One notification, planned but not yet handed to the platform.
@immutable
final class PlannedNotification {
  /// Plans [kind] for [fireDate].
  const PlannedNotification({required this.kind, required this.fireDate});

  /// What it is for.
  final NotificationKind kind;

  /// The calendar day it should fire on.
  final CivilDate fireDate;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.kind == kind &&
      other.fireDate == fireDate;

  @override
  int get hashCode => Object.hash(kind, fireDate);

  @override
  String toString() => '${kind.name} on ${fireDate.toIso8601()}';
}

/// The user's notification preferences, as the planner needs them.
@immutable
final class NotificationPreferences {
  /// Creates a preference set.
  const NotificationPreferences({
    this.predictionsEnabled = true,
    this.nudgeEnabled = false,
    this.leadDays = 2,
    this.lastNudge,
  });

  /// Whether window, started and late notices are wanted. On by default.
  final bool predictionsEnabled;

  /// Whether the logging nudge is wanted. **Off** by default.
  final bool nudgeEnabled;

  /// How many days before the window opens to give notice.
  final int leadDays;

  /// When the nudge last fired, for the cap.
  final CivilDate? lastNudge;
}

/// Decides what should be scheduled, and when.
///
/// Deliberately pure: dates in, dates out, no plugin and no platform. Every
/// rule in the 2.4.3 table is checkable here without a device, which matters
/// because the alternative is discovering on a real phone that the nudge cap
/// was off by a day.
abstract final class NotificationPlanner {
  /// Days of silence before the logging nudge is considered.
  static const int nudgeAfterSilentDays = 7;

  /// Minimum days between two nudges. A hard cap, not a target.
  static const int nudgeCapDays = 7;

  /// Days after a window closes before the late notice fires.
  static const int lateNoticeAfterDays = 5;

  /// Days after the window opens before "likely started" fires.
  static const int likelyStartedAfterDays = 1;

  /// Builds the schedule for [result] as of [today].
  ///
  /// Returns an empty list whenever there is no window to talk about. That
  /// covers [NoData], [TooIrregular], [LostTrack] and [DataInconsistent]: each
  /// is a state where the app has just said it cannot support a window, and a
  /// notification about one would contradict that.
  static List<PlannedNotification> plan({
    required PredictionResult result,
    required CivilDate today,
    required NotificationPreferences preferences,
    CivilDate? lastLoggedDay,
  }) {
    final planned = <PlannedNotification>[];

    final window = switch (result) {
      Predicted(:final prediction) => prediction.window80,
      InsufficientData(:final populationPrior) => populationPrior.window80,
      TooIrregular() || LostTrack() || NoData() || DataInconsistent() => null,
    };

    if (preferences.predictionsEnabled && window != null) {
      final opening = window.start.addDays(-preferences.leadDays);
      if (opening > today) {
        planned.add(
          PlannedNotification(
            kind: NotificationKind.windowOpening,
            fireDate: opening,
          ),
        );
      }
      final started = window.start.addDays(likelyStartedAfterDays);
      if (started > today) {
        planned.add(
          PlannedNotification(
            kind: NotificationKind.likelyStarted,
            fireDate: started,
          ),
        );
      }
      final late = window.end.addDays(lateNoticeAfterDays);
      if (late > today) {
        planned.add(
          PlannedNotification(
            kind: NotificationKind.lateNotice,
            fireDate: late,
          ),
        );
      }
    }

    final nudge = _planNudge(
      today: today,
      preferences: preferences,
      lastLoggedDay: lastLoggedDay,
    );
    if (nudge != null) planned.add(nudge);

    return planned;
  }

  static PlannedNotification? _planNudge({
    required CivilDate today,
    required NotificationPreferences preferences,
    required CivilDate? lastLoggedDay,
  }) {
    if (!preferences.nudgeEnabled) return null;
    if (lastLoggedDay == null) return null;

    // Past the point where the app admits it has lost track, a nudge is not a
    // reminder any more, it is nagging someone who has stopped for a reason.
    final silence = lastLoggedDay.daysBetween(today);
    if (silence > CycleRules.lostTrackAfterDays) return null;

    var fire = lastLoggedDay.addDays(nudgeAfterSilentDays);
    final lastNudge = preferences.lastNudge;
    if (lastNudge != null) {
      // The cap is hard. Pushing the fire date out rather than dropping it
      // keeps one reminder alive without ever exceeding one per seven days.
      final earliest = lastNudge.addDays(nudgeCapDays);
      if (earliest > fire) fire = earliest;
    }
    if (fire <= today) return null;
    return PlannedNotification(
      kind: NotificationKind.loggingNudge,
      fireDate: fire,
    );
  }

  /// Whether a reminder came due while the app was closed.
  ///
  /// OEM battery optimisers on several manufacturers silently kill scheduled
  /// alarms (risk R12), so the app cannot assume anything it scheduled actually
  /// arrived. This is the detection half of the fallback: if a planned date
  /// passed between [lastOpened] and [today], the UI can surface it in app
  /// rather than the reminder simply never having happened.
  static bool missedWhileClosed({
    required List<PlannedNotification> planned,
    required CivilDate? lastOpened,
    required CivilDate today,
  }) {
    if (lastOpened == null) return false;
    return planned.any(
      (notification) =>
          notification.fireDate > lastOpened && notification.fireDate <= today,
    );
  }
}
