import 'package:flutter/material.dart';

class AppThemes {
  static const String light = 'light';
  static const String dark = 'dark';
  static const String amoled = 'amoled';
  static const String ocean = 'ocean';
  static const String forest = 'forest';

  static const Map<String, String> names = {
    light: 'Light',
    dark: 'Dark',
    amoled: 'AMOLED black',
    ocean: 'Ocean',
    forest: 'Forest',
  };

  static ThemeData byId(String id) {
    switch (id) {
      case light:
        return _base(Brightness.light, const Color(0xFF6750A4));
      case amoled:
        return _base(Brightness.dark, const Color(0xFF9E8CFF)).copyWith(
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          cardTheme: _cardTheme(Colors.black),
        );
      case ocean:
        return _base(Brightness.dark, Colors.lightBlueAccent);
      case forest:
        return _base(Brightness.dark, Colors.green);
      case dark:
      default:
        return _base(Brightness.dark, const Color(0xFF9E8CFF));
    }
  }

  static CardThemeData _cardTheme(Color? color) => CardThemeData(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );

  static ThemeData _base(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: _cardTheme(null),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
