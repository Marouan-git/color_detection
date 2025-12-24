import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:flutter/material.dart';

class DetectionResultPainter extends CustomPainter {
  final List<DetectionResult> results;
  final Size imageSize;

  const DetectionResultPainter({
    required this.results,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Use common scale for aspect ratio if using BoxFit.contain (which matches the Image widget)
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Offsets to center the content
    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;

    for (final result in results) {
      _paintResult(canvas, scale, offsetX, offsetY, result);
    }
  }

  void _paintResult(
    Canvas canvas,
    double scale,
    double offsetX,
    double offsetY,
    DetectionResult result,
  ) {
    void drawPath(List<Offset> points, Paint paint, {bool close = true}) {
      if (points.isEmpty) return;
      final path = Path();
      final p0 = points[0] * scale + Offset(offsetX, offsetY);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < points.length; i++) {
        final p = points[i] * scale + Offset(offsetX, offsetY);
        path.lineTo(p.dx, p.dy);
      }
      if (close) path.close();
      canvas.drawPath(path, paint);
    }

    // 1. Draw QR Corners (Blue)
    if (result.qrCorners.isNotEmpty) {
      final paintQr = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      drawPath(result.qrCorners, paintQr);

      // Draw Label
      if (result.qrCode != null) {
        final p0 = result.qrCorners[0] * scale + Offset(offsetX, offsetY);
        final textPainter = TextPainter(
          text: TextSpan(
            text: result.qrCode,
            style: const TextStyle(
              color: Colors.blue,
              backgroundColor: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, p0 - Offset(0, 20));
      }
    }

    // 2. Draw Search Region / Cone (Faint White)
    if (result.searchRegion.isNotEmpty) {
      final paintConeFill = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final paintConeBorder = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      drawPath(result.searchRegion, paintConeFill);
      drawPath(result.searchRegion, paintConeBorder);
    }

    // 3. Draw Detected LED (Circle)
    if (result.ledCentroid != null) {
      final center = result.ledCentroid! * scale + Offset(offsetX, offsetY);
      final paintLed = Paint()
        ..color = result.detectedColor ?? Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      canvas.drawCircle(center, 20 * scale, paintLed); // Ring

      final paintLedFill = Paint()
        ..color = (result.detectedColor ?? Colors.red).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 20 * scale, paintLedFill); // Fill
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
