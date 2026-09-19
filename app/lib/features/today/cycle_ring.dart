import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One band of the ring: a colour and how many days it covers.
@immutable
class RingBand {
  /// Creates a band of [days] days painted in [color].
  const RingBand({
    required this.days,
    required this.color,
    required this.label,
  });

  /// How many days the band covers.
  ///
  /// Zero is allowed and means the band is not drawn and not named: the
  /// ovulation band is zero whenever the user has not opted in, and the ring
  /// and the legend both filter on it. Painting one anyway would put a
  /// zero-length arc between two gaps, which is just a wider gap.
  final double days;

  /// The colour to paint it.
  final Color color;

  /// What it is, for the ring's screen-reader description.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is RingBand &&
      other.days == days &&
      other.color == color &&
      other.label == label;

  @override
  int get hashCode => Object.hash(days, color, label);
}

/// The cycle as a ring of coloured bands (AND-39).
///
/// Proportional to the days each phase actually covers, drawn clockwise from
/// the top. The bands are separated by a gap rather than butted together, and
/// the caps are square: a round cap extends half the stroke width past the end
/// of its arc, so a 10-wide stroke with a 9-wide gap overlaps its neighbour by
/// one on each side and the two bands appear to bleed into each other.
///
/// The ring is **decoration over text that is already on the screen**. The
/// phase and the day of the cycle are written in the middle of it, the legend
/// names every band, and the prediction beneath states the window in words. A
/// four-colour ring cannot be read on hue alone — follicular and ovular sit
/// around 1.04:1 apart in greyscale in the default scheme — so nothing here is
/// the only way to learn anything, and `semanticsLabel` gives a screen reader
/// the same sentence a sighted reader gets from the middle.
class CycleRing extends StatelessWidget {
  /// Draws [bands] around [child].
  const CycleRing({
    required this.bands,
    required this.semanticsLabel,
    required this.child,
    this.diameter = 252,
    super.key,
  });

  /// The bands, in cycle order.
  final List<RingBand> bands;

  /// What the ring says, for a reader who cannot see it.
  final String semanticsLabel;

  /// What sits in the middle.
  final Widget child;

  /// Outer size of the ring, in logical pixels.
  final double diameter;

  /// Width of the painted band.
  static const double strokeWidth = 10;

  /// Gap between two bands, in the same units as the circumference.
  static const double gap = 9;

  /// Above this text scale the ring is dropped and only [child] is drawn.
  ///
  /// A circle is a fixed box and text inside one is not: at a large scale the
  /// two lines in the middle stop fitting, and the honest answer is to keep the
  /// words. Nothing is lost by it — the ring is decoration over text that is
  /// already on the screen, and the legend beneath still names every phase.
  static const double maxScaleWithRing = 1.35;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (scale > maxScaleWithRing) {
      return Semantics(
        label: semanticsLabel,
        container: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: child,
        ),
      );
    }
    return Semantics(
      label: semanticsLabel,
      // The bands are described by the label above; the middle is real text
      // and stays readable on its own.
      container: true,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size.square(diameter),
              painter: _RingPainter(bands: bands),
            ),
            // The largest square that fits inside the ring's inner circle, not
            // the inner circle's bounding box: a box the full width of the
            // circle has corners outside it, and text in those corners sits
            // under the band.
            SizedBox(
              width: (diameter - strokeWidth * 2) * 0.68,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.bands});

  final List<RingBand> bands;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = bands.where((band) => band.days > 0).toList();
    if (drawn.isEmpty) return;

    final radius = (size.shortestSide - CycleRing.strokeWidth) / 2;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final totalDays = drawn.fold<double>(0, (sum, band) => sum + band.days);
    if (totalDays <= 0) return;

    // Every band gives up the same amount to the gap either side of it, so the
    // gaps stay even however lopsided the phases are. With enough bands to eat
    // the whole circle the gaps shrink rather than the arcs going negative.
    final wanted = CycleRing.gap * drawn.length;
    final gapTotal = math.min(wanted, circumference * 0.25);
    final gap = gapTotal / drawn.length;
    final paintable = circumference - gapTotal;

    var cursor = -math.pi / 2 + (gap / 2) / radius;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final band in drawn) {
      final sweep = (band.days / totalDays) * paintable / radius;
      canvas.drawArc(
        rect,
        cursor,
        sweep,
        false,
        Paint()
          ..color = band.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = CycleRing.strokeWidth
          // Square caps would extend past each end by half the stroke and eat
          // the gap; butt stops exactly where the arc does.
          ..strokeCap = StrokeCap.butt,
      );
      cursor += sweep + gap / radius;
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      !listEquals(oldDelegate.bands, bands);
}

/// The names of the bands, with their colours, under the ring.
///
/// The swatch and the word travel together and always in the same order, so
/// the legend is what makes the ring legible rather than the hues being
/// distinguishable on their own.
class RingLegend extends StatelessWidget {
  /// Names [bands].
  const RingLegend({required this.bands, super.key});

  /// The same bands the ring was drawn from.
  final List<RingBand> bands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: <Widget>[
        for (final band in bands.where((band) => band.days > 0))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The swatch is decoration beside its own label, so it is not
              // announced twice.
              ExcludeSemantics(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: band.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                band.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
