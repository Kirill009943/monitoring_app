import 'package:flutter/services.dart';

import '../data/models.dart';

class ThermalApi {
  static const MethodChannel _ch = MethodChannel('monittoring/thermal');

  static Future<List<ThermalZone>> listZones() async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>('listZones');
      return (res ?? const [])
          .map((e) => ThermalZone.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<Map<String, double>> readZones(List<String> names) async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>('readZones', {'names': names});
      final out = <String, double>{};
      for (final e in res ?? const []) {
        final m = e as Map<dynamic, dynamic>;
        final name = m['name'] as String?;
        final temp = (m['tempC'] as num?)?.toDouble();
        if (name != null && temp != null) out[name] = temp;
      }
      return out;
    } catch (e) {
      throw Exception('native call failed: $e');
    }
  }

  static Future<int> thermalStatus() async {
    try {
      final res = await _ch.invokeMethod<int>('thermalStatus');
      return res ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static String thermalStatusLabel(int status) => switch (status) {
        0 => 'None',
        1 => 'Light',
        2 => 'Moderate',
        3 => 'Severe',
        4 => 'Critical',
        5 => 'Emergency',
        6 => 'Shutdown',
        _ => 'Unsupported',
      };
}
