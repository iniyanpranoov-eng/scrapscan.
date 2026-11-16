import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants/app_constants.dart';
import 'settings_service.dart';

/// Represents a single candidate prediction from top-k scoring
class TopKPrediction {
  final String category;
  final double score;

  const TopKPrediction({required this.category, required this.score});

  @override
  String toString() => '$category (${(score * 100).toStringAsFixed(0)}%)';
}

/// Evaluates lighting luminance and contrast to detect dim or harshly lit scrap photos
class ImageLightingAssessment {
  final double averageLuminance; // 0.0 to 255.0
  final double contrastStdDev;
  final bool isDim;
  final bool isHarsh;
  final bool isLowContrast;
  final String? advisory;

  const ImageLightingAssessment({
    required this.averageLuminance,
    required this.contrastStdDev,
    required this.isDim,
    required this.isHarsh,
    required this.isLowContrast,
    this.advisory,
  });

  static ImageLightingAssessment analyze(img.Image image) {
    final int stepX = math.max(1, image.width ~/ 32);
    final int stepY = math.max(1, image.height ~/ 32);

    double totalLum = 0.0;
    int count = 0;
    final List<double> lumSamples = [];

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        totalLum += lum;
        lumSamples.add(lum);
        count++;
      }
    }

    if (count == 0) {
      return const ImageLightingAssessment(
        averageLuminance: 128.0,
        contrastStdDev: 50.0,
        isDim: false,
        isHarsh: false,
        isLowContrast: false,
      );
    }

    final avgLum = totalLum / count;
    double varianceSum = 0.0;
    for (final l in lumSamples) {
      final diff = l - avgLum;
      varianceSum += diff * diff;
    }
    final stdDev = math.sqrt(varianceSum / count);

    final bool isDim = avgLum < 45.0;
    final bool isHarsh = avgLum > 215.0;
    final bool isLowContrast = stdDev < 20.0;

    String? advisory;
    if (isDim) {
      advisory = 'Dim lighting detected. Textures may be unclear.';
    } else if (isHarsh) {
      advisory = 'Harsh lighting/glare detected. Reflections may distort color.';
    } else if (isLowContrast) {
      advisory = 'Low contrast detected. Please scan against a neutral background.';
    }

    return ImageLightingAssessment(
      averageLuminance: avgLum,
      contrastStdDev: stdDev,
      isDim: isDim,
      isHarsh: isHarsh,
      isLowContrast: isLowContrast,
      advisory: advisory,
    );
  }
}

class ClassificationResult {
  final String category;
  final double confidence;
  final String aiEngine;
  final bool isUncertain;
  final List<String> candidateLabels;
  final List<TopKPrediction> topKPredictions;
  final bool isBorderline;
  final ImageLightingAssessment? lightingQuality;

  const ClassificationResult({
    required this.category,
    required this.confidence,
    required this.aiEngine,
    required this.isUncertain,
    this.candidateLabels = const [],
    this.topKPredictions = const [],
    this.isBorderline = false,
    this.lightingQuality,
  });

  factory ClassificationResult.uncertain({
    String candidate = 'Uncertain / Unknown material',
    double confidence = 0.0,
    required String aiEngine,
    List<String> candidates = const [],
    List<TopKPrediction> topK = const [],
    bool isBorderline = false,
    ImageLightingAssessment? lightingQuality,
  }) {
    return ClassificationResult(
      category: candidate,
      confidence: confidence,
      aiEngine: aiEngine,
      isUncertain: true,
      candidateLabels: candidates,
      topKPredictions: topK,
      isBorderline: isBorderline,
      lightingQuality: lightingQuality,
    );
  }
}

/// Sliding-window buffer that stabilizes live camera/gallery classifications across consecutive frames
class TemporalClassifierBuffer {
  final int windowSize;
  final List<ClassificationResult> _window = [];

  TemporalClassifierBuffer({this.windowSize = 3});

  int get count => _window.length;
  List<ClassificationResult> get frames => List.unmodifiable(_window);

  void addFrame(ClassificationResult result) {
    if (_window.length >= windowSize) {
      _window.removeAt(0);
    }
    _window.add(result);
  }

  void reset() {
    _window.clear();
  }

  /// Stabilizes classification results across consecutive frames using majority voting
  /// and confidence smoothing to eliminate flickering between similar scrap categories.
  ClassificationResult getSmoothedResult() {
    if (_window.isEmpty) {
      return ClassificationResult.uncertain(
        aiEngine: 'Temporal Smoothing Buffer',
      );
    }

    if (_window.length == 1) {
      return _window.first;
    }

    final Map<String, int> voteCount = {};
    final Map<String, double> confidenceSum = {};
    final List<String> allCandidates = [];

    for (final frame in _window) {
      final cat = frame.category;
      voteCount[cat] = (voteCount[cat] ?? 0) + 1;
      confidenceSum[cat] = (confidenceSum[cat] ?? 0.0) + frame.confidence;
      for (final c in frame.candidateLabels) {
        if (!allCandidates.contains(c)) allCandidates.add(c);
      }
    }

    String bestCategory = _window.last.category;
    int maxVotes = 0;
    voteCount.forEach((cat, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        bestCategory = cat;
      }
    });

    final avgConfidence = (confidenceSum[bestCategory] ?? 0.0) / maxVotes;
    final bool hasMajority = maxVotes >= 2;
    final bool isUncertain = !hasMajority ||
        bestCategory == 'Uncertain / Unknown material' ||
        avgConfidence < AppConstants.confidenceThreshold;

    return ClassificationResult(
      category: isUncertain ? 'Uncertain / Unknown material' : bestCategory,
      confidence: avgConfidence,
      aiEngine: 'Temporal Multi-Frame Smoothing ($maxVotes/${_window.length} votes)',
      isUncertain: isUncertain,
      candidateLabels: allCandidates.take(4).toList(),
      topKPredictions: _window.last.topKPredictions,
      isBorderline: isUncertain && hasMajority && avgConfidence >= 0.50,
      lightingQuality: _window.last.lightingQuality,
    );
  }
}

class AIClassifierService {
  static final AIClassifierService instance = AIClassifierService._init();

  AIClassifierService._init();

  bool? _isTfliteAvailable;

  /// Temporal sliding window buffer across 3 consecutive frames
  final TemporalClassifierBuffer temporalBuffer = TemporalClassifierBuffer(windowSize: 3);

  /// Check whether custom TFLite weights and labels are bundled in assets
  Future<bool> isCustomModelAvailable() async {
    if (_isTfliteAvailable != null) return _isTfliteAvailable!;
    final candidateAssets = [
      'assets/models/yolov8n_float16.tflite',
      'assets/models/yolov8n.tflite',
      'assets/models/scrap_model.tflite',
    ];

    for (final asset in candidateAssets) {
      try {
        await rootBundle.load(asset);
        await rootBundle.loadString('assets/models/labels.txt');
        _isTfliteAvailable = true;
        return true;
      } catch (_) {}
    }

    _isTfliteAvailable = false;
    return false;
  }

  /// Image pre-processing pipeline:
  /// 1. Center square-crop to 1:1 aspect ratio to avoid distortion
  /// 2. Luminance & contrast compensation for dim or harsh photos
  /// 3. Resizing to exact model tensor dimensions
  static img.Image preprocessImage(
    img.Image source, {
    required int targetWidth,
    required int targetHeight,
    bool compensateLighting = true,
  }) {
    // 1. Center crop to 1:1 square aspect ratio
    final minDim = math.min(source.width, source.height);
    final offsetX = (source.width - minDim) ~/ 2;
    final offsetY = (source.height - minDim) ~/ 2;
    var cropped = img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: minDim,
      height: minDim,
    );

    // 2. Assess lighting and compensate dim/harsh lighting
    if (compensateLighting) {
      final lighting = ImageLightingAssessment.analyze(cropped);
      if (lighting.isDim) {
        cropped = img.adjustColor(cropped, brightness: 1.15, contrast: 1.12);
      } else if (lighting.isHarsh) {
        cropped = img.adjustColor(cropped, brightness: 0.92, contrast: 1.08);
      } else if (lighting.isLowContrast) {
        cropped = img.adjustColor(cropped, contrast: 1.20);
      }
    }

    // 3. Resize to exact tensor dimensions
    return img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Evaluates primary confidence against 65% threshold and top-k secondary predictions
  /// to flag borderline / ambiguous material classifications.
  static ({
    bool isUncertain,
    bool isBorderline,
    String finalCategory,
    double finalConfidence,
  }) evaluateConfidenceAndTopK({
    required List<TopKPrediction> topK,
    double threshold = AppConstants.confidenceThreshold,
  }) {
    if (topK.isEmpty) {
      return (
        isUncertain: true,
        isBorderline: false,
        finalCategory: 'Uncertain / Unknown material',
        finalConfidence: 0.0,
      );
    }

    final top1 = topK[0];
    final top2 = topK.length > 1 ? topK[1] : null;

    // Strict 65% threshold cut-off
    if (top1.score < threshold) {
      final bool borderline = top1.score >= 0.50;
      return (
        isUncertain: true,
        isBorderline: borderline,
        finalCategory: 'Uncertain / Unknown material',
        finalConfidence: top1.score,
      );
    }

    // Top-K secondary prediction ambiguity check:
    // If top-1 is marginally above threshold (< 0.75) and top-2 is very close (delta < 0.12),
    // mark as borderline uncertain for safe manual verification.
    if (top2 != null && top1.score < 0.75 && (top1.score - top2.score) < 0.12) {
      return (
        isUncertain: true,
        isBorderline: true,
        finalCategory: 'Uncertain / Unknown material',
        finalConfidence: top1.score,
      );
    }

    return (
      isUncertain: false,
      isBorderline: false,
      finalCategory: top1.category,
      finalConfidence: top1.score,
    );
  }

  /// Classify scrap image with custom TFLite in background Isolate,
  /// with top-k calibration and optional temporal multi-frame smoothing.
  Future<ClassificationResult> classifyImage(
    String imagePath, {
    bool useTemporalSmoothing = false,
  }) async {
    final useYolo = await SettingsService.instance.getUseYoloEngine();
    final customAvailable = useYolo && await isCustomModelAvailable();
    ClassificationResult rawResult;

    if (customAvailable) {
      try {
        final tfliteResult = await _classifyWithTFLite(imagePath);
        if (tfliteResult != null) {
          rawResult = tfliteResult;
        } else {
          rawResult = await _classifyWithMLKit(imagePath);
        }
      } catch (e) {
        rawResult = await _classifyWithMLKit(imagePath);
      }
    } else {
      rawResult = await _classifyWithMLKit(imagePath);
    }

    if (useTemporalSmoothing) {
      temporalBuffer.addFrame(rawResult);
      return temporalBuffer.getSmoothedResult();
    }

    return rawResult;
  }

  // ======================================================
  // TENSORFLOW LITE CLASSIFICATION IN ISOLATE
  // ======================================================

  Future<ClassificationResult?> _classifyWithTFLite(String imagePath) async {
    try {
      final candidateAssets = [
        'assets/models/yolov8n_float16.tflite',
        'assets/models/yolov8n.tflite',
        'assets/models/scrap_model.tflite',
      ];
      ByteData? modelData;
      for (final asset in candidateAssets) {
        try {
          modelData = await rootBundle.load(asset);
          break;
        } catch (_) {}
      }
      if (modelData == null) return null;

      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      final labels = labelsData
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      final modelBytes = modelData.buffer.asUint8List();

      // Run inference in a background isolate to keep UI smooth
      final rawResult = await Isolate.run(() {
        return _runTfliteInference(imageBytes, modelBytes, labels);
      });

      if (rawResult == null) return null;

      final rawTopK = (rawResult['topK'] as List)
          .map((item) => TopKPrediction(
                category: item['category'] as String,
                score: (item['score'] as num).toDouble(),
              ))
          .toList();

      final eval = evaluateConfidenceAndTopK(topK: rawTopK);

      final candidates = rawTopK.map((p) => p.toString()).toList();

      ImageLightingAssessment? lightingQuality;
      if (rawResult['lighting'] != null) {
        final m = rawResult['lighting'] as Map<String, dynamic>;
        lightingQuality = ImageLightingAssessment(
          averageLuminance: (m['avgLum'] as num).toDouble(),
          contrastStdDev: (m['stdDev'] as num).toDouble(),
          isDim: m['isDim'] as bool,
          isHarsh: m['isHarsh'] as bool,
          isLowContrast: m['isLowContrast'] as bool,
          advisory: m['advisory'] as String?,
        );
      }

      return ClassificationResult(
        category: eval.finalCategory,
        confidence: eval.finalConfidence,
        aiEngine: 'TensorFlow Lite (MobileNetV3)',
        isUncertain: eval.isUncertain,
        candidateLabels: candidates,
        topKPredictions: rawTopK,
        isBorderline: eval.isBorderline,
        lightingQuality: lightingQuality,
      );
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _runTfliteInference(
    Uint8List imageBytes,
    Uint8List modelBytes,
    List<String> labels,
  ) {
    try {
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      // 1. Lighting assessment
      final lighting = ImageLightingAssessment.analyze(decodedImage);

      // 2. Pre-processing: square-crop & resize
      final resized = preprocessImage(
        decodedImage,
        targetWidth: 224,
        targetHeight: 224,
        compensateLighting: true,
      );

      final interpreter = Interpreter.fromBuffer(modelBytes);
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      final int height = inputShape.length > 1 ? inputShape[1] : 224;
      final int width = inputShape.length > 2 ? inputShape[2] : 224;
      final int numClasses = outputShape.isNotEmpty ? outputShape.last : labels.length;

      // 3. Prepare normalized input tensor [1, 224, 224, 3] in [0, 1]
      final input = List.generate(
        1,
        (_) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final output = List.generate(1, (_) => List<double>.filled(numClasses, 0.0));
      interpreter.run(input, output);
      interpreter.close();

      final probabilities = output[0];

      // Extract top-k sorted predictions
      final List<MapEntry<int, double>> indexedScores = [];
      for (int i = 0; i < probabilities.length; i++) {
        indexedScores.add(MapEntry(i, probabilities[i]));
      }
      indexedScores.sort((a, b) => b.value.compareTo(a.value));

      final List<Map<String, dynamic>> topKList = [];
      for (int k = 0; k < math.min(3, indexedScores.length); k++) {
        final idx = indexedScores[k].key;
        final score = indexedScores[k].value;
        final label = idx < labels.length ? labels[idx] : 'Unknown';
        topKList.add({'category': label, 'score': score});
      }

      return {
        'topK': topKList,
        'lighting': {
          'avgLum': lighting.averageLuminance,
          'stdDev': lighting.contrastStdDev,
          'isDim': lighting.isDim,
          'isHarsh': lighting.isHarsh,
          'isLowContrast': lighting.isLowContrast,
          'advisory': lighting.advisory,
        },
      };
    } catch (e) {
      return null;
    }
  }

  // ======================================================
  // GOOGLE ML KIT OFFLINE CLASSIFICATION
  // ======================================================

  Future<ClassificationResult> _classifyWithMLKit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.30),
    );

    try {
      final labels = await imageLabeler.processImage(inputImage);

      // Lighting analysis on the file
      ImageLightingAssessment? lightingQuality;
      try {
        final bytes = await File(imagePath).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          lightingQuality = ImageLightingAssessment.analyze(decoded);
        }
      } catch (_) {}

      if (labels.isEmpty) {
        return ClassificationResult.uncertain(
          aiEngine: 'Google ML Kit (Offline)',
          lightingQuality: lightingQuality,
        );
      }

      double plasticScore = 0.0;
      double aluminumScore = 0.0;
      double paperCardboardScore = 0.0;
      double ironSteelScore = 0.0;
      double copperWiringScore = 0.0;
      double eWasteScore = 0.0;
      double glassScore = 0.0;

      final detectedNames = <String>[];

      for (final label in labels) {
        final name = label.label.toLowerCase();
        final score = label.confidence;
        detectedNames.add('${label.label} (${(score * 100).toStringAsFixed(0)}%)');

        // Plastic Bottle / PET
        if (name.contains('bottle') ||
            name == 'plastic' ||
            name.contains('container') ||
            name.contains('tableware') ||
            name.contains('polyethylene') ||
            name.contains('drinkware')) {
          if (score > plasticScore) plasticScore = score;
        }

        // Aluminum Can & Tins
        if (name.contains('aluminum') ||
            name.contains('aluminium') ||
            name.contains('can') ||
            name.contains('tin') ||
            name.contains('beverage can') ||
            name.contains('foil')) {
          if (score > aluminumScore) aluminumScore = score;
        }

        // Paper / Cardboard
        if (name.contains('paper') ||
            name.contains('cardboard') ||
            name.contains('carton') ||
            name.contains('newspaper') ||
            name.contains('corrugated') ||
            name.contains('publication')) {
          if (score > paperCardboardScore) paperCardboardScore = score;
        }

        // Iron & Steel
        if (name.contains('iron') ||
            name.contains('steel') ||
            name.contains('hardware') ||
            name.contains('tool') ||
            name.contains('appliance') ||
            name.contains('metal rod')) {
          if (score > ironSteelScore) ironSteelScore = score;
        }

        // Copper & Wiring
        if (name.contains('wire') ||
            name.contains('cable') ||
            name.contains('copper') ||
            name.contains('cord')) {
          if (score > copperWiringScore) copperWiringScore = score;
        }

        // E-Waste & Circuitry
        if (name.contains('electronic') ||
            name.contains('circuit') ||
            name.contains('hardware') ||
            name.contains('computer') ||
            name.contains('motherboard') ||
            name.contains('gadget') ||
            name.contains('phone')) {
          if (score > eWasteScore) eWasteScore = score;
        }

        // Glass Bottles
        if (name.contains('glass') ||
            name.contains('beer bottle') ||
            name.contains('wine bottle') ||
            name.contains('liquor')) {
          if (score > glassScore) glassScore = score;
        }
      }

      final Map<String, double> categoryScores = {
        'Plastic Bottle / PET': plasticScore,
        'Aluminum Can & Tins': aluminumScore,
        'Paper/Cardboard': paperCardboardScore,
        'Iron & Steel': ironSteelScore,
        'Copper & Wiring': copperWiringScore,
        'E-Waste & Circuitry': eWasteScore,
        'Glass Bottles': glassScore,
      };

      final List<TopKPrediction> topK = categoryScores.entries
          .map((e) => TopKPrediction(category: e.key, score: e.value))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final eval = evaluateConfidenceAndTopK(topK: topK);

      final candidateSummary = topK
          .where((p) => p.score > 0.15)
          .take(3)
          .map((p) => p.toString())
          .toList();

      return ClassificationResult(
        category: eval.finalCategory,
        confidence: eval.finalConfidence,
        aiEngine: 'Google ML Kit (Offline)',
        isUncertain: eval.isUncertain,
        candidateLabels: candidateSummary.isNotEmpty ? candidateSummary : detectedNames.take(3).toList(),
        topKPredictions: topK,
        isBorderline: eval.isBorderline,
        lightingQuality: lightingQuality,
      );
    } catch (e) {
      return ClassificationResult.uncertain(
        aiEngine: 'Google ML Kit (Offline)',
      );
    } finally {
      await imageLabeler.close();
    }
  }
}
