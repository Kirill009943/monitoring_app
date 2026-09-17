import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../data/models.dart';
import '../common/widgets.dart';

class MetricChart extends StatelessWidget {
  final List<TimeValue> data;
  final GraphPrefs prefs;

  const MetricChart({super.key, required this.data, required this.prefs});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 220,
        child: EmptyState(
          icon: Icons.query_stats,
          title: 'No data in this range yet',
          body: 'Turn on background monitoring and check back later.',
        ),
      );
    }
    final color = Color(prefs.colorValue);
    final border = Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.4));
    return SizedBox(
      height: 220,
      child: prefs.isBar ? _bar(color, border) : _line(color, border),
    );
  }

  Widget _line(Color color, Border border) {
    return LineChart(
      LineChartData(
        minY: prefs.minY,
        maxY: prefs.maxY,
        gridData: FlGridData(show: prefs.showGrid),
        borderData: FlBorderData(show: true, border: border),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final p in data) FlSpot(p.ts.toDouble(), p.value),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color color, Border border) {
    final width = data.length > 60
        ? 3.0
        : data.length > 30
            ? 6.0
            : 12.0;
    return BarChart(
      BarChartData(
        minY: prefs.minY,
        maxY: prefs.maxY,
        gridData: FlGridData(show: prefs.showGrid),
        borderData: FlBorderData(show: true, border: border),
        titlesData: const FlTitlesData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        barGroups: [
          for (final p in data)
            BarChartGroupData(
              x: p.ts,
              barRods: [
                BarChartRodData(
                  toY: p.value,
                  color: color,
                  width: width,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
