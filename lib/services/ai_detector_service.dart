import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants/app_constants.dart';
import '../data/models/detected_object.dart';
import '../data/models/scrap_category.dart';
import 'ai_classifier_service.dart';
import 'settings_service.dart';

class ScrapDetectionResult {
  final List<DetectedObject> objects;
  final String aiEngine;
  final bool isMultiObject;
  final bool isUncertain;
  final double primaryConfidence;
  final String primaryCategory;

  const ScrapDetectionResult({
    required this.objects,
    required this.aiEngine,
    required this.isMultiObject,
    required this.isUncertain,
    required this.primaryConfidence,
    required this.primaryCategory,
  });

  double get totalWeightKg =>
      objects.fold(0.0, (sum, o) => sum + o.weightKg);

  double get totalEstimatedValue =>
      objects.fold(0.0, (sum, o) => sum + o.estimatedValue);

  int get count => objects.length;
}

class AIDetectorService {
  static final AIDetectorService instance = AIDetectorService._init();

  AIDetectorService._init();

  bool? _isYoloModelAvailable;
  String _activeModelAsset = 'assets/models/yolov8n_float16.tflite';

  /// Check whether YOLOv8 model file and labels exist in assets
  Future<bool> isYOLOModelAvailable() async {
    if (_isYoloModelAvailable != null) return _isYoloModelAvailable!;

    final candidateAssets = [
      'assets/models/yolov8n_float16.tflite',
      'assets/models/yolov8n.tflite',
    ];

    for (final asset in candidateAssets) {
      try {
        await rootBundle.load(asset);
        await rootBundle.loadString('assets/models/labels.txt');
        _activeModelAsset = asset;
        _isYoloModelAvailable = true;
        return true;
      } catch (_) {}
    }

    _isYoloModelAvailable = false;
    return false;
  }

  /// Main detection pipeline: Runs hardware-accelerated YOLOv8 multi-item detection
  /// if present, or gracefully falls back to single classification / Google ML Kit.
  Future<ScrapDetectionResult> detectObjects(
    String imagePath, {
    required List<ScrapCategory> categories,
  }) async {
    final useYolo = await SettingsService.instance.getUseYoloEngine();
    final hasYolo = useYolo && await isYOLOModelAvailable();

    if (hasYolo) {
      try {
        final yoloResult = await _runYOLODetection(imagePath, categories);
        if (yoloResult != null) {
          return yoloResult;
        }
      } catch (e) {
        // Fallback to classifier if YOLO runtime fails
      }
    }

    // Graceful fallback to single classifier / offline Google ML Kit
    return await _fallbackToClassifier(imagePath, categories);
  }

  // ======================================================
  // HARDWARE-ACCELERATED YOLOV8 DETECTION
  // ======================================================

  Future<ScrapDetectionResult?> _runYOLODetection(
    String imagePath,
    List<ScrapCategory> categories,
  ) async {
    try {
      final modelData = await rootBundle.load(_activeModelAsset);
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      final labels = labelsData
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      // Preprocess image: 1:1 center square-crop, lighting check & compensation, 640x640 resize
      final processed = AIClassifierService.preprocessImage(
        decodedImage,
        targetWidth: 640,
        targetHeight: 640,
        compensateLighting: true,
      );

      final options = _createHardwareAcceleratedOptions();
      final interpreter = Interpreter.fromBuffer(
        modelData.buffer.asUint8List(),
        options: options,
      );

      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);

      final inputShape = inputTensor.shape; // [1, 640, 640, 3]
      final outputShape = outputTensor.shape; // [1, 4 + classes, 8400] or [1, 8400, 4 + classes]

      final int height = inputShape.length > 1 ? inputShape[1] : 640;
      final int width = inputShape.length > 2 ? inputShape[2] : 640;

      // Prepare normalized input tensor [1, 640, 640, 3] in [0.0, 1.0]
      final input = List.generate(
        1,
        (_) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) {
              final pixel = processed.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Allocate output buffer dynamically based on output shape
      final output = _createOutputBuffer(outputShape);
      interpreter.run(input, output);
      interpreter.close();

      // Post-process bounding boxes, confidences, and classes
      final candidates = _parseYOLOOutput(
        output: output,
        outputShape: outputShape,
        labels: labels,
        categories: categories,
      );

      // Apply Non-Maximum Suppression (NMS) to eliminate duplicate overlapping boxes
      final detected = _applyNMS(candidates, 0.45);

      if (detected.isEmpty) {
        return const ScrapDetectionResult(
          objects: [],
          aiEngine: 'YOLOv8-nano (Hardware Accelerated)',
          isMultiObject: false,
          isUncertain: true,
          primaryConfidence: 0.0,
          primaryCategory: 'Uncertain / Unknown material',
        );
      }

      final primary = detected.first;

      return ScrapDetectionResult(
        objects: detected,
        aiEngine: 'YOLOv8-nano (Hardware Accelerated)',
        isMultiObject: detected.length > 1,
        isUncertain: false,
        primaryConfidence: primary.confidence,
        primaryCategory: primary.category,
      );
    } catch (e) {
      return null;
    }
  }

  InterpreterOptions _createHardwareAcceleratedOptions() {
    final options = InterpreterOptions()..threads = 4;
    if (Platform.isAndroid) {
      try {
        // Mobile GPU acceleration via GpuDelegateV2
        options.addDelegate(GpuDelegateV2());
      } catch (_) {
        try {
          options.addDelegate(XNNPackDelegate());
        } catch (_) {}
      }
    } else {
      try {
        options.addDelegate(XNNPackDelegate());
      } catch (_) {}
    }
    return options;
  }

  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.length == 3) {
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List<double>.filled(shape[2], 0.0),
        ),
      );
    }
    return List.generate(1, (_) => List.generate(11, (_) => List<double>.filled(8400, 0.0)));
  }

  List<DetectedObject> _parseYOLOOutput({
    required dynamic output,
    required List<int> outputShape,
    required List<String> labels,
    required List<ScrapCategory> categories,
  }) {
    final List<DetectedObject> rawCandidates = [];
    final int numClasses = labels.length;

    // Format A: [1, 4 + num_classes, 8400]
    if (outputShape.length == 3 && outputShape[1] < outputShape[2]) {
      final int channels = outputShape[1];
      final int numBoxes = outputShape[2];

      for (int i = 0; i < numBoxes; i++) {
        double maxClassScore = 0.0;
        int maxClassIdx = 0;

        for (int c = 0; c < numClasses && (4 + c) < channels; c++) {
          final score = (output[0][4 + c][i] as num).toDouble();
          if (score > maxClassScore) {
            maxClassScore = score;
            maxClassIdx = c;
          }
        }

        // Strict 65% threshold enforcement
        if (maxClassScore >= AppConstants.confidenceThreshold) {
          final cx = (output[0][0][i] as num).toDouble();
          final cy = (output[0][1][i] as num).toDouble();
          final w = (output[0][2][i] as num).toDouble();
          final h = (output[0][3][i] as num).toDouble();

          final rect = _toNormalizedRect(cx, cy, w, h);
          final label = maxClassIdx < labels.length ? labels[maxClassIdx] : 'Unknown';
          final category = _matchCategory(label, categories);

          rawCandidates.add(
            DetectedObject(
              id: 'det_${DateTime.now().microsecondsSinceEpoch}_$i',
              category: category?.name ?? label,
              confidence: maxClassScore,
              boundingBox: rect,
              weightKg: _defaultItemWeight(category?.name ?? label),
              ratePerKg: category?.ratePerKg ?? 20.0,
              aiEngine: 'YOLOv8-nano (GPU)',
            ),
          );
        }
      }
    }
    // Format B: [1, 8400, 4 + num_classes]
    else if (outputShape.length == 3) {
      final int numBoxes = outputShape[1];
      final int channels = outputShape[2];

      for (int i = 0; i < numBoxes; i++) {
        double maxClassScore = 0.0;
        int maxClassIdx = 0;

        for (int c = 0; c < numClasses && (4 + c) < channels; c++) {
          final score = (output[0][i][4 + c] as num).toDouble();
          if (score > maxClassScore) {
            maxClassScore = score;
            maxClassIdx = c;
          }
        }

        if (maxClassScore >= AppConstants.confidenceThreshold) {
          final cx = (output[0][i][0] as num).toDouble();
          final cy = (output[0][i][1] as num).toDouble();
          final w = (output[0][i][2] as num).toDouble();
          final h = (output[0][i][3] as num).toDouble();

          final rect = _toNormalizedRect(cx, cy, w, h);
          final label = maxClassIdx < labels.length ? labels[maxClassIdx] : 'Unknown';
          final category = _matchCategory(label, categories);

          rawCandidates.add(
            DetectedObject(
              id: 'det_${DateTime.now().microsecondsSinceEpoch}_$i',
              category: category?.name ?? label,
              confidence: maxClassScore,
              boundingBox: rect,
              weightKg: _defaultItemWeight(category?.name ?? label),
              ratePerKg: category?.ratePerKg ?? 20.0,
              aiEngine: 'YOLOv8-nano (GPU)',
            ),
          );
        }
      }
    }

    return rawCandidates;
  }

  Rect _toNormalizedRect(double cx, double cy, double w, double h) {
    // If coords are in pixel space (0-640), convert to [0.0, 1.0]
    final normCx = cx > 1.0 ? (cx / 640.0) : cx;
    final normCy = cy > 1.0 ? (cy / 640.0) : cy;
    final normW = w > 1.0 ? (w / 640.0) : w;
    final normH = h > 1.0 ? (h / 640.0) : h;

    final left = (normCx - normW / 2.0).clamp(0.0, 1.0);
    final top = (normCy - normH / 2.0).clamp(0.0, 1.0);
    final width = normW.clamp(0.0, 1.0 - left);
    final height = normH.clamp(0.0, 1.0 - top);

    return Rect.fromLTWH(left, top, width, height);
  }

  // Non-Maximum Suppression (NMS)
  static List<DetectedObject> _applyNMS(List<DetectedObject> candidates, double iouThreshold) {
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<DetectedObject> selected = [];

    for (final candidate in candidates) {
      bool shouldSelect = true;
      for (final existing in selected) {
        if (_calculateIoU(candidate.boundingBox, existing.boundingBox) > iouThreshold) {
          shouldSelect = false;
          break;
        }
      }
      if (shouldSelect) {
        selected.add(candidate);
      }
    }
    return selected;
  }

  static double _calculateIoU(Rect a, Rect b) {
    final double intersectionLeft = math.max(a.left, b.left);
    final double intersectionTop = math.max(a.top, b.top);
    final double intersectionRight = math.min(a.right, b.right);
    final double intersectionBottom = math.min(a.bottom, b.bottom);

    if (intersectionRight < intersectionLeft || intersectionBottom < intersectionTop) {
      return 0.0;
    }

    final double intersectionArea =
        (intersectionRight - intersectionLeft) * (intersectionBottom - intersectionTop);
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double unionArea = areaA + areaB - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  // ======================================================
  // FALLBACK TO SINGLE CLASSIFIER / GOOGLE ML KIT
  // ======================================================

  Future<ScrapDetectionResult> _fallbackToClassifier(
    String imagePath,
    List<ScrapCategory> categories,
  ) async {
    final result = await AIClassifierService.instance.classifyImage(imagePath);

    if (result.isUncertain) {
      return ScrapDetectionResult(
        objects: [],
        aiEngine: result.aiEngine,
        isMultiObject: false,
        isUncertain: true,
        primaryConfidence: result.confidence,
        primaryCategory: 'Uncertain / Unknown material',
      );
    }

    final cat = _matchCategory(result.category, categories);
    final singleObject = DetectedObject(
      id: 'det_single_${DateTime.now().millisecondsSinceEpoch}',
      category: cat?.name ?? result.category,
      confidence: result.confidence,
      boundingBox: const Rect.fromLTWH(0.08, 0.08, 0.84, 0.84),
      weightKg: _defaultItemWeight(cat?.name ?? result.category),
      ratePerKg: cat?.ratePerKg ?? 20.0,
      aiEngine: result.aiEngine,
    );

    return ScrapDetectionResult(
      objects: [singleObject],
      aiEngine: result.aiEngine,
      isMultiObject: false,
      isUncertain: false,
      primaryConfidence: result.confidence,
      primaryCategory: singleObject.category,
    );
  }

  ScrapCategory? _matchCategory(String name, List<ScrapCategory> list) {
    final lower = name.toLowerCase();
    for (final cat in list) {
      if (cat.name.toLowerCase() == lower) return cat;
      if (lower.contains('plastic') && cat.name.contains('Plastic')) return cat;
      if (lower.contains('aluminum') && cat.name.contains('Aluminum')) return cat;
      if (lower.contains('paper') && cat.name.contains('Paper')) return cat;
      if (lower.contains('cardboard') && cat.name.contains('Cardboard')) return cat;
      if (lower.contains('iron') && cat.name.contains('Iron')) return cat;
      if (lower.contains('copper') && cat.name.contains('Copper')) return cat;
      if (lower.contains('e-waste') && cat.name.contains('E-Waste')) return cat;
      if (lower.contains('glass') && cat.name.contains('Glass')) return cat;
    }
    return list.isNotEmpty ? list.first : null;
  }

  double _defaultItemWeight(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plastic')) return 0.05; // 50g per bottle
    if (lower.contains('aluminum')) return 0.02; // 20g per can
    if (lower.contains('paper') || lower.contains('cardboard')) return 0.25;
    if (lower.contains('iron') || lower.contains('steel')) return 1.0;
    if (lower.contains('copper')) return 0.40;
    if (lower.contains('e-waste')) return 0.30;
    if (lower.contains('glass')) return 0.35;
    return 0.25;
  }
}
