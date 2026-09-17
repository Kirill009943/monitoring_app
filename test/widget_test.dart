import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monittoring_app/app.dart';
import 'package:monittoring_app/core/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(String name, Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(MethodChannel(name), handler);
  }

  mock('monittoring/thermal', (call) async => switch (call.method) {
        'listZones' || 'readZones' => <dynamic>[],
        'thermalStatus' => -1,
        _ => null,
      });
  mock('monittoring/battery', (call) async => {
        'level': 50,
        'status': 3,
        'plugged': 0,
        'health': 2,
        'voltageMv': 4000,
        'tempC': 30.0,
        'currentNowUa': 0,
        'technology': 'Li-ion',
      });
  mock('monittoring/apps', (call) async => switch (call.method) {
        'listInstalled' || 'usageToday' || 'usageRange' => <dynamic>[],
        _ => false,
      });
  mock('monittoring/monitor', (call) async => false);
  mock('monittoring/notify', (call) async => true);
}

Future<void> _pumpApp(WidgetTester tester, SharedPreferences prefs) {
  return tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(prefs),
      child: const PhoneMonitorApp(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_mockChannels);

  testWidgets('first run shows onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpApp(tester, prefs);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Phone Monitor'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('after onboarding home shell shows five tabs', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    await _pumpApp(tester, prefs);
    await tester.pump();
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Phone Monitor'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('theme id from settings is applied', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_id': 'amoled'});
    final prefs = await SharedPreferences.getInstance();
    await _pumpApp(tester, prefs);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, Colors.black);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
