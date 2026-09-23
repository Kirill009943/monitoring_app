import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../native/monitor_api.dart';

Future<void> setMonitoring(BuildContext context, bool on) async {
  final settings = context.read<SettingsProvider>();
  await settings.setMonitoringEnabled(on);
  try {
    if (on) {
      await MonitorApi.startMonitor();
    } else {
      await MonitorApi.stopMonitor();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not ${on ? 'start' : 'stop'} the service: $e')),
      );
    }
  }
}
