import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../data/stats_repo.dart';
import '../common/widgets.dart';
import 'metric_chart.dart';

enum StatsRange { day, week, month }

extension on StatsRange {
  String get label => switch (this) {
        StatsRange.day => '24 h',
        StatsRange.week => '7 days',
        StatsRange.month => '30 days',
      };
}

class MetricData {
  final List<TimeValue> points;
  final MinAvgMax summary;
  final String unit;

  const MetricData(this.points, this.summary, this.unit);
}

Future<MetricData> loadMetricData(
  SettingsProvider settings,
  MetricRef metric,
  StatsRange range,
) async {
  final repo = StatsRepo();
  final now = DateTime.now().millisecondsSinceEpoch;
  List<TimeValue> raw;

  if (metric.kind == 'usage') {
    switch (range) {
      case StatsRange.day:
        raw = await repo.series(
          kind: 'usage',
          key: metric.key,
          startMs: now - 86400000,
          endMs: now,
          bucketMs: 3600000,
        );
      case StatsRange.week:
        raw = await repo.dailyUsageSeries(packageName: metric.key, days: 7);
      case StatsRange.month:
        raw = await repo.dailyUsageSeries(packageName: metric.key, days: 30);
    }
  } else {
    final start = switch (range) {
      StatsRange.day => now - 86400000,
      StatsRange.week => now - 7 * 86400000,
      StatsRange.month => now - 30 * 86400000,
    };
    final bucket = switch (range) {
      StatsRange.day => null,
      StatsRange.week => 3600000,
      StatsRange.month => 6 * 3600000,
    };
    raw = await repo.series(
      kind: metric.kind,
      key: metric.key,
      startMs: start,
      endMs: now,
      bucketMs: bucket,
    );
  }

  double convert(double v) {
    if (metric.kind == 'thermal' ||
        (metric.kind == 'battery' && metric.key == 'temp')) {
      return displayTemp(v, settings.useCelsius);
    }
    if (metric.kind == 'battery' && metric.key == 'voltageMv') return v / 1000;
    if (metric.kind == 'battery' && metric.key == 'currentUa') return v / 1000;
    if (metric.kind == 'usage') return v / 60;
    return v;
  }

  final points = [
    for (final p in raw) TimeValue(p.ts, convert(p.value)),
  ];

  final unit = () {
    if (metric.kind == 'thermal' ||
        (metric.kind == 'battery' && metric.key == 'temp')) {
      return tempUnit(settings.useCelsius);
    }
    if (metric.kind == 'battery') {
      return switch (metric.key) {
        'level' => '%',
        'voltageMv' => 'V',
        'currentUa' => 'mA',
        _ => '',
      };
    }
    if (metric.kind == 'usage') return 'min';
    return '';
  }();

  if (points.isEmpty) return MetricData(points, MinAvgMax.empty, unit);
  double mn = points.first.value, mx = points.first.value, sum = 0;
  for (final p in points) {
    if (p.value < mn) mn = p.value;
    if (p.value > mx) mx = p.value;
    sum += p.value;
  }
  return MetricData(
    points,
    MinAvgMax(
      min: mn,
      avg: sum / points.length,
      max: mx,
      count: points.length,
    ),
    unit,
  );
}

class MetricExplorer extends StatefulWidget {
  final List<MetricRef> metrics;
  final MetricRef? initial;

  const MetricExplorer({super.key, required this.metrics, this.initial});

  @override
  State<MetricExplorer> createState() => _MetricExplorerState();
}

class _MetricExplorerState extends State<MetricExplorer> {
  MetricRef? _metric;
  StatsRange _range = StatsRange.day;
  int _reload = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _metric = widget.initial ??
        (widget.metrics.isNotEmpty ? widget.metrics.first : null);
    // background recording continues while the page is open; keep the
    // graph in sync without any user action
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _customize() async {
    final metric = _metric;
    if (metric == null) return;
    final settings = context.read<SettingsProvider>();
    final updated =
        await showGraphCustomizeDialog(context, settings.graphPrefs(metric.id));
    if (updated != null) {
      await settings.setGraphPrefs(metric.id, updated);
      setState(() => _reload++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final metric = _metric;
    if (metric == null) {
      return const EmptyState(
        icon: Icons.query_stats,
        title: 'Nothing to graph yet',
        body: 'Select sensors on the Sensors tab or track apps on the Apps tab.',
      );
    }
    final prefs = settings.graphPrefs(metric.id);
    final future = Future<MetricData>(
        () => loadMetricData(settings, metric, _range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.metrics.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final m in widget.metrics)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(m.label),
                      selected: m == metric,
                      onSelected: (_) => setState(() => _metric = m),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<StatsRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in StatsRange.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) =>
                      setState(() => _range = s.first),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Customize this graph',
                onPressed: _customize,
              ),
            ],
          ),
        ),
        FutureBuilder<MetricData>(
          key: ValueKey('${_metric!.id}|$_range|$_reload|${prefs.hashCode}'),
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final d = snap.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MetricChart(
                    data: d.points,
                    prefs: prefs,
                    unit: d.unit,
                    formatTs: _fmtTs,
                  ),
                ),
                if (d.points.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmtTs(d.points.first.ts),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          _fmtTs(d.points.last.ts),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryChip(
                          'Min', d.summary.min, d.unit, Colors.lightBlueAccent),
                      _SummaryChip('Avg', d.summary.avg, d.unit,
                          Colors.amberAccent),
                      _SummaryChip(
                          'Max', d.summary.max, d.unit, Colors.redAccent),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _fmtTs(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int v) => v.toString().padLeft(2, '0');
    if (_range == StatsRange.day) return '${two(d.hour)}:${two(d.minute)}';
    return '${two(d.day)}.${two(d.month)}';
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _SummaryChip(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}

Future<GraphPrefs?> showGraphCustomizeDialog(
    BuildContext context, GraphPrefs initial) {
  return showDialog<GraphPrefs>(
    context: context,
    builder: (context) => _GraphCustomizeDialog(initial: initial),
  );
}

class _GraphCustomizeDialog extends StatefulWidget {
  final GraphPrefs initial;

  const _GraphCustomizeDialog({required this.initial});

  @override
  State<_GraphCustomizeDialog> createState() => _GraphCustomizeDialogState();
}

class _GraphCustomizeDialogState extends State<_GraphCustomizeDialog> {
  static const _colors = [
    0xFF4FC3F7,
    0xFF81C784,
    0xFFFFB74D,
    0xFFE57373,
    0xFFBA68C8,
    0xFFFFF176,
  ];

  late bool _isBar = widget.initial.isBar;
  late int _color = widget.initial.colorValue;
  late bool _grid = widget.initial.showGrid;
  late final TextEditingController _minY = TextEditingController(
      text: widget.initial.minY?.toString() ?? '');
  late final TextEditingController _maxY = TextEditingController(
      text: widget.initial.maxY?.toString() ?? '');

  @override
  void dispose() {
    _minY.dispose();
    _maxY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Graph style'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Line')),
                ButtonSegment(value: true, label: Text('Bars')),
              ],
              selected: {_isBar},
              onSelectionChanged: (s) => setState(() => _isBar = s.first),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = c),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                                width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show grid'),
              value: _grid,
              onChanged: (v) => setState(() => _grid = v),
            ),
            const SizedBox(height: 8),
            Text('Y axis range (empty = auto)',
                style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minY,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))
                    ],
                    decoration: const InputDecoration(labelText: 'Min'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxY,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))
                    ],
                    decoration: const InputDecoration(labelText: 'Max'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final minY = double.tryParse(_minY.text.trim());
            final maxY = double.tryParse(_maxY.text.trim());
            Navigator.pop(
              context,
              GraphPrefs(
                isBar: _isBar,
                colorValue: _color,
                showGrid: _grid,
                minY: minY,
                maxY: maxY,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
