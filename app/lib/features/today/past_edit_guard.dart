/// The guard in front of editing a past day.
///
/// Tapping a day on the Today tab opens it locked: what was recorded is shown,
/// and nothing can be changed until the lock is lifted (ADR-0027). This file
/// holds the rules for when the lock applies, when the app offers to stand it
/// down, and when it comes back, so they can be tested without a widget.
///
/// Nothing here is persisted. The counts and the stand-down live for as long
/// as the app is running and no longer, for two reasons: every setting this
/// app stores travels in the user's export, and when the user has edited days
/// is behaviour rather than anything they recorded about themselves; and a
/// guard that is still down after the phone has been put away is a guard that
/// has stopped guarding.
///
/// Includes:
///     - PastEditGuard: The rules, as a value.
///     - pastEditGuardProvider: The one live instance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';

/// Whether a past day is locked, and whether to offer to stop asking.
///
/// Immutable: every change answers with a new guard, so a test can hold two
/// points on the same timeline at once, and the provider below replaces one
/// value with the next rather than mutating in place.
///
/// Attributes:
///     changes (`Map<CivilDate, DateTime>`): When each day was last changed,
///         most recent wins, as UTC instants.
///     standDownUntil (DateTime?): When the lock comes back, or null when it
///         is not standing down.
@immutable
final class PastEditGuard {
  /// Creates a guard.
  ///
  /// Args:
  ///     changes (`Map<CivilDate, DateTime>`, optional): When each day was
  ///         last changed. Defaults to none.
  ///     standDownUntil (DateTime?, optional): When the lock returns.
  ///         Defaults to null, which is a lock in force.
  const PastEditGuard({
    this.changes = const <CivilDate, DateTime>{},
    this.standDownUntil,
  });

  /// When each day was last changed, as UTC instants.
  final Map<CivilDate, DateTime> changes;

  /// When the lock comes back, or null when it is in force.
  final DateTime? standDownUntil;

  /// How many days changed inside [bulkWindow] counts as working in bulk.
  ///
  /// The offer appears on the *next* day after this many, so four days inside
  /// the window is what it takes. Three is a correction; four is a sitting.
  static const int bulkThreshold = 3;

  /// How far back the count of changed days reaches.
  static const Duration bulkWindow = Duration(minutes: 10);

  /// How long the lock stands down once the user asks it to.
  ///
  /// Long enough to finish catching up a week of logging, short enough that
  /// the guard is back before the next time the app is opened for something
  /// else. It is never indefinite: there is no setting for that, on purpose.
  static const Duration standDown = Duration(minutes: 30);

  /// Whether [date] needs the lock lifted before it can be changed.
  ///
  /// Today never does: the Today tab is where today is logged, and asking
  /// about the day the screen is named after would be noise. Neither does a
  /// future day, which cannot be written at all
  /// (`CycleRepository` refuses it), so the sheet does not offer to.
  ///
  /// Args:
  ///     date (CivilDate): The day being opened.
  ///     today (CivilDate): The current day.
  ///     now (DateTime): The current instant, for the stand-down.
  ///
  /// Returns:
  ///     bool: True when the sheet should open locked.
  bool locks(
    CivilDate date, {
    required CivilDate today,
    required DateTime now,
  }) {
    if (date.epochDay >= today.epochDay) return false;
    return !standingDown(now);
  }

  /// Whether the lock is currently standing down.
  ///
  /// Args:
  ///     now (DateTime): The current instant.
  ///
  /// Returns:
  ///     bool: True until [standDownUntil] passes.
  bool standingDown(DateTime now) {
    final until = standDownUntil;
    return until != null && now.isBefore(until);
  }

  /// How many distinct days were changed in the [bulkWindow] before [now].
  ///
  /// Args:
  ///     now (DateTime): The current instant.
  ///
  /// Returns:
  ///     int: The count, counting each day once however often it changed.
  int recentlyChanged(DateTime now) {
    final since = now.subtract(bulkWindow);
    return changes.values.where((at) => at.isAfter(since)).length;
  }

  /// Whether to offer to stand the lock down.
  ///
  /// Only while it is up, and only once the user has shown they are working
  /// through several days rather than fixing one.
  ///
  /// Args:
  ///     now (DateTime): The current instant.
  ///
  /// Returns:
  ///     bool: True when the offer belongs on screen.
  bool offersStandDown(DateTime now) =>
      !standingDown(now) && recentlyChanged(now) > bulkThreshold;

  /// Record that [date] was changed at [now].
  ///
  /// Days whose last change has fallen out of the window are dropped as they
  /// go, so the map cannot grow for the life of the process.
  ///
  /// Args:
  ///     date (CivilDate): The day that changed.
  ///     now (DateTime): When it changed.
  ///
  /// Returns:
  ///     PastEditGuard: A guard carrying the change.
  PastEditGuard changed(CivilDate date, DateTime now) {
    final since = now.subtract(bulkWindow);
    return PastEditGuard(
      changes: <CivilDate, DateTime>{
        for (final entry in changes.entries)
          if (entry.value.isAfter(since)) entry.key: entry.value,
        date: now,
      },
      standDownUntil: standDownUntil,
    );
  }

  /// Stand the lock down for [standDown] from [now].
  ///
  /// Args:
  ///     now (DateTime): When the user asked.
  ///
  /// Returns:
  ///     PastEditGuard: A guard that locks nothing until it expires.
  PastEditGuard standingDownFrom(DateTime now) => PastEditGuard(
    changes: changes,
    standDownUntil: now.add(standDown),
  );
}

/// The live guard, for as long as the app is running.
///
/// A [StateProvider] as the notification revision is, rather than a notifier:
/// the guard is a value with two transitions and no asynchronous work, and the
/// transitions are its own methods.
final StateProvider<PastEditGuard> pastEditGuardProvider =
    StateProvider<PastEditGuard>((ref) => const PastEditGuard());
