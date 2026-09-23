import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(prefs);
  await settings.ensureSensorJsonSynced();
  runApp(
    ChangeNotifierProvider(
      create: (_) => settings,
      child: const PhoneMonitorApp(),
    ),
  );
}
