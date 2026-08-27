import 'package:flutter/material.dart';

/// How long things take to move, and how they get there (AND-34).
///
/// Three durations and one curve are the whole vocabulary: [quick] for a
/// control answering a finger, [standard] for one surface replacing another,
/// [entrance] for content arriving. Two more exist because AND-34 pins two
/// specific surfaces to figures that are not any of the three — [monthSlide]
/// and [stagger] — and they live here rather than at their call sites for the
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
/// site is where it gets forgotten — the same argument the theme makes for the
/// 48dp tap-target floor. `motion_test.dart` fails if any token here returns
/// something other than zero with animations off, so a new one cannot be added
/// that skips the check.
///
/// Turning motion off drops the *interpolation*, never the state change. A tab
/// still switches, a chip still shows its checkmark, a card is still there; it
/// simply happens on the frame it was asked for. Nothing in this app becomes
/// unreadable or unreachable with animations off, and nothing may be built that
/// only appears once an animation has run.
abstract final class Motion {
  /// A control answering a finger: chip selection, a checkmark.
  static Duration quick(BuildContext context) => _resolve(context, _quick);

  /// One surface replacing another: a tab change, a phase crossfade.
  static Duration standard(BuildContext context) =>
      _resolve(context, _standard);

  /// Content arriving on a screen that was empty a moment ago.
  static Duration entrance(BuildContext context) =>
      _resolve(context, _entrance);

  /// The month grid travelling one month left or right.
  ///
  /// Between [quick] and [standard] on purpose: the grid is a large surface, so
  /// it needs longer than a chip, but it is also the thing a user steps through
  /// repeatedly looking for a date, and at [standard] the fourth tap feels like
  /// waiting.
  static Duration monthSlide(BuildContext context) =>
      _resolve(context, _monthSlide);

  /// The gap between one entering card and the next.
  ///
  /// A duration rather than a delay constant so it collapses with everything
  /// else: a stagger that survived "remove animations" would leave content
  /// appearing in sequence, which is the effect the setting exists to stop.
  static Duration stagger(BuildContext context) => _resolve(context, _stagger);

  /// The one easing curve. Decelerating, so movement arrives rather than stops.
  static const Curve curve = Curves.easeOutCubic;

  /// Every token, resolved for [context] and keyed for the failure message.
  ///
  /// Exists so `motion_test.dart` can walk the whole set rather than naming
  /// them one at a time. A token added below must be added here too; the test
  /// checks the count as well as the values, so leaving it out fails.
  static Map<String, Duration> all(BuildContext context) => <String, Duration>{
    'quick': quick(context),
    'standard': standard(context),
    'entrance': entrance(context),
    'monthSlide': monthSlide(context),
    'stagger': stagger(context),
  };

  static const Duration _quick = Duration(milliseconds: 120);
  static const Duration _standard = Duration(milliseconds: 220);
  static const Duration _entrance = Duration(milliseconds: 320);
  static const Duration _monthSlide = Duration(milliseconds: 180);
  static const Duration _stagger = Duration(milliseconds: 40);

  static Duration _resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
