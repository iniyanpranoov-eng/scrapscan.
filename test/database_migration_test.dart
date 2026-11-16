import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scrap_scan/data/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('v1.0.0 SharedPreferences Migration Tests', () {
    test('Migrates 7-field and 6-field legacy records to SQLite correctly', () async {
      // Setup mock legacy v1.0.0 data
      SharedPreferences.setMockInitialValues({
        'v1_migrated_to_sqlite': false,
        'scan_history': [
          // 7-field format: material|confidence|weight|value|savedValue|image|date
          'Plastic Bottle|0.92|1.5|30.0|30.0|/old/path1.jpg|2026-08-01T10:00:00.000',
          // 6-field older format: material|confidence|weight|value|image|date
          'Aluminum Can|0.85|2.0|70.0|/old/path2.jpg|2026-08-02T11:00:00.000',
        ],
      });

      final migratedCount = await AppDatabase.instance.migrateV1HistoryIfNeeded();
      expect(migratedCount, 2);

      // Verify records are present in SQLite
      final scans = await AppDatabase.instance.getAllScans();
      expect(scans.length, greaterThanOrEqualTo(2));

      final p1 = scans.firstWhere((s) => s.category == 'Plastic Bottle');
      expect(p1.weightKg, 1.5);
      expect(p1.estimatedValue, 30.0);
      expect(p1.rateAtScanTime, 20.0);
      expect(p1.aiEngine, contains('v1.0 Migrated'));

      final p2 = scans.firstWhere((s) => s.category == 'Aluminum Can');
      expect(p2.weightKg, 2.0);
      expect(p2.estimatedValue, 70.0);
      expect(p2.rateAtScanTime, 35.0);

      // Verify flag is set in SharedPreferences so it runs only once
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('v1_migrated_to_sqlite'), isTrue);

      // Second run should return 0
      final rerunCount = await AppDatabase.instance.migrateV1HistoryIfNeeded();
      expect(rerunCount, 0);
    });
  });
}
