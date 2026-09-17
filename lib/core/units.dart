double displayTemp(double celsius, bool useCelsius) =>
    useCelsius ? celsius : celsius * 9 / 5 + 32;

String tempUnit(bool useCelsius) => useCelsius ? '°C' : '°F';

String formatTemp(double celsius, bool useCelsius) =>
    '${displayTemp(celsius, useCelsius).toStringAsFixed(1)} ${tempUnit(useCelsius)}';

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String formatSecondsCompact(int seconds) {
  if (seconds < 60) return '${seconds}s';
  return formatMinutes((seconds / 60).round());
}

String formatMah(int microAmps) {
  final ma = microAmps / 1000.0;
  return '${ma.toStringAsFixed(0)} mA';
}

String formatVoltage(int millivolts) =>
    '${(millivolts / 1000.0).toStringAsFixed(2)} V';
