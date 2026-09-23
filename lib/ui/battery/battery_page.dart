import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/battery_health.dart';
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
          const _BatteryHealthCard(),
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

class _BatteryHealthCard extends StatefulWidget {
  const _BatteryHealthCard();

  @override
  State<_BatteryHealthCard> createState() => _BatteryHealthCardState();
}

class _BatteryHealthCardState extends State<_BatteryHealthCard> {
  Future<BatteryHealthReport>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final designMah = context.watch<SettingsProvider>().batteryDesignMah;
    _future = analyzeBatteryHealth(designMah: designMah);
  }

  Future<void> _editDesignCapacity() async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(
        text: settings.batteryDesignMah > 0
            ? settings.batteryDesignMah.toString()
            : '');
    final saved = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Design battery capacity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'mAh',
            hintText: 'e.g. 5000 — see your phone specs',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) await settings.setBatteryDesignMah(saved);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final designMah = settings.batteryDesignMah;
    return SectionCard(
      title: 'Battery health (estimate)',
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Set design capacity',
        onPressed: _editDesignCapacity,
      ),
      child: FutureBuilder<BatteryHealthReport>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final r = snap.data!;
          final last = r.sessions.isNotEmpty ? r.sessions.first : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, 'Design capacity',
                  designMah > 0 ? '$designMah mAh' : 'tap ✎ to set'),
              if (r.bestEstimateMah != null)
                _line(context, 'Estimated full charge',
                    '~${r.bestEstimateMah!.round()} mAh'),
              if (r.healthPercent != null)
                _line(
                  context,
                  'Health',
                  '${r.healthPercent!.clamp(0, 130).toStringAsFixed(0)} %',
                  highlight: true,
                ),
              if (last != null)
                _line(context, 'Last charge session',
                    '+${last.pctGain} % · ${last.mahCharged.round()} mAh'),
              if (!r.hasData)
                Text(
                  'No recorded charge sessions yet. Keep monitoring on and charge the phone — after a session of 15 % or more, capacity is estimated from mAh charged vs % gained.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else if (r.bestEstimateMah == null)
                Text(
                  '${r.sessions.length} session(s) recorded, but all under 15 % — one longer charge is needed for an estimate.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          Text(
            value,
            style: highlight
                ? Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)
                : Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

