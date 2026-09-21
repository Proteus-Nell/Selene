/// Motion tokens.
///
/// Holds every animation duration and the single easing curve the app uses, so
/// that the "remove animations" accessibility setting is honoured in one place
/// rather than at each call site. Exposes one static accessor per token, each
/// taking a [BuildContext] and collapsing to [Duration.zero] when the device
/// asks for no animation.
///
/// Includes:
///     - Motion: The token set, its curve, and the [Motion.all] roll-up the
///       test walks.
library;

import 'package:flutter/material.dart';

/// Motion vocabulary: how long things take to move, and how they get there
/// (AND-34).
///
/// Three durations and one curve are the whole vocabulary: [quick] for a
/// control answering a finger, [standard] for one surface replacing another,
/// [entrance] for content arriving. Two more exist because AND-34 pins two
/// specific surfaces to figures that are not any of the three, [monthSlide]
/// and [stagger], and they live here rather than at their call sites for the
/// reason below.
///
/// **Every duration is read through a [BuildContext] and collapses to
/// [Duration.zero] when the device asks for no animation.** Android's "remove
/// animations" accessibility setting, and iOS's reduce-motion, arrive as
/// [MediaQuery.disableAnimationsOf]. Honouring it is not optional: motion
/// triggers nausea and migraine for some people, and a setting the system
/// offers and an app ignores is worse than one it never had.
///
/// The check lives on the token rather than at each call site, because a call
/// site is where it gets forgotten. That is the same argument the theme makes
/// for the 48dp tap-target floor. `motion_test.dart` fails if any token here
/// returns something other than zero with animations off, so a new one cannot
/// be added that skips the check.
///
/// Turning motion off drops the *interpolation*, never the state change. A tab
/// still switches, a chip still shows its checkmark, a card is still there; it
/// simply happens on the frame it was asked for. Nothing in this app becomes
/// unreadable or unreachable with animations off, and nothing may be built
/// that only appears once an animation has run.
abstract final class Motion {
  /// Return how long a control takes to answer a finger.
  ///
  /// Chip selection, a checkmark appearing.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     Duration: The token, or [Duration.zero] with animations off.
  static Duration quick(BuildContext context) => _resolve(context, _quick);

  /// Return how long one surface takes to replace another.
  ///
  /// A tab change, a phase crossfade.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     Duration: The token, or [Duration.zero] with animations off.
  static Duration standard(BuildContext context) =>
      _resolve(context, _standard);

  /// Return how long content takes to arrive on an empty screen.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     Duration: The token, or [Duration.zero] with animations off.
  static Duration entrance(BuildContext context) =>
      _resolve(context, _entrance);

  /// Return how long the month grid takes to travel one month.
  ///
  /// Between [quick] and [standard] on purpose: the grid is a large surface,
  /// so it needs longer than a chip, but it is also the thing a user steps
  /// through repeatedly looking for a date, and at [standard] the fourth tap
  /// feels like waiting.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     Duration: The token, or [Duration.zero] with animations off.
  static Duration monthSlide(BuildContext context) =>
      _resolve(context, _monthSlide);

  /// Return the gap between one entering card and the next.
  ///
  /// A duration rather than a delay constant so it collapses with everything
  /// else: a stagger that survived "remove animations" would leave content
  /// appearing in sequence, which is the effect the setting exists to stop.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     Duration: The token, or [Duration.zero] with animations off.
  static Duration stagger(BuildContext context) => _resolve(context, _stagger);

  /// The one easing curve. Decelerating, so movement arrives rather than
  /// stops.
  static const Curve curve = Curves.easeOutCubic;

  /// Return every token, resolved for [context] and keyed by name.
  ///
  /// Exists so `motion_test.dart` can walk the whole set rather than naming
  /// them one at a time. A token added below must be added here too; the test
  /// checks the count as well as the values, so leaving it out fails.
  ///
  /// Args:
  ///     context (BuildContext): Read for the reduce-motion setting.
  ///
  /// Returns:
  ///     `Map<String, Duration>`: Token name to resolved duration, for all
  ///     five tokens.
  static Map<String, Duration> all(BuildContext context) => <String, Duration>{
    'quick': quick(context),
    'standard': standard(context),
    'entrance': entrance(context),
    'monthSlide': monthSlide(context),
    'stagger': stagger(context),
  };

  // ----- Token values -----
  // Figures pinned by AND-34, not tuned at call sites. Any change here moves
  // the whole app at once, which is the point of the file. The counts and the
  // values are both asserted @ motion_test.dart.
  static const Duration _quick = Duration(milliseconds: 120); // finger answer
  static const Duration _standard = Duration(milliseconds: 220); // surface swap
  static const Duration _entrance = Duration(milliseconds: 320); // content in
  /// The month grid's travel time.
  ///
  /// ### Deliberately between _quick and _standard, not one of the three, so
  /// a user stepping through months does not wait @ calendar_screen.dart
  static const Duration _monthSlide = Duration(milliseconds: 180);
  static const Duration _stagger = Duration(milliseconds: 40); // card-to-card

  /// Return [duration], or [Duration.zero] if the device wants no animation.
  ///
  /// The single place the accessibility setting is read. Every public token
  /// above goes through here, so none of them can forget it.
  ///
  /// Args:
  ///     context (BuildContext): Read for [MediaQuery.disableAnimationsOf].
  ///     duration (Duration): The token's value when motion is allowed.
  ///
  /// Returns:
  ///     Duration: [duration], or [Duration.zero].
  static Duration _resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
