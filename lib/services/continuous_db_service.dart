import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_service.dart'; // For RegionSelection

class ContinuousLabelEvent {
  int? id;
  final String doctorName;
  final String fileName;
  final int iteration;
  final DateTime timestamp;
  final int? ambientLux;
  final String colorA;
  final double percentA;
  final String colorB;
  final double percentB;
  final String sessionId;

  ContinuousLabelEvent({
    this.id,
    required this.doctorName,
    required this.fileName,
    required this.iteration,
    required this.timestamp,
    this.ambientLux,
    required this.colorA,
    required this.percentA,
    required this.colorB,
    required this.percentB,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'doctorName': doctorName,
    'fileName': fileName,
    'iteration': iteration,
    'timestamp': timestamp.toIso8601String(),
    'ambientLux': ambientLux,
    'colorA': colorA,
    'percentA': percentA,
    'colorB': colorB,
    'percentB': percentB,
    'sessionId': sessionId,
  };

  factory ContinuousLabelEvent.fromMap(Map<String, dynamic> m) =>
      ContinuousLabelEvent(
        id: m['id'] as int?,
        doctorName: m['doctorName'] as String,
        fileName: m['fileName'] as String,
        iteration: m['iteration'] as int,
        timestamp: DateTime.parse(m['timestamp'] as String),
        ambientLux: m['ambientLux'] as int?,
        colorA: m['colorA'] as String,
        percentA: (m['percentA'] as num).toDouble(),
        colorB: m['colorB'] as String,
        percentB: (m['percentB'] as num).toDouble(),
        sessionId: m['sessionId'] as String? ?? '',
      );
}

class ContinuousDbService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'continuous_mode.db');
    _db = await openDatabase(
      dbPath,
      version: 2, // Bump version to add sessionId columns
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doctorName TEXT NOT NULL,
            fileName   TEXT NOT NULL,
            iteration  INTEGER NOT NULL,
            timestamp  TEXT NOT NULL,
            ambientLux INTEGER,
            colorA     TEXT NOT NULL,
            percentA   REAL NOT NULL,
            colorB     TEXT NOT NULL,
            percentB   REAL NOT NULL,
            sessionId  TEXT NOT NULL DEFAULT ''
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
            ambientLux INTEGER,
            sessionId  TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add sessionId column to existing tables
          await db.execute('''
            ALTER TABLE events
            ADD COLUMN sessionId TEXT NOT NULL DEFAULT ''
          ''');
          await db.execute('''
            ALTER TABLE regions
            ADD COLUMN sessionId TEXT NOT NULL DEFAULT ''
          ''');
        }
      },
    );
    return _db!;
  }

  // Event CRUD
  static Future<void> insertEvent(ContinuousLabelEvent e) async {
    final database = await db;
    await database.transaction((txn) async {
      e.id = await txn.insert('events', e.toMap());
    });
  }

  static Future<void> updateEvent(int id, ContinuousLabelEvent newEvent) async {
    final database = await db;
    final map = Map<String, dynamic>.from(newEvent.toMap());
    map.remove('id'); // Do not update the primary key
    await database.update('events', map, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<ContinuousLabelEvent>> fetchEvents({
    String? sessionId,
  }) async {
    final database = await db;
    List<Map<String, dynamic>> rows;
    if (sessionId != null) {
      rows = await database.query(
        'events',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
      );
    } else {
      rows = await database.query('events');
    }
    return rows.map((r) => ContinuousLabelEvent.fromMap(r)).toList();
  }

  static Future<void> deleteEvent({
    required String doctorName,
    required String fileName,
    required int iteration,
    required String colorA,
    required String colorB,
    required String sessionId,
  }) async {
    final database = await db;
    await database.delete(
      'events',
      where:
          'doctorName = ? AND fileName = ? AND iteration = ? AND colorA = ? AND colorB = ? AND sessionId = ?',
      whereArgs: [doctorName, fileName, iteration, colorA, colorB, sessionId],
    );
  }

  static Future<void> deleteAllEventsForImage({
    required String doctorName,
    required String fileName,
    required int iteration,
    required String sessionId,
  }) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(
        'events',
        where:
            'doctorName = ? AND fileName = ? AND iteration = ? AND sessionId = ?',
        whereArgs: [doctorName, fileName, iteration, sessionId],
      );
    });
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
    required String sessionId,
  }) async {
    final database = await db;
    final rows = await database.query(
      'regions',
      where:
          'doctorName = ? AND fileName = ? AND iteration = ? AND sessionId = ?',
      whereArgs: [doctorName, fileName, iteration, sessionId],
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
