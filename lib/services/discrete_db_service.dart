import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_service.dart'; // For LabelEvent and RegionSelection

class DiscreteDbService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'discrete_mode.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doctorName TEXT NOT NULL,
            fileName   TEXT NOT NULL,
            color      TEXT NOT NULL,
            iteration  INTEGER NOT NULL,
            timestamp  TEXT NOT NULL,
            ambientLux INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE regions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doctorName TEXT NOT NULL,
            fileName   TEXT NOT NULL,
            pathJson   TEXT NOT NULL,
            iteration  INTEGER NOT NULL,
            timestamp  TEXT NOT NULL,
            ambientLux INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  // Event CRUD
  static Future<void> insertEvent(LabelEvent e) async {
    final database = await db;
    e.id = await database.insert('events', e.toMap());
  }

  static Future<void> updateEvent(int id, String newColor) async {
    final database = await db;
    await database.update(
      'events',
      {'color': newColor, 'timestamp': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<LabelEvent>> fetchEvents() async {
    final database = await db;
    final rows = await database.query('events');
    return rows.map((r) => LabelEvent.fromMap(r)).toList();
  }

  // Region CRUD
  static Future<void> insertRegion(RegionSelection r) async {
    final database = await db;
    r.id = await database.insert('regions', r.toMap());
  }

  static Future<List<RegionSelection>> fetchRegions() async {
    final database = await db;
    final rows = await database.query('regions');
    return rows.map((r) => RegionSelection.fromMap(r)).toList();
  }

  static Future<void> deleteLastRegion({
    required String doctorName,
    required String fileName,
    required int iteration,
  }) async {
    final database = await db;
    final rows = await database.query(
      'regions',
      where: 'doctorName = ? AND fileName = ? AND iteration = ?',
      whereArgs: [doctorName, fileName, iteration],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      await database.delete('regions', where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> clearAllData() async {
    final database = await db;
    await database.delete('events');
    await database.delete('regions');
  }
}
