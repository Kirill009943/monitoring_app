import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native/notify_api.dart';

class GraphPrefs {
  final bool isBar;
  final int colorValue;
  final bool showGrid;
  final double? minY;
  final double? maxY;

  const GraphPrefs({
    this.isBar = false,
    this.colorValue = 0xFF4FC3F7,
    this.showGrid = true,
    this.minY,
    this.maxY,
  });

  GraphPrefs copyWith({
    bool? isBar,
    int? colorValue,
    bool? showGrid,
    double? Function()? minY,
    double? Function()? maxY,
  }) =>
      GraphPrefs(
        isBar: isBar ?? this.isBar,
        colorValue: colorValue ?? this.colorValue,
        showGrid: showGrid ?? this.showGrid,
        minY: minY != null ? minY() : this.minY,
        maxY: maxY != null ? maxY() : this.maxY,
      );

  factory GraphPrefs.fromJson(Map<String, dynamic> j) => GraphPrefs(
        isBar: j['isBar'] == true,
        colorValue: (j['color'] as num?)?.toInt() ?? 0xFF4FC3F7,
        showGrid: j['grid'] != false,
        minY: (j['minY'] as num?)?.toDouble(),
        maxY: (j['maxY'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'isBar': isBar,
        'color': colorValue,
        'grid': showGrid,
        if (minY != null) 'minY': minY,
        if (maxY != null) 'maxY': maxY,
      };
}

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsProvider(this._prefs);

  static const pollOptions = [15, 30, 60, 120, 300, 600];
  static const retentionOptions = [1, 3, 7, 30, 90];

  bool get monitoringEnabled => _prefs.getBool('monitoring_enabled') ?? false;
  Future<void> setMonitoringEnabled(bool v) => _set('monitoring_enabled', v);

  int get pollIntervalSec => _prefs.getInt('poll_interval_sec') ?? 60;
  Future<void> setPollIntervalSec(int v) => _set('poll_interval_sec', v);

  int get retentionDays => _prefs.getInt('retention_days') ?? 7;
  Future<void> setRetentionDays(int v) => _set('retention_days', v);

  bool get useCelsius => _prefs.getBool('units_celsius') ?? true;
  Future<void> setUseCelsius(bool v) => _set('units_celsius', v);

  String get themeId => _prefs.getString('theme_id') ?? 'dark';
  Future<void> setThemeId(String v) => _set('theme_id', v);

  bool get onboardingDone => _prefs.getBool('onboarding_done') ?? false;
  Future<void> setOnboardingDone(bool v) => _set('onboarding_done', v);

  int get batteryDesignMah => _prefs.getInt('battery_design_mah') ?? 0;
  Future<void> setBatteryDesignMah(int v) => _set('battery_design_mah', v);

  String get sensorSort => _prefs.getString('sensor_sort') ?? 'default';
  Future<void> setSensorSort(String v) => _set('sensor_sort', v);

  bool get sensorHideZero => _prefs.getBool('sensor_hide_zero') ?? false;
  Future<void> setSensorHideZero(bool v) => _set('sensor_hide_zero', v);

  bool get sensorHideHot => _prefs.getBool('sensor_hide_hot') ?? false;
  Future<void> setSensorHideHot(bool v) => _set('sensor_hide_hot', v);

  Set<String> get monitoredSensors =>
      (_prefs.getStringList('monitored_sensors') ?? const []).toSet();

  Future<void> setSensorMonitored(String zone, bool monitored) async {
    final set = monitoredSensors;
    if (monitored) {
      set.add(zone);
    } else {
      set.remove(zone);
    }
    final list = set.toList()..sort();
    await _prefs.setStringList('monitored_sensors', list);
    // the service reads this JSON form — the plugin's native list encoding
    // is not readable via SharedPreferences.getStringSet on all versions
    await _prefs.setString('monitored_sensors_json', jsonEncode(list));
    notifyListeners();
  }

  Future<void> ensureSensorJsonSynced() async {
    if (_prefs.getString('monitored_sensors_json') == null) {
      final list = monitoredSensors.toList()..sort();
      await _prefs.setString('monitored_sensors_json', jsonEncode(list));
    }
  }

  Map<String, double> get tempThresholds {
    final raw = _prefs.getString('temp_thresholds');
    if (raw == null || raw.isEmpty) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setThreshold(String zone, double? celsius) async {
    final map = tempThresholds;
    if (celsius == null) {
      map.remove(zone);
    } else {
      map[zone] = celsius;
    }
    await _set('temp_thresholds', jsonEncode(map));
  }

  Map<String, int> get trackedApps {
    final raw = _prefs.getString('tracked_apps');
    if (raw == null || raw.isEmpty) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Map<String, String> get trackedAppLabels {
    final raw = _prefs.getString('tracked_app_labels');
    if (raw == null || raw.isEmpty) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Map<String, String> get trackedAppIcons {
    final raw = _prefs.getString('tracked_app_icons');
    if (raw == null || raw.isEmpty) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveTrackedApps(Map<String, int> map) =>
      _set('tracked_apps', jsonEncode(map));

  Future<void> setAppTracked(String pkg, bool tracked,
      {String? label, String? iconBase64}) {
    final map = trackedApps;
    final labels = trackedAppLabels;
    final icons = trackedAppIcons;
    if (tracked) {
      map.putIfAbsent(pkg, () => 0);
      if (label != null) labels[pkg] = label;
      if (iconBase64 != null) icons[pkg] = iconBase64;
    } else {
      map.remove(pkg);
      labels.remove(pkg);
      icons.remove(pkg);
    }
    _prefs.setString('tracked_app_labels', jsonEncode(labels));
    _prefs.setString('tracked_app_icons', jsonEncode(icons));
    return _saveTrackedApps(map);
  }

  Future<void> setAppLimit(String pkg, int minutes) {
    final map = trackedApps;
    if (map.containsKey(pkg)) {
      map[pkg] = minutes;
      return _saveTrackedApps(map);
    }
    return Future.value();
  }

  bool notifEnabled(String kind) => _prefs.getBool('notif_${kind}_enabled') ?? true;
  bool notifSound(String kind) => _prefs.getBool('notif_${kind}_sound') ?? true;
  bool notifVibrate(String kind) => _prefs.getBool('notif_${kind}_vibrate') ?? true;
  int notifImportance(String kind) => _prefs.getInt('notif_${kind}_importance') ?? 4;

  Future<void> setNotifEnabled(String kind, bool v) => _setNotif(kind, 'enabled', v);
  Future<void> setNotifSound(String kind, bool v) => _setNotif(kind, 'sound', v);
  Future<void> setNotifVibrate(String kind, bool v) => _setNotif(kind, 'vibrate', v);
  Future<void> setNotifImportance(String kind, int v) =>
      _setNotif(kind, 'importance', v);

  Future<void> _setNotif(String kind, String field, Object value) async {
    final key = 'notif_${kind}_$field';
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    }
    notifyListeners();
    NotifyApi.refreshChannels().catchError((_) => false);
  }

  GraphPrefs graphPrefs(String metricId) {
    final raw = _prefs.getString('graph_$metricId');
    if (raw == null || raw.isEmpty) return const GraphPrefs();
    try {
      return GraphPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GraphPrefs();
    }
  }

  Future<void> setGraphPrefs(String metricId, GraphPrefs p) =>
      _set('graph_$metricId', jsonEncode(p.toJson()));

  Future<void> _set(String key, Object value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
    notifyListeners();
  }
}
