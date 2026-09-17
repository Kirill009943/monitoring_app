import 'package:flutter/services.dart';

class NotifyApi {
  static const MethodChannel _ch = MethodChannel('monittoring/notify');

  static Future<bool> sendTest(String kind) async {
    try {
      return await _ch.invokeMethod<bool>('sendTest', {'kind': kind}) ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> refreshChannels() async {
    try {
      return await _ch.invokeMethod<bool>('refreshChannels') ?? false;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<bool> hasNotificationPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasNotificationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
