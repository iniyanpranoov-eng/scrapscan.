import 'scan_record.dart';

class ScrapLotItem {
  final String id;
  final String category;
  final double ratePerKg;
  double weightKg;
  final double confidence;
  final String imagePath;
  final String aiEngine;
  final DateTime addedAt;

  ScrapLotItem({
    required this.id,
    required this.category,
    required this.ratePerKg,
    required this.weightKg,
    required this.confidence,
    required this.imagePath,
    required this.aiEngine,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  double get estimatedValue => weightKg * ratePerKg;

  ScanRecord toScanRecord({required String lotId}) {
    return ScanRecord(
      category: category,
      confidence: confidence,
      weightKg: weightKg,
      rateAtScanTime: ratePerKg,
      estimatedValue: estimatedValue,
      imagePath: imagePath,
      timestamp: addedAt,
      aiEngine: aiEngine,
      lotId: lotId,
    );
  }
}
