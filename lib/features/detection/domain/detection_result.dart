import 'dart:ui';
import 'package:color_detection_app/features/product_management/domain/product.dart';

/// Represents the outcome of a detection algorithm processing a single image.
class DetectionResult {
  /// The decoded QR code data (Product ID), if found.
  final String? qrCode;

  /// The coordinates of the QR code corners in the image.
  /// Usually 4 points: TopLeft, TopRight, BottomRight, BottomLeft.
  final List<Offset> qrCorners;

  /// The definition of the search region (e.g. the "Cone").
  /// Used for visualization only.
  final List<Offset> searchRegion;

  /// The centroid of the detected LED blob.
  final Offset? ledCentroid;

  /// The detected color of the LED (for visualization/debugging).
  final Color? detectedColor;

  /// The inferred stock status based on the color.
  final StockStatus? status;

  /// Any debug or error message (e.g., "QR found but no light detected").
  final String? message;

  /// The name of the algorithm used.
  final String? algorithmName;

  DetectionResult({
    this.qrCode,
    this.qrCorners = const [],
    this.searchRegion = const [],
    this.ledCentroid,
    this.detectedColor,
    this.status,
    this.message,
    this.algorithmName,
  });

  bool get hasQr => qrCode != null;
  bool get hasStatus => status != null;
}
