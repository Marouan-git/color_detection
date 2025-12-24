import 'dart:io';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';

/// Abstract strategy for detecting QR codes and sensor status from an image.
///
/// Implementations can define different approaches (e.g., Vector Cone,
/// Machine Learning, fixed offset, etc.).
abstract class DetectionAlgorithm {
  /// A human-readable name for this algorithm (for UI selection).
  String get name;

  /// A brief description of how this algorithm works (for UI info).
  String get description;

  /// Processes the given [image] file and returns a list of [DetectionResult].
  ///
  /// This method should handle parsing the QR code and finding the
  /// corresponding status light.
  Future<List<DetectionResult>> process(File image);
}
