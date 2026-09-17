import 'package:flutter/services.dart';

import '../data/models.dart';

class BatteryApi {
  static const MethodChannel _ch = MethodChannel('monittoring/battery');

  static Future<BatteryInfo> getInfo() async {
    try {
      final res = await _ch.invokeMethod<Map<dynamic, dynamic>>('getInfo');
      if (res == null) throw Exception('empty response');
      return BatteryInfo.fromMap(res);
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }
}
