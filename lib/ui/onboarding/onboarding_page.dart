import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../native/apps_api.dart';
import '../../native/monitor_api.dart';
import '../../native/notify_api.dart';
import '../common/help_sheet.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;

  bool _notifGranted = false;
  bool _usageGranted = false;
  bool _batteryExempt = false;

  static const _pageCount = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStates();
  }

  Future<void> _refreshStates() async {
    final n = await NotifyApi.hasNotificationPermission();
    final u = await AppsApi.hasUsageAccess();
    final b = await MonitorApi.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notifGranted = n;
      _usageGranted = u;
      _batteryExempt = b;
    });
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<SettingsProvider>().setOnboardingDone(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        actions: const [HelpButton(pageId: 'onboarding')],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _PageBody(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Welcome to Phone Monitor',
                    body:
                        'Watch your phone\'s temperatures, battery and app screen time — with graphs, alerts and zero cloud. Everything is stored only on this device.',
                  ),
                  _PageBody(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    body:
                        'Needed so temperature and app-time alerts can reach you while the app is closed.',
                    state: _notifGranted ? 'Allowed' : 'Not allowed yet',
                    actionLabel:
                        _notifGranted ? null : 'Allow notifications',
                    onAction: () async {
                      await NotifyApi.requestNotificationPermission();
                      _refreshStates();
                    },
                  ),
                  _PageBody(
                    icon: Icons.apps_outlined,
                    title: 'Usage access',
                    body:
                        'A special Android permission that lets the app measure how long each app is on screen. In the list that opens, find Phone Monitor and enable it.',
                    state: _usageGranted ? 'Granted' : 'Not granted yet',
                    actionLabel:
                        _usageGranted ? null : 'Open usage access settings',
                    onAction: () async {
                      await AppsApi.openUsageAccessSettings();
                    },
                  ),
                  _PageBody(
                    icon: Icons.battery_saver,
                    title: 'Battery optimization',
                    body:
                        'Excluding Phone Monitor keeps background recording alive. Without it, Android may pause recording after a while.',
                    state: _batteryExempt ? 'Excluded' : 'Not excluded yet',
                    actionLabel:
                        _batteryExempt ? null : 'Exclude from optimization',
                    onAction: () async {
                      await MonitorApi.requestIgnoreBatteryOptimizations();
                      _refreshStates();
                    },
                  ),
                  _PageBody(
                    icon: Icons.check_circle_outline,
                    title: 'All set',
                    body:
                        'Pick sensors on the Sensors tab, track apps on the Apps tab, then turn on monitoring from the dashboard. Every screen has a ? button with help.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (_page < _pageCount - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                        _page == _pageCount - 1 ? 'Start' : 'Next'),
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

class _PageBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? state;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PageBody({
    required this.icon,
    required this.title,
    required this.body,
    this.state,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(body,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
          if (state != null) ...[
            const SizedBox(height: 16),
            Chip(label: Text(state!)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
