/// Chip selection motion.
///
/// Wraps every selectable chip in the app so that selecting one settles rather
/// than snaps, and so that the checkmark appearing never changes the chip's
/// width. Both halves are here because separating them is how the second one
/// gets forgotten.
///
/// Includes:
///     - ChipMotion: The wrapper, its scale and its reserved slot.
///     - _ChipMotionState: The one controller behind both.
///     - _CheckSlot: The slot itself, and the checkmark that fades in it.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/core/motion.dart';

/// Chip motion: makes selecting a chip an answer, not a repaint (AND-34).
///
/// Every selectable chip in the app is built through this, and the builder
/// hands back the avatar the chip has to carry, so the two halves cannot come
/// apart:
///
/// ```dart
/// ChipMotion(
///   selected: recorded,
///   builder: (context, checkSlot) => FilterChip(
///     avatar: checkSlot,
///     selected: recorded,
///     onSelected: ...,
///     label: Text(label),
///   ),
/// )
/// ```
///
/// **The scale** runs [Motion.quick] on every selection change and takes the
/// chip from 0.96 back to 1, so it settles under the finger instead of
/// snapping. At rest the scale is exactly 1 in *both* states, never 0.96 for
/// an unselected chip, because a chip painted at 96% is a tap target painted
/// at 96%, and `a11y_test.dart` measures the rendered rect against the 48dp
/// floor.
///
/// **The slot** is what stops the row reflowing. Material lays the checkmark
/// out in the avatar slot, and a chip with no avatar has no slot: selecting one
/// opens a drawer as wide as the chip is tall, and everything to its right
/// slides along under a finger that has not lifted yet. On a `Wrap` of sixteen
/// symptom chips it can also push a chip onto the next line. An avatar that is
/// always there holds the space open, and the width never changes.
///
/// The checkmark inside the slot is drawn here rather than by Material, and
/// `AppTheme` sets `showCheckmark: false` for that reason. Material's own
/// checkmark rides a fixed 195ms select animation that no accessibility setting
/// reaches; this one fades over [Motion.quick], which is zero when the device
/// has asked for no animation.
///
/// One caveat, on the symptom chips only: their *label* grows when a severity
/// is recorded, gaining a separator and a word after the symptom's name. That
/// is a deliberate never-colour-alone requirement from `docs/PLAN.md` 2.4.4
/// and moves the row regardless. The slot removes the checkmark's
/// contribution to the reflow, not the label's.
///
/// With animations off the controller lands on its end value on the frame it
/// was started, so the chip is simply selected, with its checkmark, at once.
///
/// Attributes:
///     selected (bool): Whether the chip is currently selected.
///     builder (`Widget Function(BuildContext, Widget)`): Builds the chip,
///         given the avatar it must carry.
class ChipMotion extends StatefulWidget {
  /// Builds a chip that is [selected], passing it the avatar it must carry.
  ///
  /// Args:
  ///     selected (bool): Whether the chip is currently selected.
  ///     builder (`Widget Function(BuildContext, Widget)`): Builds the chip.
  ///         Its second argument is the avatar the chip must use, and a
  ///         builder that drops it reintroduces the reflow this widget exists
  ///         to remove.
  const ChipMotion({required this.selected, required this.builder, super.key});

  /// Whether the chip is currently selected.
  ///
  /// Passed in rather than read off the built chip, because `ChoiceChip`,
  /// `FilterChip` and the rest share no interface that exposes it.
  final bool selected;

  /// Builds the chip. The second argument is the avatar the chip must use.
  final Widget Function(BuildContext context, Widget checkSlot) builder;

  /// The size of the reserved avatar slot.
  ///
  /// Matches the box Material would have opened for its own checkmark, so the
  /// chip is the size it always was in the selected state.
  static const double slotSize = 18;

  /// How far the chip is scaled down at the start of a selection change.
  static const double _dip = 0.96;

  @override
  State<ChipMotion> createState() => _ChipMotionState();
}

/// State for [ChipMotion]: the one controller both halves run off.
///
/// Attributes:
///     _controller (AnimationController): The selection animation, driving
///         both the scale and the checkmark's opacity.
class _ChipMotionState extends State<ChipMotion>
    with SingleTickerProviderStateMixin {
  /// Runs 0 to 1 on every selection change, and rests at 1.
  ///
  /// Starting completed means a chip that is already selected the first time it
  /// is built does not animate itself in, which would make every rebuild of a
  /// screen look like a fresh answer.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void didUpdateWidget(ChipMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read on every build rather than once: the accessibility setting can be
    // changed while the app is open, and the controller only consults its
    // duration when it is next started.
    _controller.duration = Motion.quick(context);
    final chip = widget.builder(
      context,
      _CheckSlot(progress: _controller, selected: widget.selected),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale:
            ChipMotion._dip +
            (1 - ChipMotion._dip) * Motion.curve.transform(_controller.value),
        // Chips are laid out before they are transformed, so this paints the
        // chip smaller without moving anything beside it.
        child: child,
      ),
      child: chip,
    );
  }
}

/// The avatar slot: reserved space, with a checkmark that fades in it.
///
/// A fixed [ChipMotion.slotSize] square whether or not the checkmark is
/// showing, which is the whole reason the slot exists: the space is held open
/// so nothing beside the chip moves when it is selected.
///
/// Attributes:
///     progress (`Animation<double>`): The parent's selection animation.
///     selected (bool): Which way the checkmark is going.
class _CheckSlot extends StatelessWidget {
  /// Creates the slot.
  ///
  /// Args:
  ///     progress (`Animation<double>`): The parent's 0-to-1 selection
  ///         animation.
  ///     selected (bool): Which way the checkmark is going. True fades it in,
  ///         false fades it out, over the same run.
  const _CheckSlot({required this.progress, required this.selected});

  /// The parent's 0-to-1 selection animation.
  final Animation<double> progress;

  /// Which way the checkmark is going.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: ChipMotion.slotSize,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          final eased = Motion.curve.transform(progress.value);
          return Opacity(opacity: selected ? eased : 1 - eased, child: child);
        },
        child: Icon(
          Icons.check,
          size: ChipMotion.slotSize,
          // The same colour the label uses, which is the pair `theme_test.dart`
          // and `a11y_test.dart` already hold to 4.5:1 against the chip's fill.
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
