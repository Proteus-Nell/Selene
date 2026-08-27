import 'package:flutter/material.dart';
import 'package:period_tracker/domain/cycles/features.dart';
import 'package:period_tracker/domain/models/cycle_record.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// A bar chart of recent cycle lengths, and the same numbers as a table.
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
class CycleLengthChart extends StatefulWidget {
  /// Charts the completed cycles in [cycles].
  const CycleLengthChart({required this.cycles, super.key});

  /// The user's cycles, oldest first.
  final List<CycleRecord> cycles;

  /// How many recent cycles are shown.
  static const int maxBars = 12;

  @override
  State<CycleLengthChart> createState() => _CycleLengthChartState();
}

class _CycleLengthChartState extends State<CycleLengthChart> {
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

class _LengthTable extends StatelessWidget {
  const _LengthTable({required this.cycles});

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

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.lengths,
    required this.barColor,
    required this.axisColor,
  });

  final List<int> lengths;
  final Color barColor;
  final Color axisColor;

  /// How strongly the cycles behind the most recent one are drawn.
  ///
  /// The last bar is the one the reader came for; the rest are the shape it
  /// sits in. Holding them back is a drawing decision and nothing else — the
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

  static bool _sameLengths(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
