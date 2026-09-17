import 'dart:convert';
import 'dart:typed_data';

class ThermalZone {
  final String name;
  final String path;
  final double? tempC;
  final bool readable;

  const ThermalZone({
    required this.name,
    required this.path,
    required this.tempC,
    required this.readable,
  });

  factory ThermalZone.fromMap(Map<dynamic, dynamic> m) => ThermalZone(
        name: m['name'] as String? ?? '',
        path: m['path'] as String? ?? '',
        tempC: (m['tempC'] as num?)?.toDouble(),
        readable: m['readable'] as bool? ?? false,
      );
}

class BatteryInfo {
  final int level;
  final int status;
  final int plugged;
  final int health;
  final int voltageMv;
  final double tempC;
  final int currentNowUa;
  final int chargeCounterUah;
  final String technology;

  const BatteryInfo({
    required this.level,
    required this.status,
    required this.plugged,
    required this.health,
    required this.voltageMv,
    required this.tempC,
    required this.currentNowUa,
    required this.chargeCounterUah,
    required this.technology,
  });

  factory BatteryInfo.fromMap(Map<dynamic, dynamic> m) => BatteryInfo(
        level: (m['level'] as num?)?.toInt() ?? -1,
        status: (m['status'] as num?)?.toInt() ?? 1,
        plugged: (m['plugged'] as num?)?.toInt() ?? 0,
        health: (m['health'] as num?)?.toInt() ?? 1,
        voltageMv: (m['voltageMv'] as num?)?.toInt() ?? -1,
        tempC: (m['tempC'] as num?)?.toDouble() ?? 0,
        currentNowUa: (m['currentNowUa'] as num?)?.toInt() ?? 0,
        chargeCounterUah: (m['chargeCounterUah'] as num?)?.toInt() ?? 0,
        technology: m['technology'] as String? ?? '',
      );

  bool get isCharging => status == 2 || status == 5;

  String get statusLabel => switch (status) {
        2 => 'Charging',
        3 => 'Discharging',
        4 => 'Not charging',
        5 => 'Full',
        _ => 'Unknown',
      };

  String get healthLabel => switch (health) {
        2 => 'Good',
        3 => 'Overheat',
        4 => 'Dead',
        5 => 'Over voltage',
        6 => 'Failure',
        7 => 'Cold',
        _ => 'Unknown',
      };
}

class InstalledApp {
  final String packageName;
  final String label;
  final String iconBase64;

  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.iconBase64,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) => InstalledApp(
        packageName: m['package'] as String? ?? '',
        label: m['label'] as String? ?? '',
        iconBase64: m['icon'] as String? ?? '',
      );

  Uint8List? get iconBytes {
    if (iconBase64.isEmpty) return null;
    try {
      return base64Decode(iconBase64);
    } catch (_) {
      return null;
    }
  }
}

class UsageEntry {
  final String packageName;
  final int fgSeconds;
  final int lastUsedMs;

  const UsageEntry({
    required this.packageName,
    required this.fgSeconds,
    required this.lastUsedMs,
  });

  factory UsageEntry.fromMap(Map<dynamic, dynamic> m) => UsageEntry(
        packageName: m['package'] as String? ?? '',
        fgSeconds: (m['fgSeconds'] as num?)?.toInt() ?? 0,
        lastUsedMs: (m['lastUsed'] as num?)?.toInt() ?? 0,
      );
}

class TimeValue {
  final int ts;
  final double value;
  const TimeValue(this.ts, this.value);
}

class MetricRef {
  final String kind;
  final String key;
  final String label;

  const MetricRef(this.kind, this.key, this.label);

  String get id => '$kind|$key';

  @override
  bool operator ==(Object other) =>
      other is MetricRef && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);
}

class MinAvgMax {
  final double min;
  final double avg;
  final double max;
  final int count;

  const MinAvgMax({
    required this.min,
    required this.avg,
    required this.max,
    required this.count,
  });

  static const empty = MinAvgMax(min: 0, avg: 0, max: 0, count: 0);
}
