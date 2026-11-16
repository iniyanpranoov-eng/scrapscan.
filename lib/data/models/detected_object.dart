import 'dart:ui';

class DetectedObject {
  final String id;
  final String category;
  final double confidence;
  final Rect boundingBox; // Normalized [0.0, 1.0] (left, top, width, height)
  double weightKg;
  double ratePerKg;
  final String aiEngine;

  DetectedObject({
    required this.id,
    required this.category,
    required this.confidence,
    required this.boundingBox,
    required this.weightKg,
    required this.ratePerKg,
    required this.aiEngine,
  });

  double get estimatedValue => weightKg * ratePerKg;

  DetectedObject copyWith({
    String? id,
    String? category,
    double? confidence,
    Rect? boundingBox,
    double? weightKg,
    double? ratePerKg,
    String? aiEngine,
  }) {
    return DetectedObject(
      id: id ?? this.id,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      weightKg: weightKg ?? this.weightKg,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      aiEngine: aiEngine ?? this.aiEngine,
    );
  }
}
