import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/settings.dart';
import 'core/theme.dart';
import 'ui/apps/apps_page.dart';
import 'ui/dashboard/dashboard_page.dart';
import 'ui/onboarding/onboarding_page.dart';
import 'ui/sensors/sensors_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/stats/stats_page.dart';

class PhoneMonitorApp extends StatelessWidget {
  const PhoneMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Phone Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.byId(settings.themeId),
      home: settings.onboardingDone
          ? const HomeShell()
          : const OnboardingPage(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    SensorsPage(),
    AppsPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
            tooltip: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon: Icon(Icons.thermostat),
            label: 'Sensors',
            tooltip: 'Thermal sensors',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
            tooltip: 'App usage time',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Stats',
            tooltip: 'Statistics and graphs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}
