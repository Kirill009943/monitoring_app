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
  } catch (_) {
    // service state is polled by the UI; nothing else to do here
  }
}
