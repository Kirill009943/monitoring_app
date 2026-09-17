import 'db.dart';
import 'models.dart';

class StatsRepo {
  final MonitorDb _db;

  StatsRepo([MonitorDb? db]) : _db = db ?? MonitorDb.instance;

  Future<List<TimeValue>> series({
    required String kind,
    required String key,
    required int startMs,
    required int endMs,
    int? bucketMs,
  }) async {
    final db = await _db.db;
    if (bucketMs == null) {
      final rows = await db.query(
        'samples',
        columns: ['ts', 'value'],
        where: 'kind = ? AND key = ? AND ts BETWEEN ? AND ?',
        whereArgs: [kind, key, startMs, endMs],
        orderBy: 'ts',
      );
      return rows
          .map((r) => TimeValue((r['ts'] as num).toInt(), (r['value'] as num).toDouble()))
          .toList();
    }
    final agg = kind == 'usage' ? 'SUM(value)' : 'AVG(value)';
    final rows = await db.rawQuery(
      'SELECT (ts / ?) * ? AS bts, $agg AS v FROM samples '
      'WHERE kind = ? AND key = ? AND ts BETWEEN ? AND ? '
      'GROUP BY bts ORDER BY bts',
      [bucketMs, bucketMs, kind, key, startMs, endMs],
    );
    return rows
        .map((r) => TimeValue((r['bts'] as num).toInt(), (r['v'] as num).toDouble()))
        .toList();
  }

  Future<MinAvgMax> minAvgMax({
    required String kind,
    required String key,
    required int startMs,
    required int endMs,
  }) async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      'SELECT MIN(value) AS mn, AVG(value) AS av, MAX(value) AS mx, COUNT(*) AS c '
      'FROM samples WHERE kind = ? AND key = ? AND ts BETWEEN ? AND ?',
      [kind, key, startMs, endMs],
    );
    final r = rows.first;
    final count = (r['c'] as num?)?.toInt() ?? 0;
    if (count == 0 || r['mn'] == null) return MinAvgMax.empty;
    return MinAvgMax(
      min: (r['mn'] as num).toDouble(),
      avg: (r['av'] as num).toDouble(),
      max: (r['mx'] as num).toDouble(),
      count: count,
    );
  }

  Future<double?> latestValue({required String kind, required String key}) async {
    final db = await _db.db;
    final rows = await db.query(
      'samples',
      columns: ['value'],
      where: 'kind = ? AND key = ?',
      whereArgs: [kind, key],
      orderBy: 'ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['value'] as num?)?.toDouble();
  }

  Future<int> pruneOlderThan(int days) async {
    final db = await _db.db;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - days * 86400000;
    return db.delete('samples', where: 'ts < ?', whereArgs: [cutoff]);
  }

  Future<List<TimeValue>> dailyUsageSeries({
    required String packageName,
    required int days,
  }) async {
    final db = await _db.db;
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final dayStart = DateTime(start.year, start.month, start.day);
    final rows = await db.rawQuery(
      'SELECT (ts / 86400000) * 86400000 AS bts, SUM(value) AS v FROM samples '
      'WHERE kind = ? AND key = ? AND ts >= ? GROUP BY bts ORDER BY bts',
      ['usage', packageName, dayStart.millisecondsSinceEpoch],
    );
    return rows
        .map((r) => TimeValue((r['bts'] as num).toInt(), (r['v'] as num).toDouble()))
        .toList();
  }
}
