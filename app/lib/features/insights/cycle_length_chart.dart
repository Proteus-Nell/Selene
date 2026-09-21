/// Cycle length chart.
///
/// Draws the recent cycle lengths as bars, and offers the identical numbers as
/// a table. Painted by hand rather than through a charting package, because a
/// dozen bars is not worth a dependency and the greyscale and text-scaling
/// requirements are easier to meet than to fight.
///
/// Includes:
///     - CycleLengthChart: The chart, its summary and the table toggle.
///     - _CycleLengthChartState: Which of the two views is showing.
///     - _LengthTable: The same numbers, as rows.
///     - _BarPainter: The bars themselves.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Cycle length chart: recent cycle lengths as bars, and as a table.
///
/// Anything that paints to a canvas is **invisible** to a screen reader: there
/// are no semantics under a [CustomPaint] unless someone writes them. So the
/// chart carries a text summary, and the identical data is one tap away as a
/// table (`docs/PLAN.md` 2.4.4). The table is not a lesser fallback; for
/// several cycles it is the more precise view, which is why it is offered to
/// everyone rather than hidden behind an accessibility setting.
///
/// Drawn by hand rather than with a charting package. A dozen bars is not worth
/// a dependency, and painting it directly is what makes the greyscale and
/// text-scaling requirements straightforward to meet rather than fought for.
///
/// Attributes:
///     cycles (`List<CycleRecord>`): The user's cycles, oldest first.
class CycleLengthChart extends StatefulWidget {
  /// Charts the completed cycles in [cycles].
  ///
  /// Args:
  ///     cycles (`List<CycleRecord>`): The user's cycles, oldest first. The
  ///         incomplete ones are filtered out here rather than by the caller,
  ///         and the last [maxBars] of what remains are drawn.
  const CycleLengthChart({required this.cycles, super.key});

  /// The user's cycles, oldest first.
  final List<CycleRecord> cycles;

  /// How many recent cycles are shown.
  static const int maxBars = 12;

  @override
  State<CycleLengthChart> createState() => _CycleLengthChartState();
}

/// State for [CycleLengthChart]: which of the two views is showing.
///
/// Attributes:
///     _showTable (bool): Whether the table has replaced the bars.
class _CycleLengthChartState extends State<CycleLengthChart> {
  /// Whether the table has replaced the bars.
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completed = widget.cycles
        .where((c) => c.isUsableObservation)
        .toList();
    if (completed.length < 2) {
      return Text(
        l10n.insightsNotEnoughForStats,
        style: theme.textTheme.bodyMedium,
      );
    }

    final shown = completed.length <= CycleLengthChart.maxBars
        ? completed
        : completed.sublist(completed.length - CycleLengthChart.maxBars);
    final lengths = shown.map((c) => c.lengthInDays!).toList();
    final summary = l10n.insightsChartSummary(
      lengths.length,
      lengths.reduce((a, b) => a < b ? a : b),
      lengths.reduce((a, b) => a > b ? a : b),
      formatDays(
        CycleFeatures.median(lengths.map((l) => l.toDouble()).toList()),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.insightsChartTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showTable = !_showTable),
              icon: Icon(_showTable ? Icons.bar_chart : Icons.table_rows),
              label: Text(
                _showTable
                    ? l10n.insightsChartShowChart
                    : l10n.insightsChartShowTable,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showTable)
          _LengthTable(cycles: shown)
        else
          Semantics(
            label: summary,
            // The painted bars carry no semantics of their own, so the summary
            // above is the whole announcement rather than a supplement to it.
            excludeSemantics: true,
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _BarPainter(
                  lengths: lengths,
                  barColor: theme.colorScheme.primary,
                  axisColor: theme.colorScheme.outline,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        const SizedBox(height: 4),
        // Also printed, not only announced: a summary in text is useful to
        // everyone, and it is the only form that survives a screenshot.
        Text(summary, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// The same numbers as the chart, as rows.
///
/// Not a lesser fallback. For several cycles it is the more precise view, and
/// it is offered to everyone rather than hidden behind an accessibility
/// setting (`docs/PLAN.md` 2.4.4).
///
/// Attributes:
///     cycles (`List<CycleRecord>`): The cycles being shown, oldest first.
class _LengthTable extends StatelessWidget {
  /// Creates the table.
  ///
  /// Args:
  ///     cycles (`List<CycleRecord>`): The cycles being shown, oldest first.
  ///         Already filtered to the completed ones the chart draws, so every
  ///         row has a length.
  const _LengthTable({required this.cycles});

  /// The cycles being shown, oldest first.
  final List<CycleRecord> cycles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: <DataColumn>[
          DataColumn(label: Text(l10n.insightsChartColumnCycle)),
          DataColumn(label: Text(l10n.insightsChartColumnStarted)),
          DataColumn(label: Text(l10n.insightsChartColumnLength)),
        ],
        rows: <DataRow>[
          for (var i = 0; i < cycles.length; i++)
            DataRow(
              cells: <DataCell>[
                DataCell(Text('${i + 1}')),
                DataCell(Text(cycles[i].startDate.dayAndMonth(context))),
                DataCell(
                  Text(l10n.insightsChartLengthDays(cycles[i].lengthInDays!)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The bars themselves.
///
/// Carries no semantics, and cannot: nothing under a [CustomPaint] reaches a
/// screen reader unless it is written by hand. The announcement is the summary
/// the chart puts above it, which is why that summary is the whole sentence
/// rather than a supplement to the picture.
///
/// Attributes:
///     lengths (`List<int>`): The cycle lengths to draw, oldest first.
///     barColor (Color): The most recent bar's colour.
///     axisColor (Color): The baseline's colour.
class _BarPainter extends CustomPainter {
  /// Creates the painter.
  ///
  /// Args:
  ///     lengths (`List<int>`): The cycle lengths to draw, oldest first. The
  ///         last entry is the one drawn at full strength.
  ///     barColor (Color): The most recent bar's colour. The rest are drawn
  ///         from the same colour at [_historyAlpha].
  ///     axisColor (Color): The baseline's colour.
  _BarPainter({
    required this.lengths,
    required this.barColor,
    required this.axisColor,
  });

  /// The cycle lengths to draw, oldest first.
  final List<int> lengths;

  /// The most recent bar's colour.
  final Color barColor;

  /// The baseline's colour.
  final Color axisColor;

  /// How strongly the cycles behind the most recent one are drawn.
  ///
  /// The last bar is the one the reader came for; the rest are the shape it
  /// sits in. Holding them back is a drawing decision and nothing else. The
  /// summary underneath, and the table behind the toggle, carry every figure at
  /// full strength, so nothing here is the only way to reach a number.
  static const double _historyAlpha = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    if (lengths.isEmpty) return;
    final maxLength = lengths.reduce((a, b) => a > b ? a : b);
    final minLength = lengths.reduce((a, b) => a < b ? a : b);
    // A floor of zero would squash every real difference into the top few
    // pixels: cycles cluster between 25 and 35 days, so the interesting
    // variation is the last quarter of the range.
    final floor = (minLength - 4).clamp(0, minLength).toDouble();
    final span = (maxLength - floor).clamp(1, 1000).toDouble();

    final barPaint = Paint()..color = barColor;
    final historyPaint = Paint()
      ..color = barColor.withValues(alpha: _historyAlpha);
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    final slot = size.width / lengths.length;
    final barWidth = (slot * 0.6).clamp(2.0, 28.0);
    for (var i = 0; i < lengths.length; i++) {
      final fraction = (lengths[i] - floor) / span;
      final height = (size.height - 8) * fraction;
      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          const Radius.circular(2),
        ),
        i == lengths.length - 1 ? barPaint : historyPaint,
      );
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.barColor != barColor ||
      oldDelegate.axisColor != axisColor ||
      !_sameLengths(oldDelegate.lengths, lengths);

  /// Report whether two length lists hold the same numbers in the same order.
  ///
  /// Element by element rather than by identity, because the chart rebuilds
  /// its list on every build and an identity check would repaint every frame.
  ///
  /// Args:
  ///     a (`List<int>`): One list.
  ///     b (`List<int>`): The other.
  ///
  /// Returns:
  ///     bool: True when they are the same length and equal at every index.
  static bool _sameLengths(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
