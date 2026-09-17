import 'package:flutter/services.dart';

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
