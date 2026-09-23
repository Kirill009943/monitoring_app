import 'package:flutter/services.dart';

class MonitorStatus {
  final bool running;
  final int lastTickMs;
  final String? lastError;

  const MonitorStatus({
    required this.running,
    required this.lastTickMs,
    required this.lastError,
  });
}

class MonitorApi {
  static const MethodChannel _ch = MethodChannel('monittoring/monitor');

  static Future<bool> startMonitor() async {
    try {
      return await _ch.invokeMethod<bool>('startMonitor') ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> stopMonitor() async {
    try {
      return await _ch.invokeMethod<bool>('stopMonitor') ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> isMonitorRunning() async {
    try {
      return await _ch.invokeMethod<bool>('isMonitorRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<MonitorStatus> status() async {
    try {
      final res = await _ch.invokeMethod<Map<dynamic, dynamic>>('monitorStatus');
      return MonitorStatus(
        running: res?['running'] as bool? ?? false,
        lastTickMs: (res?['lastTickMs'] as num?)?.toInt() ?? 0,
        lastError: res?['lastError'] as String?,
      );
    } catch (_) {
      return const MonitorStatus(
          running: false, lastTickMs: 0, lastError: null);
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _ch.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _ch
              .invokeMethod<bool>('requestIgnoreBatteryOptimizations') ??
          false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }
}
