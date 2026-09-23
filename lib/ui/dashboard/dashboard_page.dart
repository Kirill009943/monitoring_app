import 'dart:async';
import 'dart:convert';

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
  Timer? _healTimer;
  int _tick = 0;

  Map<String, double> _temps = {};
  BatteryInfo? _battery;
  MonitorStatus _status =
      const MonitorStatus(running: false, lastTickMs: 0, lastError: null);
  Map<String, int> _usageToday = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    // If monitoring is enabled but the system killed the service, restart it —
    // delayed so it never fights app startup, and re-armed every time this
    // page is created (tab switches dispose it).
    _healTimer = Timer(const Duration(seconds: 10), _healOnce);
  }

  Future<void> _healOnce() async {
    try {
      final settings = context.read<SettingsProvider>();
      if (!settings.monitoringEnabled) return;
      if (await MonitorApi.isMonitorRunning()) return;
      await MonitorApi.startMonitor();
      _refresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _healTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final monitored = settings.monitoredSensors.toList();

    Map<String, double> temps = _temps;
    BatteryInfo? battery = _battery;
    MonitorStatus status = _status;
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
      status = await MonitorApi.status();
    } catch (_) {}

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
      _status = status;
      _usageToday = usage;
    });
  }

  String _fmtTick(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
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
                    _status.running && _status.lastError == null
                        ? Icons.check_circle_outline
                        : _status.lastError != null
                            ? Icons.error_outline
                            : Icons.pause_circle_outline,
                    color: _status.lastError != null
                        ? Theme.of(context).colorScheme.error
                        : _status.running
                            ? Colors.greenAccent
                            : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !settings.monitoringEnabled
                          ? 'Off — nothing is being recorded'
                          : _status.lastError != null
                              ? 'Error: ${_status.lastError}'
                              : _status.running && _status.lastTickMs > 0
                                  ? 'Recording every ${settings.pollIntervalSec} s · last tick ${_fmtTick(_status.lastTickMs)}'
                                  : _status.running
                                      ? 'Service running, waiting for first tick…'
                                      : 'Starting…',
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
                            leading: _AppIcon(
                                base64Icon: settings.trackedAppIcons[pkg]),
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

class _AppIcon extends StatelessWidget {
  final String? base64Icon;

  const _AppIcon({this.base64Icon});

  @override
  Widget build(BuildContext context) {
    final b64 = base64Icon;
    if (b64 == null || b64.isEmpty) return const Icon(Icons.android);
    try {
      return Image.memory(
        base64Decode(b64),
        width: 28,
        height: 28,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.android),
      );
    } catch (_) {
      return const Icon(Icons.android);
    }
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
