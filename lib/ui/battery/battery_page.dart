import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../native/battery_api.dart';
import '../common/help_sheet.dart';
import '../common/widgets.dart';
import '../stats/metric_explorer.dart';

class BatteryPage extends StatefulWidget {
  const BatteryPage({super.key});

  @override
  State<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<BatteryPage> {
  Timer? _timer;
  BatteryInfo? _info;

  static const _metrics = [
    MetricRef('battery', 'level', 'Level'),
    MetricRef('battery', 'temp', 'Temperature'),
    MetricRef('battery', 'voltageMv', 'Voltage'),
    MetricRef('battery', 'currentUa', 'Current'),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final info = await BatteryApi.getInfo();
      if (mounted) setState(() => _info = info);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final info = _info;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery'),
        actions: const [HelpButton(pageId: 'battery')],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            title: 'Current status',
            child: info == null
                ? const Text('Reading…')
                : Column(
                    children: [
                      _row(context, 'Level', '${info.level} %'),
                      _row(context, 'Status', info.statusLabel),
                      _row(context, 'Temperature',
                          formatTemp(info.tempC, settings.useCelsius)),
                      if (info.voltageMv > 0)
                        _row(context, 'Voltage',
                            formatVoltage(info.voltageMv)),
                      if (info.currentNowUa != 0)
                        _row(
                            context,
                            info.isCharging
                                ? 'Charging current'
                                : 'Discharge current',
                            formatMah(info.currentNowUa.abs())),
                      _row(context, 'Health', info.healthLabel),
                      if (info.technology.isNotEmpty)
                        _row(context, 'Technology', info.technology),
                    ],
                  ),
          ),
          SectionCard(
            title: 'History',
            child: const MetricExplorer(
              metrics: _metrics,
              initial: MetricRef('battery', 'level', 'Level'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
