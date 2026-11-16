import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/detected_object.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final List<DetectedObject> objects;
  final Size? imageSize;

  const BoundingBoxOverlay({
    super.key,
    required this.objects,
    this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    if (objects.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BoundingBoxPainter(objects: objects),
        );
      },
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<DetectedObject> objects;

  _BoundingBoxPainter({required this.objects});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final rect = Rect.fromLTWH(
        obj.boundingBox.left * size.width,
        obj.boundingBox.top * size.height,
        obj.boundingBox.width * size.width,
        obj.boundingBox.height * size.height,
      );

      final color = _getColorForCategory(obj.category);

      // 1. Draw box background tint
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        fillPaint,
      );

      // 2. Draw outer border
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        borderPaint,
      );

      // 3. Draw high-tech YOLO Viewfinder Corner Reticles
      final cornerLength = math.min(16.0, math.min(rect.width, rect.height) / 4);
      final cornerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round;

      // Top-Left corner
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength), cornerPaint);

      // Top-Right corner
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), cornerPaint);

      // Bottom-Left corner
      canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength), cornerPaint);

      // Bottom-Right corner
      canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);

      // 4. Draw top-left label chip with class label and confidence percentage tag
      final labelText = '${obj.category} • ${(obj.confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = textPainter.width + 14;
      final chipHeight = textPainter.height + 7;
      final chipRect = Rect.fromLTWH(
        rect.left,
        rect.top >= chipHeight + 4 ? rect.top - chipHeight - 2 : rect.top + 4,
        chipWidth,
        chipHeight,
      );

      // Chip shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect.translate(0, 1), const Radius.circular(6)),
        shadowPaint,
      );

      // Chip background
      final chipPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
        chipPaint,
      );

      // Chip text
      textPainter.paint(
        canvas,
        Offset(chipRect.left + 7, chipRect.top + 3.5),
      );
    }
  }

  Color _getColorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plastic')) return Colors.teal.shade700;
    if (lower.contains('aluminum') || lower.contains('metal')) return Colors.blue.shade700;
    if (lower.contains('paper') || lower.contains('cardboard')) return Colors.orange.shade800;
    if (lower.contains('iron') || lower.contains('steel')) return Colors.blueGrey.shade800;
    if (lower.contains('copper')) return Colors.deepOrange.shade700;
    if (lower.contains('e-waste')) return Colors.purple.shade700;
    if (lower.contains('glass')) return Colors.cyan.shade800;
    return Colors.green.shade700;
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.objects != objects;
  }
}
