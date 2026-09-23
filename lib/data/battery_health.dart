import 'models.dart';
import 'stats_repo.dart';

class ChargeSession {
  final int startMs;
  final int endMs;
  final int levelStart;
  final int levelEnd;
  final double mahCharged;

  const ChargeSession({
    required this.startMs,
    required this.endMs,
    required this.levelStart,
    required this.levelEnd,
    required this.mahCharged,
  });

  int get pctGain => levelEnd - levelStart;

  double? get estimatedFullCapacityMah =>
      pctGain >= 15 && mahCharged > 0 ? mahCharged / pctGain * 100 : null;
}

class BatteryHealthReport {
  final List<ChargeSession> sessions;
  final double? bestEstimateMah;
  final double? healthPercent;

  const BatteryHealthReport({
    required this.sessions,
    required this.bestEstimateMah,
    required this.healthPercent,
  });

  bool get hasData => sessions.isNotEmpty;
}

Future<BatteryHealthReport> analyzeBatteryHealth({
  required int designMah,
  int hoursBack = 72,
}) async {
  final repo = StatsRepo();
  final now = DateTime.now().millisecondsSinceEpoch;
  final start = now - hoursBack * 3600000;

  final charging = await repo.series(
      kind: 'battery', key: 'charging', startMs: start, endMs: now);
  final levels = await repo.series(
      kind: 'battery', key: 'level', startMs: start, endMs: now);
  final counters = await repo.series(
      kind: 'battery', key: 'chargeUah', startMs: start, endMs: now);

  final sessions = <ChargeSession>[];
  if (charging.isNotEmpty && counters.isNotEmpty) {
    const gapMs = 3 * 60000;
    int segStart = -1;
    int lastTs = -1;
    for (var i = 0; i < charging.length; i++) {
      final c = charging[i];
      final on = c.value >= 0.5;
      if (on && segStart < 0) {
        segStart = c.ts;
      } else if (on && c.ts - lastTs > gapMs) {
        _closeSession(sessions, segStart, lastTs, levels, counters);
        segStart = c.ts;
      } else if (!on && segStart >= 0) {
        _closeSession(sessions, segStart, lastTs, levels, counters);
        segStart = -1;
      }
      lastTs = c.ts;
    }
    if (segStart >= 0) {
      _closeSession(sessions, segStart, lastTs, levels, counters);
    }
  }

  sessions.sort((a, b) => b.startMs.compareTo(a.startMs));

  final estimates = sessions
      .map((s) => s.estimatedFullCapacityMah)
      .whereType<double>()
      .toList();
  double? best;
  if (estimates.isNotEmpty) {
    estimates.sort();
    best = estimates[estimates.length ~/ 2];
  }

  final health =
      (best != null && designMah > 0) ? best / designMah * 100 : null;
  return BatteryHealthReport(
    sessions: sessions,
    bestEstimateMah: best,
    healthPercent: health,
  );
}

void _closeSession(
  List<ChargeSession> out,
  int startMs,
  int endMs,
  List<TimeValue> levels,
  List<TimeValue> counters,
) {
  if (endMs - startMs < 60000) return;
  final segCounters =
      counters.where((c) => c.ts >= startMs && c.ts <= endMs).toList();
  if (segCounters.length < 2) return;
  final mah = (segCounters.last.value - segCounters.first.value).abs() / 1000.0;
  if (mah <= 0) return;

  int levelAt(int ts, {required bool after}) {
    TimeValue? best;
    for (final l in levels) {
      if (after ? l.ts >= ts : l.ts <= ts) {
        if (best == null ||
            (after ? l.ts < best.ts : l.ts > best.ts)) {
          best = l;
        }
      }
    }
    return best?.value.round() ?? -1;
  }

  final lStart = levelAt(startMs, after: true);
  final lEnd = levelAt(endMs, after: false);
  if (lStart < 0 || lEnd < 0) return;
  out.add(ChargeSession(
    startMs: startMs,
    endMs: endMs,
    levelStart: lStart,
    levelEnd: lEnd,
    mahCharged: mah,
  ));
}
