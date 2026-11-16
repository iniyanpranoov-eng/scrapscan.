import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../models/scrap_category.dart';
import '../models/scan_record.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scrap_scan_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        rate_per_kg REAL NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 1,
        icon_name TEXT NOT NULL,
        description TEXT NOT NULL,
        recycling_steps TEXT,
        disposal_warning TEXT
      )
    ''');

    // Scan history table
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        confidence REAL NOT NULL,
        weight_kg REAL NOT NULL,
        rate_at_scan_time REAL NOT NULL,
        estimated_value REAL NOT NULL,
        image_path TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        ai_engine TEXT NOT NULL,
        lot_id TEXT
      )
    ''');

    // Populate default categories
    final batch = db.batch();
    for (final item in AppConstants.defaultCategories) {
      batch.insert('categories', {
        'name': item['name'],
        'rate_per_kg': item['rate'],
        'is_default': 1,
        'icon_name': item['icon'],
        'description': item['description'],
        'recycling_steps': jsonEncode(item['recycling_steps'] ?? []),
        'disposal_warning': item['disposal_warning'] ?? '',
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add recycling_steps and disposal_warning columns if they don't exist
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN recycling_steps TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN disposal_warning TEXT');
      } catch (_) {}

      final batch = db.batch();
      for (final item in AppConstants.defaultCategories) {
        batch.update(
          'categories',
          {
            'recycling_steps': jsonEncode(item['recycling_steps'] ?? []),
            'disposal_warning': item['disposal_warning'] ?? '',
          },
          where: 'name = ?',
          whereArgs: [item['name']],
        );
      }
      await batch.commit(noResult: true);
    }
  }

  // ======================================================
  // V1.0.0 SHAREDPREFERENCES MIGRATION
  // ======================================================

  Future<int> migrateV1HistoryIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool('v1_migrated_to_sqlite') ?? false;

    if (isMigrated) {
      return 0;
    }

    final legacyList = prefs.getStringList('scan_history') ?? [];
    if (legacyList.isEmpty) {
      await prefs.setBool('v1_migrated_to_sqlite', true);
      return 0;
    }

    final db = await database;
    final batch = db.batch();
    int count = 0;

    for (final entry in legacyList) {
      final parts = entry.split('|');
      if (parts.length < 5) continue;

      String material = parts[0];
      double confidence = double.tryParse(parts[1]) ?? 0.0;
      double weight = double.tryParse(parts[2]) ?? 0.0;
      double value = double.tryParse(parts[3]) ?? 0.0;

      double savedValue = value;
      String imagePath = '';
      DateTime timestamp = DateTime.now();

      if (parts.length >= 7) {
        // v1.0.0 format: material | confidence | weight | value | savedValue | image | date
        savedValue = double.tryParse(parts[4]) ?? value;
        imagePath = parts[5];
        timestamp = DateTime.tryParse(parts[6]) ?? DateTime.now();
      } else if (parts.length >= 6) {
        // Older format: material | confidence | weight | value | image | date
        savedValue = value;
        imagePath = parts[4];
        timestamp = DateTime.tryParse(parts[5]) ?? DateTime.now();
      }

      double rateAtScan = weight > 0 ? (savedValue / weight) : 20.0;

      batch.insert('scan_history', {
        'category': material,
        'confidence': confidence,
        'weight_kg': weight,
        'rate_at_scan_time': rateAtScan,
        'estimated_value': savedValue,
        'image_path': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'ai_engine': 'Google ML Kit (v1.0 Migrated)',
        'lot_id': null,
      });
      count++;
    }

    await batch.commit(noResult: true);
    await prefs.setBool('v1_migrated_to_sqlite', true);
    return count;
  }

  // ======================================================
  // CATEGORIES CRUD
  // ======================================================

  Future<List<ScrapCategory>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'id ASC');
    return result.map((map) => ScrapCategory.fromMap(map)).toList();
  }

  Future<ScrapCategory?> getCategoryByName(String name) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return ScrapCategory.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertCategory(ScrapCategory category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCategoryRate(int id, double newRate) async {
    final db = await database;
    return await db.update(
      'categories',
      {'rate_per_kg': newRate},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCategory(ScrapCategory category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Protect default categories from deletion
    return await db.delete(
      'categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  Future<void> resetDefaultRates() async {
    final db = await database;
    final batch = db.batch();

    for (final item in AppConstants.defaultCategories) {
      batch.update(
        'categories',
        {
          'rate_per_kg': item['rate'],
          'description': item['description'],
          'recycling_steps': jsonEncode(item['recycling_steps'] ?? []),
          'disposal_warning': item['disposal_warning'] ?? '',
        },
        where: 'name = ?',
        whereArgs: [item['name']],
      );
    }

    await batch.commit(noResult: true);
  }

  // ======================================================
  // SCAN HISTORY CRUD
  // ======================================================

  Future<int> insertScan(ScanRecord record) async {
    final db = await database;
    return await db.insert('scan_history', record.toMap());
  }

  Future<List<int>> insertLotScans(List<ScanRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('scan_history', record.toMap());
    }
    final results = await batch.commit();
    return results.map((r) => r as int).toList();
  }

  Future<List<ScanRecord>> getAllScans({String orderBy = 'id DESC'}) async {
    final db = await database;
    final result = await db.query('scan_history', orderBy: orderBy);
    return result.map((map) => ScanRecord.fromMap(map)).toList();
  }

  Future<int> deleteScan(int id) async {
    final db = await database;
    return await db.delete(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllScans() async {
    final db = await database;
    return await db.delete('scan_history');
  }

  // ======================================================
  // AGGREGATION & ANALYTICS QUERIES
  // ======================================================

  Future<double> getTotalSavings() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(estimated_value) as total FROM scan_history');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalWeight() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(weight_kg) as total FROM scan_history');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<int> getTotalScansCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scan_history');
    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as num).toInt();
    }
    return 0;
  }

  Future<List<ScanRecord>> getScansBetween(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'scan_history',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return result.map((map) => ScanRecord.fromMap(map)).toList();
  }
}
