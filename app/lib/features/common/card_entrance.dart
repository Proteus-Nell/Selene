import 'package:flutter/material.dart';
import 'package:period_tracker/core/motion.dart';

/// Fades a card in and lifts it 8px into place, once (AND-34).
///
/// Wrapped around the sections of a screen that arrives all at once, with
/// [index] counting down the screen, so they land in reading order rather than
/// together. The gap is [Motion.stagger] and the movement is [Motion.entrance].
///
/// **Once per visit, never on rebuild.** The animation starts the first time
/// this widget's state is created and never again, so a screen that rebuilds
/// because a day was logged does not replay its own arrival — which would make
/// every save look like a page load. Riverpod rebuilds these screens on every
/// database change, so this is the common case rather than the edge one.
///
/// **Capped at [maxStaggered].** Past the fifth card the delay stops growing.
/// A stagger that kept counting would have the ninth card arriving a third of a
/// second after the first, and a reader who scrolls immediately would be
/// scrolling into content that has not shown up yet.
///
/// **The rise is 8px and nothing depends on it.** The card is laid out where it
/// belongs and painted 8px low for a moment; nothing reflows, nothing moves
/// under a finger, and with animations off the card is simply there. No content
/// in this app may require an entrance to have run in order to be readable.
class CardEntrance extends StatefulWidget {
  /// Brings [child] in as the [index]th card on its screen, counting from 0.
  const CardEntrance({required this.index, required this.child, super.key});

  /// Position down the screen. Only the first [maxStaggered] are staggered.
  final int index;

  /// The card.
  final Widget child;

  /// How many cards get their own step in the stagger.
  static const int maxStaggered = 5;

  /// How far below its resting place a card starts, in logical pixels.
  static const double rise = 8;

  @override
  State<CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Where in the controller's run this card starts moving.
  double _start = 0;

  bool _begun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;

    // The delay is part of the animation rather than a Timer before it. A timer
    // is a second clock to reason about, it has to be cancelled on dispose, and
    // it is the usual reason a widget test hangs on `pumpAndSettle`.
    final step = widget.index.clamp(0, CardEntrance.maxStaggered - 1);
    final delay = Motion.stagger(context) * step;
    final total = delay + Motion.entrance(context);
    if (total == Duration.zero) {
      // Animations are off. The card is where it belongs, at full opacity, on
      // this frame.
      _controller.value = 1;
      return;
    }
    _start = delay.inMicroseconds / total.inMicroseconds;
    _controller
      ..duration = total
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Interval(
          _start,
          1,
          curve: Motion.curve,
        ).transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, CardEntrance.rise * (1 - progress)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
