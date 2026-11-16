import 'package:flutter_test/flutter_test.dart';
import 'package:scrap_scan/data/models/scrap_lot_item.dart';
import 'package:scrap_scan/services/scrap_lot_service.dart';

void main() {
  group('ScrapLotService Cart Tests', () {
    final lot = ScrapLotService.instance;

    setUp(() {
      lot.clear();
    });

    test('addItem and total calculation work correctly', () {
      expect(lot.isEmpty, isTrue);
      expect(lot.itemCount, 0);

      lot.addItem(ScrapLotItem(
        id: '1',
        category: 'Plastic Bottle / PET',
        ratePerKg: 20.0,
        weightKg: 2.0,
        confidence: 0.90,
        imagePath: '',
        aiEngine: 'TFLite',
      ));

      lot.addItem(ScrapLotItem(
        id: '2',
        category: 'Aluminum Can & Tins',
        ratePerKg: 35.0,
        weightKg: 3.0,
        confidence: 0.85,
        imagePath: '',
        aiEngine: 'TFLite',
      ));

      expect(lot.itemCount, 2);
      expect(lot.totalWeight, 5.0);
      // 2 * 20 = 40; 3 * 35 = 105; total = 145.0
      expect(lot.totalValue, 145.0);
    });

    test('updateItemWeight adjusts totals dynamically', () {
      lot.addItem(ScrapLotItem(
        id: 'item_a',
        category: 'Copper & Wiring',
        ratePerKg: 450.0,
        weightKg: 1.0,
        confidence: 0.95,
        imagePath: '',
        aiEngine: 'TFLite',
      ));

      expect(lot.totalValue, 450.0);

      lot.updateItemWeight('item_a', 2.5);
      expect(lot.totalWeight, 2.5);
      expect(lot.totalValue, 1125.0);
    });

    test('removeItem removes item from session lot', () {
      lot.addItem(ScrapLotItem(
        id: 'x1',
        category: 'Paper/Cardboard',
        ratePerKg: 10.0,
        weightKg: 10.0,
        confidence: 0.80,
        imagePath: '',
        aiEngine: 'TFLite',
      ));
      expect(lot.itemCount, 1);

      lot.removeItem('x1');
      expect(lot.isEmpty, isTrue);
      expect(lot.totalValue, 0.0);
    });
  });
}
