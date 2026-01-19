import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:color_detection_app/features/detection/data/calibration_repository.dart';
import 'package:color_detection_app/features/detection/domain/cone_calibration_settings.dart';
import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:color_detection_app/features/product_management/domain/product.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ConeSearchAlgorithm extends DetectionAlgorithm {
  @override
  String get name => 'Vector Cone Search (v6.0 – Homography & Robust)';

  @override
  String get description =>
      'Uses perspective projection for accurate 3D cone placement and dynamic thresholds for LED detection.';

  // --- Config ---
  final double coneGapPercent = 0.2;
  final double coneHeightFactor = 3.9;

  // --- Parameters ---
  // Note: brightnessThreshold is dynamic.
  // circularity and minArea are now relative/stricter.
  final double saturationThreshold =
      15.0; // Lowered to catch dim/small LEDs better
  final double strictCircularity = 0.30; // Relaxed slightly for small LEDs

  // Calibration settings (loaded at runtime)
  ConeCalibrationSettings _settings = const ConeCalibrationSettings();

  /// Loads calibration settings from repository
  Future<void> _loadCalibrationSettings() async {
    try {
      final repo = CalibrationRepository();
      _settings = await repo.getSettings();
    } catch (e) {
      debugPrint('Failed to load calibration settings: $e');
      _settings = const ConeCalibrationSettings();
    }
  }

  @override
  Future<List<DetectionResult>> process(File image) async {
    // Load calibration settings before processing
    await _loadCalibrationSettings();

    final inputImage = InputImage.fromFile(image);
    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    final results = <DetectionResult>[];

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return [
          DetectionResult(message: 'No QR Code found.', algorithmName: name),
        ];
      }

      // Read image bytes and decode with OpenCV (more portable than imread on iOS)
      final imageBytes = await image.readAsBytes();
      final mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (mat.isEmpty) {
        debugPrint('OpenCV imdecode failed for path: ${image.path}');
        return [
          DetectionResult(
            message: 'Failed to load image from path.',
            algorithmName: name,
          ),
        ];
      }

      try {
        for (final qr in barcodes) {
          final corners = qr.cornerPoints;
          if (corners.length != 4) continue;

          final qrCorners = corners
              .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
              .toList();

          final result = _processSingleCone(mat, qr.displayValue, qrCorners);
          results.add(result);
        }
        return results;
      } finally {
        mat.dispose();
      }
    } catch (e) {
      debugPrint("Algorithm Error: $e");
      return [DetectionResult(message: 'Error: $e', algorithmName: name)];
    } finally {
      barcodeScanner.close();
    }
  }

  /// Processes raw JPEG bytes directly for real-time detection (no file I/O).
  ///
  /// [jpegBytes] - Raw JPEG image bytes
  /// [width] - Image width in pixels
  /// [height] - Image height in pixels
  Future<List<DetectionResult>> processFromBytes(
    Uint8List jpegBytes,
    int width,
    int height,
  ) async {
    // Load calibration settings before processing
    await _loadCalibrationSettings();

    final inputImage = InputImage.fromBytes(
      bytes: jpegBytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21, // JPEG decoded to NV21
        bytesPerRow: width,
      ),
    );
    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    final results = <DetectionResult>[];

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return [
          DetectionResult(message: 'No QR Code found.', algorithmName: name),
        ];
      }

      // Decode JPEG bytes to cv.Mat
      final mat = cv.imdecode(jpegBytes, cv.IMREAD_COLOR);
      if (mat.isEmpty) {
        return [
          DetectionResult(
            message: 'Failed to decode image bytes.',
            algorithmName: name,
          ),
        ];
      }

      try {
        for (final qr in barcodes) {
          final corners = qr.cornerPoints;
          if (corners.length != 4) continue;

          final qrCorners = corners
              .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
              .toList();

          final result = _processSingleCone(mat, qr.displayValue, qrCorners);
          results.add(result);
        }
        return results;
      } finally {
        mat.dispose();
      }
    } catch (e) {
      debugPrint("Algorithm Error (bytes): $e");
      return [DetectionResult(message: 'Error: $e', algorithmName: name)];
    } finally {
      barcodeScanner.close();
    }
  }

  /// Processes raw BGRA pixel data directly for iOS (no JPEG compression).
  /// This provides better accuracy than JPEG as there's no lossy compression.
  ///
  /// [bgraBytes] - Raw BGRA pixel data (4 bytes per pixel, already stride-stripped)
  /// [width] - Image width in pixels
  /// [height] - Image height in pixels
  Future<List<DetectionResult>> processFromBgra(
    Uint8List bgraBytes,
    int width,
    int height,
  ) async {
    // Create InputImage for ML Kit barcode scanning
    // ML Kit on iOS supports BGRA8888 format directly
    final inputImage = InputImage.fromBytes(
      bytes: bgraBytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: width * 4, // 4 bytes per pixel for BGRA
      ),
    );
    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    final results = <DetectionResult>[];

    // Load calibration settings before processing
    await _loadCalibrationSettings();

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return [
          DetectionResult(message: 'No QR Code found.', algorithmName: name),
        ];
      }

      // Convert BGRA to BGR for OpenCV (OpenCV uses BGR format)
      // Remove alpha channel: BGRA -> BGR
      final bgrBytes = Uint8List(width * height * 3);
      for (int i = 0; i < width * height; i++) {
        final bgraOffset = i * 4;
        final bgrOffset = i * 3;
        bgrBytes[bgrOffset] = bgraBytes[bgraOffset]; // B
        bgrBytes[bgrOffset + 1] = bgraBytes[bgraOffset + 1]; // G
        bgrBytes[bgrOffset + 2] = bgraBytes[bgraOffset + 2]; // R
      }

      // Create OpenCV Mat from BGR bytes
      final mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
      if (mat.isEmpty) {
        return [
          DetectionResult(
            message: 'Failed to create Mat from BGRA bytes.',
            algorithmName: name,
          ),
        ];
      }

      try {
        for (final qr in barcodes) {
          final corners = qr.cornerPoints;
          if (corners.length != 4) continue;

          final qrCorners = corners
              .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
              .toList();

          final result = _processSingleCone(mat, qr.displayValue, qrCorners);
          results.add(result);
        }
        return results;
      } finally {
        mat.dispose();
      }
    } catch (e) {
      debugPrint("Algorithm Error (BGRA): $e");
      return [DetectionResult(message: 'Error: $e', algorithmName: name)];
    } finally {
      barcodeScanner.close();
    }
  }

  DetectionResult _processSingleCone(
    cv.Mat fullImage,
    String? qrValue,
    List<Offset> qrCorners,
  ) {
    // --- 0. Geometry & Cone ---
    final cone = _calculateCone(qrCorners);

    // Bounds Check
    bool allOutside = cone.every(
      (p) =>
          p.dx < 0 ||
          p.dx > fullImage.cols ||
          p.dy < 0 ||
          p.dy > fullImage.rows,
    );
    if (cone.isEmpty || allOutside) {
      return _fail(qrValue, qrCorners, cone, "Target region off-screen");
    }

    // Dynamic Area Calculation (0.5% of QR area)
    final qrHeight = (qrCorners[3] - qrCorners[0]).distance;
    final dynamicMinArea = 10.0;

    // Distance Constraints
    final minLedDist = qrHeight * 2.0;
    final maxLedDist = qrHeight * 3.5;

    // --- 1. Extract ROI ---
    int minX = fullImage.cols, minY = fullImage.rows, maxX = 0, maxY = 0;
    for (final p in cone) {
      minX = math.min(minX, p.dx.toInt());
      maxX = math.max(maxX, p.dx.toInt());
      minY = math.min(minY, p.dy.toInt());
      maxY = math.max(maxY, p.dy.toInt());
    }
    const pad = 20;
    minX = (minX - pad).clamp(0, fullImage.cols);
    minY = (minY - pad).clamp(0, fullImage.rows);
    maxX = (maxX + pad).clamp(0, fullImage.cols);
    maxY = (maxY + pad).clamp(0, fullImage.rows);
    final roiMat = fullImage.region(
      cv.Rect(minX, minY, maxX - minX, maxY - minY),
    );

    cv.Mat? roiHsv;
    cv.Mat? mask;
    cv.Mat? vChannel;
    // KEEPING THESE FOR REUSE
    cv.Mat? sChannel;
    cv.Mat? satMask;

    try {
      // --- 2. Pre-processing ---
      final roiBlurred = cv.gaussianBlur(roiMat, (5, 5), 0);
      roiHsv = cv.cvtColor(roiBlurred, cv.COLOR_BGR2HSV);
      roiBlurred.dispose();

      // --- 3. Cone Mask ---
      final coneMask = cv.Mat.zeros(
        roiMat.rows,
        roiMat.cols,
        cv.MatType.CV_8UC1,
      );
      final localCone = cone
          .map((p) => cv.Point((p.dx - minX).toInt(), (p.dy - minY).toInt()))
          .toList();
      final vecVec = cv.VecVecPoint.fromList([localCone]);
      cv.fillPoly(coneMask, vecVec, cv.Scalar(255, 0, 0, 0));
      vecVec.dispose();

      // --- 4. INTENSITY-FIRST DETECTION ---

      // A. Extract Channels
      final channels = cv.split(roiHsv);
      // STORE H and S for later
      final hChannel = channels[0];
      sChannel = channels[1];
      vChannel = channels[2];

      // Dispose H immediately if not needed? No, we need it implicitly in roiHsv.
      // Actually cv.split creates copies, so we can dispose hChannel if we only use roiHsv later.
      // BUT we need sChannel for the Halo Mask.
      hChannel.dispose();

      // B. Compute Threshold
      final (meanS, stdS) = cv.meanStdDev(vChannel, mask: coneMask);
      double threshVal = meanS.val1 + (stdS.val1 * 2.0);
      threshVal = threshVal.clamp(160.0, 240.0);

      // C. Create "Bright Objects" Mask
      final (_, brightMask) = cv.threshold(
        vChannel,
        threshVal,
        255,
        cv.THRESH_BINARY,
      );

      // D. Apply Cone Mask
      mask = cv.Mat.zeros(roiMat.rows, roiMat.cols, cv.MatType.CV_8UC1);
      cv.bitwiseAND(brightMask, coneMask, dst: mask);
      brightMask.dispose();
      coneMask.dispose();

      // PRE-CALCULATE HALO MASK: Find pixels that are actually colorful
      // Threshold Saturation > 40. This filters out the white core (S ~ 0-10).
      satMask = cv.Mat.zeros(roiMat.rows, roiMat.cols, cv.MatType.CV_8UC1);
      cv.threshold(sChannel, 40, 255, cv.THRESH_BINARY, dst: satMask);

      // --- 5. Analyze Candidates ---
      final (contours, hierarchy) = cv.findContours(
        mask,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );

      final candidates = <Map<String, dynamic>>[];
      final topMidGlobal = (qrCorners[0] + qrCorners[1]) / 2.0;

      for (final contour in contours) {
        final area = cv.contourArea(contour);
        if (area < dynamicMinArea) continue;

        final perimeter = cv.arcLength(contour, true);
        if (perimeter == 0) continue;
        final circularity = (4 * math.pi * area) / (perimeter * perimeter);

        if (circularity > 0.25) {
          final M = cv.moments(cv.Mat.fromVec(contour));
          if (M.m00 == 0) continue;
          final cx = M.m10 / M.m00;
          final cy = M.m01 / M.m00;
          final globalCentroid = Offset(minX + cx, minY + cy);

          final dist = (globalCentroid - topMidGlobal).distance;

          if (dist < minLedDist || dist > maxLedDist) continue;

          // 1. Basic Blob Mask
          final singleLedMask = cv.Mat.zeros(
            roiMat.rows,
            roiMat.cols,
            cv.MatType.CV_8UC1,
          );
          final cVec = cv.VecVecPoint.fromList([contour.toList()]);
          cv.drawContours(
            singleLedMask,
            cVec,
            -1,
            cv.Scalar(255, 0, 0, 0),
            thickness: -1,
          );
          cVec.dispose();

          // 2. SMART SAMPLING: Intersect Blob with High-Saturation Mask
          // We only want the average color of the "Halo", not the white core.
          final samplingMask = cv.Mat.zeros(
            roiMat.rows,
            roiMat.cols,
            cv.MatType.CV_8UC1,
          );
          cv.bitwiseAND(singleLedMask, satMask!, dst: samplingMask);

          // Fallback: If the LED is very pale (entirely S < 40), samplingMask is empty.
          // In that case, use the whole blob (singleLedMask).
          final validPixels = cv.countNonZero(samplingMask);
          final maskToUse = (validPixels > 0) ? samplingMask : singleLedMask;

          // Calculate average color in HSV (for saturation check)
          final meanColorHsv = cv.mean(roiHsv, mask: maskToUse);

          // Calculate LAB average color (for classification)
          final roiLab = cv.cvtColor(roiMat, cv.COLOR_BGR2Lab);
          final meanColorLab = cv.mean(roiLab, mask: maskToUse);
          roiLab.dispose();

          // Clean up masks AFTER using them
          singleLedMask.dispose();
          samplingMask.dispose();

          final double s = meanColorHsv.val2; // Saturation from HSV

          // We require Saturation > 10 to avoid white/glare (lowered for dim LEDs).
          if (s > 10) {
            StockStatus? status;
            String colorLabel = "Unknown";
            Color visColor = const Color(0xFF000000);

            // === LAB COLOR SPACE CLASSIFICATION ===
            // LAB is better for distinguishing yellow from green
            // L = Lightness (0-255), A = Green-Red (-128 to 127), B = Blue-Yellow (-128 to 127)
            // In OpenCV: L (0-255), A (0-255 where 128=0), B (0-255 where 128=0)

            // Note: meanColorLab.val1 is Lightness (not used for classification)
            // final double labA =
            //     meanColorLab.val2; // Green(-) to Red(+), centered at 128
            // final double labB =
            //     meanColorLab.val3; // Blue(-) to Yellow(+), centered at 128

            // Convert to signed values (-128 to 127 range)
            // final double a = labA - 128; // Negative = green, Positive = red
            // final double b = labB - 128; // Negative = blue, Positive = yellow

            // DEBUG: Uncomment to see LAB values
            // debugPrint("LAB -> L: ${labL.toStringAsFixed(1)} | a: ${a.toStringAsFixed(1)} | b: ${b.toStringAsFixed(1)}");

            // Classification based on LAB:
            // RED: High positive 'a' value (red component)
            // YELLOW: Low/neutral 'a', high positive 'b' (yellow component)
            // GREEN: Negative 'a' value (green component), moderate 'b'

            // if (a > 20) {
            //   // Strong red component
            //   status = StockStatus.outOfStock;
            //   colorLabel = "Red";
            //   visColor = const Color(0xFFFF0000);
            // } else if (a < 5 && b > 30) {
            //   // Low red, strong yellow - this is YELLOW
            //   status = StockStatus.lowStock;
            //   colorLabel = "Yellow";
            //   visColor = const Color(0xFFFFFF00);
            // } else if (a < -5 && b > -10 && b < 40) {
            //   // Negative 'a' (greenish), moderate 'b'
            //   status = StockStatus.inStock;
            //   colorLabel = "Green";
            //   visColor = const Color(0xFF00FF00);
            // }

            //=== HSV CLASSIFICATION (BACKUP) ===
            final double h = meanColorHsv.val1;

            // RED: 0-15 or 160-180
            if (h < 15 || h > 160) {
              status = StockStatus.outOfStock;
              colorLabel = "Red";
              visColor = const Color(0xFFFF0000);
            }
            // YELLOW: 18-28
            else if (h >= 18 && h <= 30) {
              status = StockStatus.lowStock;
              colorLabel = "Yellow";
              visColor = const Color(0xFFFFFF00);
            }
            // GREEN: 31-95
            else if (h >= 33 && h < 95) {
              status = StockStatus.inStock;
              colorLabel = "Green";
              visColor = const Color(0xFF00FF00);
            }
            // === END HSV BACKUP ===

            if (status != null) {
              candidates.add({
                'dist': dist,
                'status': status,
                'color': colorLabel,
                'visColor': visColor,
                'centroid': globalCentroid,
              });
            }
          }
        }
      }
      contours.dispose();
      hierarchy.dispose();

      // ... Winner Selection (Same as before) ...
      if (candidates.isNotEmpty) {
        candidates.sort(
          (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
        );
        final winner = candidates.first;
        return DetectionResult(
          qrCode: qrValue,
          qrCorners: qrCorners,
          searchRegion: cone,
          ledCentroid: winner['centroid'] as Offset,
          detectedColor: winner['visColor'] as Color,
          status: winner['status'] as StockStatus,
          algorithmName: name,
          message: "Found ${winner['status'].label} (${winner['color']})",
        );
      }

      return _fail(qrValue, qrCorners, cone, "No active light found");
    } finally {
      roiMat.dispose();
      roiHsv?.dispose();
      mask?.dispose();
      vChannel?.dispose();
      sChannel?.dispose(); // Don't forget to dispose
      satMask?.dispose();
    }
  }

  // --- 0. Geometry & Cone (Revised with Homography + Calibration) ---
  List<Offset> _calculateCone(List<Offset> corners) {
    if (corners.length != 4) return [];

    // CONSTANT: Scale ideal world up by 1000 to preserve precision with Integers
    const double scale = 1000.0;

    // Apply calibration settings
    final heightMultiplier = _settings.heightMultiplier;
    final rotationAngle = _settings.rotationAngle;

    // 1. Destination: Actual QR corners (Screen Pixels)
    // We cast to Int (VecPoint) as required by the library.
    // Loss of <1px precision here is acceptable.
    final destVec = cv.VecPoint.fromList(
      corners.map((o) => cv.Point(o.dx.toInt(), o.dy.toInt())).toList(),
    );

    // 2. Source: Ideal Square scaled to 1000x1000
    // (0,0), (1000,0), (1000,1000), (0,1000)
    final srcVec = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point((1.0 * scale).toInt(), 0),
      cv.Point((1.0 * scale).toInt(), (1.0 * scale).toInt()),
      cv.Point(0, (1.0 * scale).toInt()),
    ]);

    cv.Mat? M;
    cv.Mat? idealConeMat;
    cv.Mat? imageConeMat;
    cv.VecPoint2f? vecRes;

    try {
      // 3. Calculate Homography using Integers
      // Maps "1000x World" -> "Screen Pixels"
      M = cv.getPerspectiveTransform(srcVec, destVec);

      // 4. Define Cone in "1000x World" (before rotation)
      // We multiply all our ratio constants by `scale`
      const double gapRatio = -0.2; // 20% gap
      final double endRatio =
          -0.2 - (3.9 * heightMultiplier); // Height with calibration
      const double baseHalfW = (1.5 / 2.0) * scale;
      const double topHalfW = (2.5 / 2.0) * scale;
      const double centerX = 0.5 * scale;
      const double centerY = 0.5 * scale; // QR center for rotation

      // Cone points relative to center (before rotation)
      final unrotatedPoints = [
        cv.Point2f(-baseHalfW, gapRatio * scale - centerY),
        cv.Point2f(-topHalfW, endRatio * scale - centerY),
        cv.Point2f(topHalfW, endRatio * scale - centerY),
        cv.Point2f(baseHalfW, gapRatio * scale - centerY),
      ];

      // Apply rotation around center
      final radians = rotationAngle * math.pi / 180;
      final rotatedPoints = unrotatedPoints.map((p) {
        final rotatedX = p.x * math.cos(radians) - p.y * math.sin(radians);
        final rotatedY = p.x * math.sin(radians) + p.y * math.cos(radians);
        return cv.Point2f(centerX + rotatedX, centerY + rotatedY);
      }).toList();

      // 5. Transform
      // Even though M was made with Ints, it works on Floats for the projection.
      idealConeMat = cv.Mat.fromVec(cv.VecPoint2f.fromList(rotatedPoints));
      imageConeMat = cv.perspectiveTransform(idealConeMat, M);

      // 6. Extract results (Screen Pixels)
      vecRes = cv.VecPoint2f.fromMat(imageConeMat);

      return vecRes.toList().map((p) => Offset(p.x, p.y)).toList();
    } finally {
      srcVec.dispose();
      destVec.dispose();
      M?.dispose();
      idealConeMat?.dispose();
      imageConeMat?.dispose();
      vecRes?.dispose();
    }
  }

  DetectionResult _fail(
    String? qr,
    List<Offset> c,
    List<Offset> cone,
    String m,
  ) => DetectionResult(
    qrCode: qr,
    qrCorners: c,
    searchRegion: cone,
    message: m,
    algorithmName: name,
  );
}
