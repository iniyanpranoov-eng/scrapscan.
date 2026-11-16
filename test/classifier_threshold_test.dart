import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scrap_scan/core/constants/app_constants.dart';
import 'package:scrap_scan/services/ai_classifier_service.dart';

void main() {
  group('AI Classifier Confidence Calibration & Threshold Tests', () {
    test('Confidence threshold is strictly 65%', () {
      expect(AppConstants.confidenceThreshold, 0.65);
    });

    test('ClassificationResult.uncertain flags isUncertain', () {
      final uncertain = ClassificationResult.uncertain(
        confidence: 0.42,
        aiEngine: 'Google ML Kit (Offline)',
        candidates: ['Plastic (42%)', 'Tableware (35%)'],
      );

      expect(uncertain.isUncertain, isTrue);
      expect(uncertain.category, 'Uncertain / Unknown material');
      expect(uncertain.confidence, 0.42);
      expect(uncertain.candidateLabels.length, 2);
    });

    test('Confident result (>=65%) remains certain', () {
      const confident = ClassificationResult(
        category: 'Plastic Bottle / PET',
        confidence: 0.82,
        aiEngine: 'TensorFlow Lite (MobileNetV3)',
        isUncertain: false,
      );

      expect(confident.isUncertain, isFalse);
      expect(confident.category, 'Plastic Bottle / PET');
      expect(confident.confidence, greaterThanOrEqualTo(0.65));
    });

    test('Sub-65% confidence forces fallback to uncertain material', () {
      final eval = AIClassifierService.evaluateConfidenceAndTopK(
        topK: const [
          TopKPrediction(category: 'Plastic Bottle / PET', score: 0.62),
          TopKPrediction(category: 'Glass Bottles', score: 0.20),
        ],
        threshold: 0.65,
      );

      expect(eval.isUncertain, isTrue);
      expect(eval.finalCategory, 'Uncertain / Unknown material');
      expect(eval.finalConfidence, 0.62);
      expect(eval.isBorderline, isTrue);
    });

    test('Top-k borderline ambiguity check triggers fallback when top-2 predictions are very close', () {
      // Primary is 0.68 (above 0.65), but secondary is 0.64 (diff 0.04 < 0.12)
      final eval = AIClassifierService.evaluateConfidenceAndTopK(
        topK: const [
          TopKPrediction(category: 'Plastic Bottle / PET', score: 0.68),
          TopKPrediction(category: 'Glass Bottles', score: 0.64),
        ],
        threshold: 0.65,
      );

      expect(eval.isUncertain, isTrue);
      expect(eval.isBorderline, isTrue);
      expect(eval.finalCategory, 'Uncertain / Unknown material');
    });

    test('Top-k clearly separated predictions accept primary category', () {
      // Primary is 0.82 (clearly separated from secondary 0.15)
      final eval = AIClassifierService.evaluateConfidenceAndTopK(
        topK: const [
          TopKPrediction(category: 'Aluminum Can & Tins', score: 0.82),
          TopKPrediction(category: 'Iron & Steel', score: 0.15),
        ],
        threshold: 0.65,
      );

      expect(eval.isUncertain, isFalse);
      expect(eval.isBorderline, isFalse);
      expect(eval.finalCategory, 'Aluminum Can & Tins');
      expect(eval.finalConfidence, 0.82);
    });
  });

  group('Image Pre-processing & Lighting Assessment Tests', () {
    test('Image preprocess center-crops to 1:1 square aspect ratio and exact model dimensions', () {
      // Create a 16:9 non-square image (640x360)
      final nonSquare = img.Image(width: 640, height: 360);
      final processed = AIClassifierService.preprocessImage(
        nonSquare,
        targetWidth: 224,
        targetHeight: 224,
        compensateLighting: false,
      );

      expect(processed.width, 224);
      expect(processed.height, 224);
    });

    test('ImageLightingAssessment flags dim images accurately', () {
      // Create a dark image (all pixels near 10,10,10)
      final darkImage = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          darkImage.setPixelRgba(x, y, 15, 15, 15, 255);
        }
      }

      final assessment = ImageLightingAssessment.analyze(darkImage);
      expect(assessment.isDim, isTrue);
      expect(assessment.isHarsh, isFalse);
      expect(assessment.advisory, contains('Dim lighting'));
    });
  });

  group('Temporal Multi-Frame Voting & Smoothing Tests', () {
    test('TemporalClassifierBuffer stabilizes results across 3 frames with majority voting', () {
      final buffer = TemporalClassifierBuffer(windowSize: 3);

      // Frame 1: Aluminum (0.80)
      buffer.addFrame(const ClassificationResult(
        category: 'Aluminum Can & Tins',
        confidence: 0.80,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));

      // Frame 2: Iron & Steel (0.70) (transient flicker)
      buffer.addFrame(const ClassificationResult(
        category: 'Iron & Steel',
        confidence: 0.70,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));

      // Frame 3: Aluminum (0.84)
      buffer.addFrame(const ClassificationResult(
        category: 'Aluminum Can & Tins',
        confidence: 0.84,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));

      expect(buffer.count, 3);
      final smoothed = buffer.getSmoothedResult();

      // Majority: 2/3 Aluminum Can & Tins
      expect(smoothed.category, 'Aluminum Can & Tins');
      expect(smoothed.isUncertain, isFalse);
      expect(smoothed.confidence, closeTo(0.82, 0.01));
      expect(smoothed.aiEngine, contains('2/3 votes'));
    });

    test('TemporalClassifierBuffer flags uncertain when frames are split with no majority', () {
      final buffer = TemporalClassifierBuffer(windowSize: 3);

      buffer.addFrame(const ClassificationResult(
        category: 'Plastic Bottle / PET',
        confidence: 0.70,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));
      buffer.addFrame(const ClassificationResult(
        category: 'Glass Bottles',
        confidence: 0.70,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));
      buffer.addFrame(const ClassificationResult(
        category: 'Paper/Cardboard',
        confidence: 0.70,
        aiEngine: 'TFLite',
        isUncertain: false,
      ));

      final smoothed = buffer.getSmoothedResult();
      // No category reached 2 votes -> marked uncertain
      expect(smoothed.isUncertain, isTrue);
      expect(smoothed.category, 'Uncertain / Unknown material');
    });

    test('TemporalClassifierBuffer slides window removing oldest frame when exceeding windowSize', () {
      final buffer = TemporalClassifierBuffer(windowSize: 3);

      for (int i = 0; i < 5; i++) {
        buffer.addFrame(ClassificationResult(
          category: 'Category $i',
          confidence: 0.80,
          aiEngine: 'TFLite',
          isUncertain: false,
        ));
      }

      expect(buffer.count, 3);
      expect(buffer.frames.first.category, 'Category 2');
      expect(buffer.frames.last.category, 'Category 4');
    });
  });
}
