import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../native/thermal_api.dart';
import '../common/help_sheet.dart';
import '../common/widgets.dart';

class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  late Future<List<ThermalZone>> _zonesFuture;
  Timer? _timer;
  Map<String, double> _temps = {};
  int _thermalStatus = -1;

  @override
  void initState() {
    super.initState();
    _zonesFuture = _load();
  }

  Future<List<ThermalZone>> _load() async {
    final zones = await ThermalApi.listZones();
    await _refreshTemps(zones);
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 3), (_) => _refreshTemps(zones));
    return zones;
  }

  Future<void> _refreshTemps(List<ThermalZone> zones) async {
    try {
      final temps =
          await ThermalApi.readZones(zones.map((z) => z.name).toList());
      final status = await ThermalApi.thermalStatus();
      if (!mounted) return;
      setState(() {
        _temps = temps;
        _thermalStatus = status;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double? _tempOf(ThermalZone z) => _temps[z.name] ?? z.tempC;

  bool _isBatteryRelated(ThermalZone z) =>
      z.name == 'battery' || z.name.toLowerCase().contains('batt');

  List<ThermalZone> _applySortFilter(
      List<ThermalZone> zones, SettingsProvider settings) {
    var out = zones.where((z) {
      final t = _tempOf(z);
      if (settings.sensorHideZero && t != null && t <= 0) return false;
      if (settings.sensorHideHot && t != null && t >= 90) return false;
      return true;
    }).toList();
    switch (settings.sensorSort) {
      case 'temp':
        out.sort((a, b) {
          final ta = _tempOf(a), tb = _tempOf(b);
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      case 'name':
        out.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      default:
        out.sort((a, b) {
          final ba = _isBatteryRelated(a) ? 0 : 1;
          final bb = _isBatteryRelated(b) ? 0 : 1;
          if (ba != bb) return ba - bb;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return out;
  }

  Future<void> _editThreshold(
      BuildContext context, String zone, double? currentC) async {
    final settings = context.read<SettingsProvider>();
    final useC = settings.useCelsius;
    final controller = TextEditingController(
      text: currentC == null
          ? ''
          : displayTemp(currentC, useC).toStringAsFixed(0),
    );
    final saved = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limit for $zone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          decoration: InputDecoration(
            labelText: 'Alert temperature (${tempUnit(useC)})',
            hintText: 'empty = no alert',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim();
              if (raw.isEmpty) {
                Navigator.pop(context, -1.0);
                return;
              }
              final v = double.tryParse(raw);
              if (v == null) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    if (saved < 0) {
      await settings.setThreshold(zone, null);
      return;
    }
    final celsius = useC ? saved : (saved - 32) * 5 / 9;
    await settings.setThreshold(zone, celsius);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final useC = settings.useCelsius;
    final thresholds = settings.tempThresholds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal sensors'),
        actions: const [HelpButton(pageId: 'sensors')],
      ),
      body: FutureBuilder<List<ThermalZone>>(
        future: _zonesFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not read sensors',
              body: '${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final zones = _applySortFilter(snap.data!, settings);
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Sort sensors',
                      initialValue: settings.sensorSort,
                      onSelected: settings.setSensorSort,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'default',
                            child: Text('Battery-related first')),
                        PopupMenuItem(
                            value: 'temp',
                            child: Text('Hottest first')),
                        PopupMenuItem(
                            value: 'name', child: Text('Name (A–Z)')),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 18),
                        label: Text(switch (settings.sensorSort) {
                          'temp' => 'Hottest first',
                          'name' => 'Name (A–Z)',
                          _ => 'Battery first',
                        }),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Hide 0°'),
                      selected: settings.sensorHideZero,
                      onSelected: settings.setSensorHideZero,
                    ),
                    FilterChip(
                      label: const Text('Hide 90°+'),
                      selected: settings.sensorHideHot,
                      onSelected: settings.setSensorHideHot,
                    ),
                    if (_thermalStatus >= 0)
                      Chip(
                        avatar: const Icon(Icons.device_thermostat),
                        label: Text(
                            'Status: ${ThermalApi.thermalStatusLabel(_thermalStatus)}'),
                      ),
                  ],
                ),
              ),
              for (final z in zones)
                ListTile(
                  leading: Icon(
                    z.readable ? Icons.thermostat : Icons.thermostat_outlined,
                    color: z.readable
                        ? null
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(z.name),
                  subtitle: !z.readable
                      ? const Text('unavailable on this device')
                      : Text(
                          thresholds.containsKey(z.name)
                              ? 'limit ${formatTemp(thresholds[z.name]!, useC)}'
                              : 'no limit',
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _temps[z.name] == null
                            ? (z.tempC == null
                                ? '—'
                                : formatTemp(z.tempC!, useC))
                            : formatTemp(_temps[z.name]!, useC),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Switch(
                        value: settings.monitoredSensors.contains(z.name),
                        onChanged: z.readable
                            ? (v) => settings.setSensorMonitored(z.name, v)
                            : null,
                      ),
                    ],
                  ),
                  onTap: z.readable
                      ? () => _editThreshold(
                          context, z.name, thresholds[z.name])
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
