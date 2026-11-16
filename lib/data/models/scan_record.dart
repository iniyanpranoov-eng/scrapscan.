class ScanRecord {
  final int? id;
  final String category;
  final double confidence;
  final double weightKg;
  final double rateAtScanTime;
  final double estimatedValue;
  final String imagePath;
  final DateTime timestamp;
  final String aiEngine;
  final String? lotId;

  const ScanRecord({
    this.id,
    required this.category,
    required this.confidence,
    required this.weightKg,
    required this.rateAtScanTime,
    required this.estimatedValue,
    required this.imagePath,
    required this.timestamp,
    required this.aiEngine,
    this.lotId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'confidence': confidence,
      'weight_kg': weightKg,
      'rate_at_scan_time': rateAtScanTime,
      'estimated_value': estimatedValue,
      'image_path': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'ai_engine': aiEngine,
      'lot_id': lotId,
    };
  }

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'] as int?,
      category: map['category'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      rateAtScanTime: (map['rate_at_scan_time'] as num).toDouble(),
      estimatedValue: (map['estimated_value'] as num).toDouble(),
      imagePath: map['image_path'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      aiEngine: (map['ai_engine'] as String?) ?? 'Google ML Kit (Offline)',
      lotId: map['lot_id'] as String?,
    );
  }

  ScanRecord copyWith({
    int? id,
    String? category,
    double? confidence,
    double? weightKg,
    double? rateAtScanTime,
    double? estimatedValue,
    String? imagePath,
    DateTime? timestamp,
    String? aiEngine,
    String? lotId,
  }) {
    return ScanRecord(
      id: id ?? this.id,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      weightKg: weightKg ?? this.weightKg,
      rateAtScanTime: rateAtScanTime ?? this.rateAtScanTime,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      aiEngine: aiEngine ?? this.aiEngine,
      lotId: lotId ?? this.lotId,
    );
  }
}
