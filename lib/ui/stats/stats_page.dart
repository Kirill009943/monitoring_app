import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../data/models.dart';
import '../common/help_sheet.dart';
import 'metric_explorer.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final labels = settings.trackedAppLabels;

    final metrics = <MetricRef>[
      for (final s in settings.monitoredSensors) MetricRef('thermal', s, s),
      const MetricRef('battery', 'level', 'Battery level'),
      const MetricRef('battery', 'temp', 'Battery temp'),
      const MetricRef('battery', 'voltageMv', 'Battery voltage'),
      const MetricRef('battery', 'currentUa', 'Charge current'),
      for (final pkg in settings.trackedApps.keys)
        MetricRef('usage', pkg, labels[pkg] ?? pkg),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: const [HelpButton(pageId: 'stats')],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          MetricExplorer(metrics: metrics),
        ],
      ),
    );
  }
}
