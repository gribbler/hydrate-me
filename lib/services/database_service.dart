import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/drink_log.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'hydrate_me.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE drink_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          amountMl REAL NOT NULL
        )
      '''),
    );
  }

  static Future<int> logDrink(DrinkLog log) async {
    final database = await db;
    return database.insert('drink_logs', log.toMap());
  }

  static Future<List<DrinkLog>> logsForDay(DateTime day) async {
    final database = await db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await database.query(
      'drink_logs',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return rows.map(DrinkLog.fromMap).toList();
  }

  // Returns total ml consumed per day for the last [days] days.
  static Future<Map<DateTime, double>> dailyTotals(int days) async {
    final database = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await database.query(
      'drink_logs',
      where: 'timestamp >= ?',
      whereArgs: [since.toIso8601String()],
    );
    final Map<DateTime, double> totals = {};
    for (final row in rows) {
      final log = DrinkLog.fromMap(row);
      final day =
          DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      totals[day] = (totals[day] ?? 0) + log.amountMl;
    }
    return totals;
  }

  static Future<void> deleteLog(int id) async {
    final database = await db;
    await database.delete('drink_logs', where: 'id = ?', whereArgs: [id]);
  }
}
