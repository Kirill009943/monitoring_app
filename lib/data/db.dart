import 'package:sqflite/sqflite.dart';

class MonitorDb {
  MonitorDb._();

  static final MonitorDb instance = MonitorDb._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      '$dir/monitor.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE IF NOT EXISTS samples(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, kind TEXT NOT NULL, key TEXT NOT NULL, value REAL NOT NULL)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_samples ON samples(kind, key, ts)');
      },
      onOpen: (db) async {
        await db.execute(
            'CREATE TABLE IF NOT EXISTS samples(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, kind TEXT NOT NULL, key TEXT NOT NULL, value REAL NOT NULL)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_samples ON samples(kind, key, ts)');
      },
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
