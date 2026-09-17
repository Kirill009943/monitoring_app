import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../native/apps_api.dart';
import '../common/help_sheet.dart';
import '../common/widgets.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> with WidgetsBindingObserver {
  late Future<List<InstalledApp>> _appsFuture;
  Map<String, int> _usageToday = {};
  bool _hasAccess = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appsFuture = AppsApi.listInstalled();
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    final has = await AppsApi.hasUsageAccess();
    Map<String, int> usage = {};
    if (has) {
      try {
        final entries = await AppsApi.usageToday();
        usage = {for (final e in entries) e.packageName: e.fgSeconds};
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _hasAccess = has;
      _usageToday = usage;
    });
  }

  Future<void> _editLimit(
      BuildContext context, InstalledApp app, int current) async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(
        text: current == 0 ? '' : current.toString());
    final saved = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Daily limit for ${app.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Minutes per day',
            hintText: 'empty or 0 = no alert',
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
    if (saved != null) await settings.setAppLimit(app.packageName, saved);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tracked = settings.trackedApps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App usage'),
        actions: const [HelpButton(pageId: 'apps')],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search apps',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!_hasAccess)
            Card(
              margin: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usage access needed',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Android requires a special permission to measure app screen time. Everything stays on your phone.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open system settings'),
                      onPressed: () => AppsApi.openUsageAccessSettings(),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<InstalledApp>>(
              future: _appsFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load apps',
                    body: '${snap.error}',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var apps = snap.data!;
                if (_search.isNotEmpty) {
                  apps = apps
                      .where((a) =>
                          a.label.toLowerCase().contains(_search) ||
                          a.packageName.toLowerCase().contains(_search))
                      .toList();
                }
                apps = [...apps]..sort((a, b) {
                    final ta = tracked.containsKey(a.packageName) ? 0 : 1;
                    final tb = tracked.containsKey(b.packageName) ? 0 : 1;
                    if (ta != tb) return ta - tb;
                    return (_usageToday[b.packageName] ?? 0)
                        .compareTo(_usageToday[a.packageName] ?? 0);
                  });
                if (apps.isEmpty) {
                  return const EmptyState(
                      icon: Icons.search_off, title: 'No apps found');
                }
                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final isTracked = tracked.containsKey(app.packageName);
                    final limit = tracked[app.packageName] ?? 0;
                    final used = _usageToday[app.packageName] ?? 0;
                    final icon = app.iconBytes;
                    return ListTile(
                      leading: icon == null
                          ? const Icon(Icons.android)
                          : Image.memory(icon,
                              width: 36, height: 36,
                              gaplessPlayback: true),
                      title: Text(app.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          if (_hasAccess)
                            'today ${formatSecondsCompact(used)}',
                          if (isTracked && limit > 0)
                            'limit ${formatMinutes(limit)}',
                        ].join(' · '),
                      ),
                      trailing: Switch(
                        value: isTracked,
                        onChanged: (v) => settings.setAppTracked(
                            app.packageName, v,
                            label: app.label),
                      ),
                      onTap: isTracked
                          ? () => _editLimit(context, app, limit)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
