import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../native/monitor_api.dart';
import '../../native/notify_api.dart';
import '../common/help_sheet.dart';
import '../common/monitor_control.dart';
import '../common/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [HelpButton(pageId: 'settings')],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(AppThemes.names[settings.themeId] ??
                settings.themeId),
            onTap: () => _pickTheme(context, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.thermostat),
            title: const Text('Temperature in °C'),
            subtitle: const Text('off = Fahrenheit'),
            value: settings.useCelsius,
            onChanged: settings.setUseCelsius,
          ),
          _header(context, 'Background recording'),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: const Text('Monitoring'),
            subtitle: const Text('record selected data in the background'),
            value: settings.monitoringEnabled,
            onChanged: (v) => setMonitoring(context, v),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Poll interval'),
            subtitle: const Text('shorter = smoother graphs, more battery'),
            trailing: DropdownButton<int>(
              value: settings.pollIntervalSec,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in SettingsProvider.pollOptions)
                  DropdownMenuItem(value: s, child: Text('$s s')),
              ],
              onChanged: (v) {
                if (v != null) settings.setPollIntervalSec(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Keep data for'),
            subtitle: const Text('older samples are deleted permanently'),
            trailing: DropdownButton<int>(
              value: settings.retentionDays,
              underline: const SizedBox.shrink(),
              items: [
                for (final d in SettingsProvider.retentionOptions)
                  DropdownMenuItem(
                      value: d, child: Text('$d day${d == 1 ? '' : 's'}')),
              ],
              onChanged: (v) {
                if (v != null) settings.setRetentionDays(v);
              },
            ),
          ),
          const _BatteryOptimizationTile(),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: const Text('System app settings'),
            subtitle: const Text(
                'Xiaomi/MIUI: enable Autostart and set Battery saver to "No restrictions"'),
            onTap: () => MonitorApi.openAppSettings(),
          ),
          _header(context, 'Notifications'),
          const _NotifStyleEditor(kind: 'temp', title: 'Temperature alerts'),
          const _NotifStyleEditor(kind: 'app', title: 'App time alerts'),
          _header(context, 'General'),
          ListTile(
            leading: const Icon(Icons.replay),
            title: const Text('Replay setup guide'),
            subtitle: const Text('permissions and first-run help'),
            onTap: () => settings.setOnboardingDone(false),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('100% local'),
            subtitle: Text(
                'No account, no internet permission, no analytics. Data never leaves this phone.'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary),
        ),
      );

  Future<void> _pickTheme(BuildContext context, SettingsProvider settings) {
    return showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<String>(
            groupValue: settings.themeId,
            onChanged: (v) {
              if (v != null) settings.setThemeId(v);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in AppThemes.names.entries)
                  RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryOptimizationTile extends StatelessWidget {
  const _BatteryOptimizationTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: MonitorApi.isIgnoringBatteryOptimizations(),
      builder: (context, snap) {
        final exempt = snap.data ?? false;
        return ListTile(
          leading: Icon(exempt
              ? Icons.battery_saver
              : Icons.battery_alert),
          title: const Text('Battery optimization'),
          subtitle: Text(exempt
              ? 'Excluded — monitoring can run reliably'
              : 'Tap to exclude the app so Android does not stop recording'),
          onTap: exempt
              ? null
              : () async {
                  await MonitorApi.requestIgnoreBatteryOptimizations();
                  (context as Element).markNeedsBuild();
                },
        );
      },
    );
  }
}

class _NotifStyleEditor extends StatelessWidget {
  final String kind;
  final String title;

  const _NotifStyleEditor({required this.kind, required this.title});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final enabled = settings.notifEnabled(kind);
    return SectionCard(
      title: title,
      trailing: Switch(
        value: enabled,
        onChanged: (v) => settings.setNotifEnabled(kind, v),
      ),
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound'),
            value: settings.notifSound(kind),
            onChanged:
                enabled ? (v) => settings.setNotifSound(kind, v) : null,
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibration'),
            value: settings.notifVibrate(kind),
            onChanged:
                enabled ? (v) => settings.setNotifVibrate(kind, v) : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Importance'),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 2, label: Text('Low')),
                    ButtonSegment(value: 3, label: Text('Med')),
                    ButtonSegment(value: 4, label: Text('High')),
                    ButtonSegment(value: 5, label: Text('Max')),
                  ],
                  selected: {settings.notifImportance(kind)},
                  onSelectionChanged: enabled
                      ? (s) => settings.setNotifImportance(kind, s.first)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Send test'),
              onPressed: enabled
                  ? () async {
                      final ok = await NotifyApi.sendTest(kind);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Test notification sent'
                              : 'Could not send — check notification permission'),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
