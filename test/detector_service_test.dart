import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrap_scan/data/models/detected_object.dart';
import 'package:scrap_scan/services/ai_detector_service.dart';

void main() {
  group('DetectedObject Model Tests', () {
    test('Calculates estimated value correctly for detected scrap', () {
      final item = DetectedObject(
        id: 'det_1',
        category: 'Plastic Bottle / PET',
        confidence: 0.89,
        boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.3, 0.4),
        weightKg: 0.5,
        ratePerKg: 20.0,
        aiEngine: 'YOLOv8-nano (GPU)',
      );

      expect(item.estimatedValue, 10.0);
    });

    test('copyWith updates properties properly', () {
      final original = DetectedObject(
        id: 'det_2',
        category: 'Aluminum Can & Tins',
        confidence: 0.92,
        boundingBox: const Rect.fromLTWH(0.5, 0.2, 0.2, 0.3),
        weightKg: 0.2,
        ratePerKg: 35.0,
        aiEngine: 'YOLOv8-nano (GPU)',
      );

      final updated = original.copyWith(weightKg: 0.5, ratePerKg: 40.0);
      expect(updated.weightKg, 0.5);
      expect(updated.ratePerKg, 40.0);
      expect(updated.estimatedValue, 20.0);
      expect(updated.id, original.id);
    });
  });

  group('ScrapDetectionResult Multi-Object Aggregation Tests', () {
    test('Aggregates cumulative weight and estimated value across multiple objects', () {
      final items = [
        DetectedObject(
          id: '1',
          category: 'Plastic Bottle / PET',
          confidence: 0.88,
          boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.3),
          weightKg: 0.5,
          ratePerKg: 20.0,
          aiEngine: 'YOLOv8-nano (GPU)',
        ),
        DetectedObject(
          id: '2',
          category: 'Aluminum Can & Tins',
          confidence: 0.91,
          boundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.3),
          weightKg: 0.2,
          ratePerKg: 35.0,
          aiEngine: 'YOLOv8-nano (GPU)',
        ),
        DetectedObject(
          id: '3',
          category: 'Paper/Cardboard',
          confidence: 0.76,
          boundingBox: const Rect.fromLTWH(0.2, 0.5, 0.5, 0.4),
          weightKg: 1.0,
          ratePerKg: 10.0,
          aiEngine: 'YOLOv8-nano (GPU)',
        ),
      ];

      final result = ScrapDetectionResult(
        objects: items,
        aiEngine: 'YOLOv8-nano (Hardware Accelerated)',
        isMultiObject: true,
        isUncertain: false,
        primaryConfidence: 0.88,
        primaryCategory: 'Plastic Bottle / PET',
      );

      expect(result.count, 3);
      expect(result.isMultiObject, isTrue);
      // 0.5 + 0.2 + 1.0 = 1.7 kg
      expect(result.totalWeightKg, 1.7);
      // 10.0 + 7.0 + 10.0 = 27.0
      expect(result.totalEstimatedValue, 27.0);
    });

    test('Uncertain result when no items detected above 65% threshold', () {
      const result = ScrapDetectionResult(
        objects: [],
        aiEngine: 'YOLOv8-nano',
        isMultiObject: false,
        isUncertain: true,
        primaryConfidence: 0.42,
        primaryCategory: 'Uncertain / Unknown material',
      );

      expect(result.isUncertain, isTrue);
      expect(result.count, 0);
      expect(result.totalWeightKg, 0.0);
      expect(result.totalEstimatedValue, 0.0);
    });
  });
}
