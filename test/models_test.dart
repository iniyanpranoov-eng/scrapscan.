import 'package:flutter_test/flutter_test.dart';
import 'package:scrap_scan/data/models/scrap_category.dart';
import 'package:scrap_scan/data/models/scan_record.dart';
import 'package:scrap_scan/data/models/scrap_lot_item.dart';

void main() {
  group('ScrapCategory Model Tests', () {
    test('toMap and fromMap should round-trip correctly', () {
      final category = ScrapCategory(
        id: 1,
        name: 'Plastic Bottle / PET',
        ratePerKg: 20.0,
        isDefault: true,
        iconName: 'local_drink_rounded',
        description: 'PET bottles',
        recyclingSteps: const [
          'Rinse bottle with clean water',
          'Flatten to reduce volume',
        ],
        disposalWarning: 'Never incinerate PET bottles',
      );

      final map = category.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Plastic Bottle / PET');
      expect(map['rate_per_kg'], 20.0);
      expect(map['is_default'], 1);
      expect(map['disposal_warning'], 'Never incinerate PET bottles');

      final reconstructed = ScrapCategory.fromMap(map);
      expect(reconstructed.id, category.id);
      expect(reconstructed.name, category.name);
      expect(reconstructed.ratePerKg, category.ratePerKg);
      expect(reconstructed.isDefault, isTrue);
      expect(reconstructed.recyclingSteps.length, 2);
      expect(reconstructed.recyclingSteps.first, 'Rinse bottle with clean water');
      expect(reconstructed.disposalWarning, 'Never incinerate PET bottles');
    });

    test('copyWith updates properties properly', () {
      const original = ScrapCategory(
        id: 2,
        name: 'Aluminum Can & Tins',
        ratePerKg: 35.0,
        recyclingSteps: ['Drain fluids'],
        disposalWarning: 'Wear gloves',
      );

      final updated = original.copyWith(
        ratePerKg: 40.0,
        disposalWarning: 'Wear protective work gloves',
      );
      expect(updated.ratePerKg, 40.0);
      expect(updated.name, original.name);
      expect(updated.id, original.id);
      expect(updated.recyclingSteps, original.recyclingSteps);
      expect(updated.disposalWarning, 'Wear protective work gloves');
    });
  });

  group('ScanRecord Model Tests', () {
    test('toMap and fromMap work as expected', () {
      final timestamp = DateTime(2026, 9, 15, 10, 30);
      final record = ScanRecord(
        id: 10,
        category: 'Copper & Wiring',
        confidence: 0.94,
        weightKg: 2.5,
        rateAtScanTime: 450.0,
        estimatedValue: 1125.0,
        imagePath: '/documents/scans/sample.jpg',
        timestamp: timestamp,
        aiEngine: 'TensorFlow Lite (MobileNetV3)',
        lotId: 'LOT_12345',
      );

      final map = record.toMap();
      expect(map['id'], 10);
      expect(map['category'], 'Copper & Wiring');
      expect(map['confidence'], 0.94);
      expect(map['weight_kg'], 2.5);
      expect(map['rate_at_scan_time'], 450.0);
      expect(map['estimated_value'], 1125.0);
      expect(map['lot_id'], 'LOT_12345');

      final reconstructed = ScanRecord.fromMap(map);
      expect(reconstructed.id, record.id);
      expect(reconstructed.category, record.category);
      expect(reconstructed.estimatedValue, 1125.0);
      expect(reconstructed.aiEngine, 'TensorFlow Lite (MobileNetV3)');
    });
  });

  group('ScrapLotItem Model Tests', () {
    test('estimatedValue calculated accurately and converts to ScanRecord', () {
      final item = ScrapLotItem(
        id: 'item_1',
        category: 'Iron & Steel',
        ratePerKg: 28.0,
        weightKg: 5.0,
        confidence: 0.88,
        imagePath: '/path/iron.jpg',
        aiEngine: 'Google ML Kit (Offline)',
      );

      expect(item.estimatedValue, 140.0);

      final record = item.toScanRecord(lotId: 'LOT_99');
      expect(record.category, 'Iron & Steel');
      expect(record.weightKg, 5.0);
      expect(record.estimatedValue, 140.0);
      expect(record.lotId, 'LOT_99');
    });
  });
}
