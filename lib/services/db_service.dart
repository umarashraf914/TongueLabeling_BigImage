// lib/services/db_service.dart

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// A single tap/color event: which doctor, which image, which color, which iteration, when.
class LabelEvent {
  int? id;
  final String doctorName;
  final String fileName;
  final String color;
  final int iteration;
  final DateTime timestamp;
  final int? ambientLux;
  final String sessionId;

  LabelEvent({
    this.id,
    required this.doctorName,
    required this.fileName,
    required this.color,
    required this.iteration,
    required this.timestamp,
    this.ambientLux,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'doctorName': doctorName,
    'fileName': fileName,
    'color': color,
    'iteration': iteration,
    'timestamp': timestamp.toIso8601String(),
    'ambientLux': ambientLux,
    'sessionId': sessionId,
  };

  factory LabelEvent.fromMap(Map<String, dynamic> m) => LabelEvent(
    id: m['id'] as int?,
    doctorName: m['doctorName'] as String,
    fileName: m['fileName'] as String,
    color: m['color'] as String,
    iteration: m['iteration'] as int,
    timestamp: DateTime.parse(m['timestamp'] as String),
    ambientLux: m['ambientLux'] as int?,
    sessionId: m['sessionId'] as String? ?? '',
  );
}

/// A free‐hand region selection: which doctor, which image, which iteration, JSON polygon, when.
class RegionSelection {
  int? id;
  final String doctorName;
  final String fileName;
  final String pathJson;
  final int iteration;
  final DateTime timestamp;
  final int? ambientLux;
  final String sessionId;

  RegionSelection({
    this.id,
    required this.doctorName,
    required this.fileName,
    required this.pathJson,
    required this.iteration,
    required this.timestamp,
    this.ambientLux,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'doctorName': doctorName,
    'fileName': fileName,
    'pathJson': pathJson,
    'iteration': iteration,
    'timestamp': timestamp.toIso8601String(),
    'ambientLux': ambientLux,
    'sessionId': sessionId,
  };

  factory RegionSelection.fromMap(Map<String, dynamic> m) => RegionSelection(
    id: m['id'] as int?,
    doctorName: m['doctorName'] as String,
    fileName: m['fileName'] as String,
    pathJson: m['pathJson'] as String,
    iteration: m['iteration'] as int,
    timestamp: DateTime.parse(m['timestamp'] as String),
    ambientLux: m['ambientLux'] as int?,
    sessionId: m['sessionId'] as String? ?? '',
  );
}

class DbService {
  static Database? _db;

  /// Returns a singleton [Database], creating or migrating it as needed.
  static Future<Database> get db async {
    if (_db != null) return _db!;

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'labels.db');

    _db = await openDatabase(
      dbPath,
      version: 2, // bumped from 1 to 2
      onCreate: (db, version) async {
        // Create both tables with iteration column
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doctorName TEXT NOT NULL,
            fileName   TEXT NOT NULL,
            color      TEXT NOT NULL,
            iteration  INTEGER NOT NULL,
            timestamp  TEXT NOT NULL,
            ambientLux INTEGER,
            sessionId  TEXT NOT NULL
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
            sessionId  TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add iteration column to existing tables, defaulting to 1
          await db.execute('''
            ALTER TABLE events
            ADD COLUMN iteration INTEGER NOT NULL DEFAULT 1
          ''');
          await db.execute('''
            ALTER TABLE regions
            ADD COLUMN iteration INTEGER NOT NULL DEFAULT 1
          ''');
        }
        // Add sessionId column if not present
        await db.execute('''
          ALTER TABLE events
          ADD COLUMN sessionId TEXT NOT NULL DEFAULT ''
        ''');
        await db.execute('''
          ALTER TABLE regions
          ADD COLUMN sessionId TEXT NOT NULL DEFAULT ''
        ''');
      },
    );

    return _db!;
  }

  // ───────────────────────────────
  // Event (color) operations
  // ───────────────────────────────

  /// Insert a new color‐label event.
  static Future<void> insertEvent(LabelEvent e) async {
    final database = await db;
    e.id = await database.insert('events', e.toMap());
  }

  /// Update an existing event's color & timestamp.
  static Future<void> updateEvent(int id, String newColor) async {
    final database = await db;
    await database.update(
      'events',
      {'color': newColor, 'timestamp': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fetch all color‐label events.
  static Future<List<LabelEvent>> fetchEvents() async {
    final database = await db;
    final rows = await database.query('events');
    return rows.map((r) => LabelEvent.fromMap(r)).toList();
  }

  // ───────────────────────────────
  // Region selection operations
  // ───────────────────────────────

  /// Insert a new region‐selection record.
  static Future<void> insertRegion(RegionSelection r) async {
    final database = await db;
    r.id = await database.insert('regions', r.toMap());
  }

  /// Fetch all region‐selection records.
  static Future<List<RegionSelection>> fetchRegions() async {
    final database = await db;
    final rows = await database.query('regions');
    return rows.map((r) => RegionSelection.fromMap(r)).toList();
  }

  /// Delete the most recent region for a given doctor, fileName, and iteration
  static Future<void> deleteLastRegion({
    required String doctorName,
    required String fileName,
    required int iteration,
  }) async {
    final database = await db;
    // Find the id of the most recent region
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

  /// Clear all data from the database (both events and regions)
  static Future<void> clearAllData() async {
    final database = await db;
    await database.delete('events');
    await database.delete('regions');
  }
}
