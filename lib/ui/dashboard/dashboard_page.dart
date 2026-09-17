import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../native/apps_api.dart';
import '../../native/battery_api.dart';
import '../../native/monitor_api.dart';
import '../../native/thermal_api.dart';
import '../battery/battery_page.dart';
import '../common/help_sheet.dart';
import '../common/monitor_control.dart';
import '../common/widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  int _tick = 0;

  Map<String, double> _temps = {};
  BatteryInfo? _battery;
  bool _serviceRunning = false;
  Map<String, int> _usageToday = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final monitored = settings.monitoredSensors.toList();

    Map<String, double> temps = _temps;
    BatteryInfo? battery = _battery;
    bool running = _serviceRunning;
    Map<String, int> usage = _usageToday;

    if (monitored.isNotEmpty) {
      try {
        temps = await ThermalApi.readZones(monitored);
      } catch (_) {}
    } else {
      temps = {};
    }
    try {
      battery = await BatteryApi.getInfo();
    } catch (_) {}
    try {
      running = await MonitorApi.isMonitorRunning();
    } catch (_) {}
    if (settings.monitoringEnabled && !running) {
      // auto-heal: system may have killed the service since
      try {
        await MonitorApi.startMonitor();
        running = await MonitorApi.isMonitorRunning();
      } catch (_) {}
    }

    _tick++;
    if (_tick % 5 == 1 && settings.trackedApps.isNotEmpty) {
      try {
        final entries = await AppsApi.usageToday();
        usage = {
          for (final e in entries)
            if (settings.trackedApps.containsKey(e.packageName))
              e.packageName: e.fgSeconds,
        };
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _temps = temps;
      _battery = battery;
      _serviceRunning = running;
      _usageToday = usage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final useC = settings.useCelsius;
    final thresholds = settings.tempThresholds;
    final tracked = settings.trackedApps;
    final labels = settings.trackedAppLabels;

    final topApps = tracked.keys.toList()
      ..sort((a, b) =>
          (_usageToday[b] ?? 0).compareTo(_usageToday[a] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Monitor'),
        actions: const [HelpButton(pageId: 'dashboard')],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionCard(
              title: 'Background monitoring',
              trailing: Switch(
                value: settings.monitoringEnabled,
                onChanged: (v) => setMonitoring(context, v),
              ),
              child: Row(
                children: [
                  Icon(
                    _serviceRunning
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: _serviceRunning
                        ? Colors.greenAccent
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _serviceRunning
                          ? 'Recording every ${settings.pollIntervalSec} s · keeping ${settings.retentionDays} days'
                          : settings.monitoringEnabled
                              ? 'Starting…'
                              : 'Off — nothing is being recorded',
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Sensors',
              child: settings.monitoredSensors.isEmpty
                  ? const Text(
                      'No sensors selected. Open the Sensors tab and pick what to monitor.')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in settings.monitoredSensors)
                          _SensorChip(
                            name: name,
                            tempC: _temps[name],
                            threshold: thresholds[name],
                            useCelsius: useC,
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Battery',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BatteryPage()),
              ),
              child: _battery == null
                  ? const Text('Reading…')
                  : Row(
                      children: [
                        Icon(
                          _battery!.isCharging
                              ? Icons.battery_charging_full
                              : Icons.battery_std,
                          size: 40,
                          color: _battery!.isCharging
                              ? Colors.greenAccent
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_battery!.level} % · ${_battery!.statusLabel}',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${formatTemp(_battery!.tempC, useC)} · ${formatVoltage(_battery!.voltageMv)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'App time today',
              child: tracked.isEmpty
                  ? const Text(
                      'No apps tracked. Open the Apps tab to pick apps and set daily limits.')
                  : Column(
                      children: [
                        for (final pkg in topApps.take(5))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.android),
                            title: Text(labels[pkg] ?? pkg),
                            subtitle: (tracked[pkg] ?? 0) > 0
                                ? Text('limit ${formatMinutes(tracked[pkg]!)}')
                                : null,
                            trailing: Text(
                              formatSecondsCompact(_usageToday[pkg] ?? 0),
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorChip extends StatelessWidget {
  final String name;
  final double? tempC;
  final double? threshold;
  final bool useCelsius;

  const _SensorChip({
    required this.name,
    required this.tempC,
    required this.threshold,
    required this.useCelsius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hot = tempC != null && threshold != null && tempC! >= threshold!;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hot ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            tempC == null ? '—' : formatTemp(tempC!, useCelsius),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            threshold == null
                ? 'no limit'
                : 'limit ${formatTemp(threshold!, useCelsius)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
