import 'package:flutter/services.dart';

import '../data/models.dart';

class AppsApi {
  static const MethodChannel _ch = MethodChannel('monittoring/apps');

  static Future<List<InstalledApp>> listInstalled() async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>('listInstalled');
      return (res ?? const [])
          .map((e) => InstalledApp.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> hasUsageAccess() async {
    try {
      return await _ch.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openUsageAccessSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openUsageAccessSettings') ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<List<UsageEntry>> usageToday() async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>('usageToday');
      return (res ?? const [])
          .map((e) => UsageEntry.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<List<UsageEntry>> usageRange(int startMs, int endMs) async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>(
          'usageRange', {'startMs': startMs, 'endMs': endMs});
      return (res ?? const [])
          .map((e) => UsageEntry.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }
}
