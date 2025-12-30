// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui';

// import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
// import 'package:color_detection_app/features/detection/domain/detection_result.dart';
// import 'package:color_detection_app/features/product_management/domain/product.dart';
// import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
// import 'package:opencv_dart/opencv_dart.dart' as cv;

// class ConeSearchAlgorithm extends DetectionAlgorithm {
//   @override
//   String get name => 'Vector Cone Search (v5.0 – Production)';

//   @override
//   String get description =>
//       'Production-ready algorithm with robust Mat handling and color spaces.';

//   // --- Config ---
//   final double coneGapPercent = 0.2;
//   final double coneHeightFactor = 3.7;

//   // --- Parameters (Fixed for Production) ---
//   final double brightnessThreshold =
//       95.0; // Dynamic default, overridden by adaptive
//   final double saturationThreshold = 40.0;
//   final double minContourArea = 10.0;
//   final double circularityThreshold = 0.35;

//   @override
//   Future<List<DetectionResult>> process(File image) async {
//     final inputImage = InputImage.fromFile(image);
//     final mat = cv.imread(image.path);

//     if (mat.isEmpty) {
//       return [
//         DetectionResult(
//           message: 'Failed to load image from path.',
//           algorithmName: name,
//         ),
//       ];
//     }

//     try {
//       return await processFrame(inputImage, mat);
//     } finally {
//       mat.dispose();
//     }
//   }

//   Future<List<DetectionResult>> processFrame(
//     InputImage inputImage,
//     cv.Mat mat,
//   ) async {
//     final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);

//     try {
//       final barcodes = await barcodeScanner.processImage(inputImage);

//       if (barcodes.isEmpty) {
//         return [
//           DetectionResult(message: 'No QR Code found.', algorithmName: name),
//         ];
//       }

//       final results = <DetectionResult>[];
//       for (final qr in barcodes) {
//         final corners = qr.cornerPoints;
//         if (corners.length != 4) continue;

//         final qrCorners = corners
//             .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
//             .toList();

//         // Pass a clone or ensure _processSingleCone doesn't dispose the input mat
//         // _processSingleCone DOES create region/clones so it should be safe.
//         final result = _processSingleCone(mat, qr.displayValue, qrCorners);
//         results.add(result);
//       }
//       return results;
//     } catch (e) {
//       debugPrint("Algorithm Error: $e");
//       return [DetectionResult(message: 'Error: $e', algorithmName: name)];
//     } finally {
//       barcodeScanner.close();
//     }
//   }

//   DetectionResult _processSingleCone(
//     cv.Mat fullImage,
//     String? qrValue,
//     List<Offset> qrCorners,
//   ) {
//     // --- 0. Geometry & Cone ---
//     final cone = _calculateCone(qrCorners);
//     if (cone.isEmpty) {
//       return _fail(qrValue, qrCorners, cone, "Invalid Geometry");
//     }

//     final tl = qrCorners[0];
//     final tr = qrCorners[1];
//     final topMidGlobal = (tl + tr) / 2.0;

//     // --- 1. Safe ROI Extraction ---
//     int minX = fullImage.cols, minY = fullImage.rows;
//     int maxX = 0, maxY = 0;
//     for (final p in cone) {
//       minX = math.min(minX, p.dx.toInt());
//       maxX = math.max(maxX, p.dx.toInt());
//       minY = math.min(minY, p.dy.toInt());
//       maxY = math.max(maxY, p.dy.toInt());
//     }
//     const pad = 20;
//     minX = (minX - pad).clamp(0, fullImage.cols);
//     minY = (minY - pad).clamp(0, fullImage.rows);
//     maxX = (maxX + pad).clamp(0, fullImage.cols);
//     maxY = (maxY + pad).clamp(0, fullImage.rows);
//     final w = maxX - minX;
//     final h = maxY - minY;

//     if (w <= 0 || h <= 0) return _fail(qrValue, qrCorners, cone, "Invalid ROI");

//     final roiMat = fullImage.region(cv.Rect(minX, minY, w, h));
//     cv.Mat? roiHsv;
//     cv.Mat? coneMask;
//     cv.Mat? brightMask;

//     try {
//       // --- 2. Pre-processing ---
//       // Apply Blur to reduce noise (matches Python)
//       final roiBlurred = cv.gaussianBlur(roiMat, (5, 5), 0);

//       // COLOR SPACE FIX:
//       // Standard OpenCV is BGR. We convert BGR -> HSV.
//       roiHsv = cv.cvtColor(roiBlurred, cv.COLOR_BGR2HSV);

//       roiBlurred.dispose();

//       // --- 3. Masks ---
//       coneMask = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
//       final localCone = cone
//           .map((p) => cv.Point((p.dx - minX).toInt(), (p.dy - minY).toInt()))
//           .toList();
//       final vecVec = cv.VecVecPoint.fromList([localCone]);
//       cv.fillPoly(coneMask, vecVec, cv.Scalar(255, 0, 0, 0));
//       vecVec.dispose();

//       // Adaptive Brightness
//       final channels = cv.split(roiHsv);
//       final vChannel = channels[2];

//       // Compute threshold using robust Mean+StdDev
//       final computedThresh = _computeSafeAdaptiveBrightness(vChannel, coneMask);

//       final (_, bMask) = cv.threshold(
//         vChannel,
//         computedThresh.toDouble(),
//         255,
//         cv.THRESH_BINARY,
//       );
//       brightMask = bMask;

//       // Disposal of channels
//       for (var c in channels) {
//         c.dispose();
//       }

//       // --- 4. Find Candidates ---
//       final candidates = <Map<String, dynamic>>[];
//       final s = saturationThreshold;
//       final v = computedThresh.toDouble();

//       void findCandidatesForColor(
//         String label,
//         List<List<double>> ranges,
//         StockStatus status,
//         Color visColor,
//       ) {
//         if (roiHsv == null || brightMask == null || coneMask == null) return;

//         cv.Mat? mask;

//         for (final range in ranges) {
//           final lower = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3);
//           lower.setTo(cv.Scalar(range[0], range[1], v, 0));

//           final upper = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3);
//           upper.setTo(cv.Scalar(range[3], range[4], range[5], 0));

//           final rng = cv.inRange(roiHsv, lower, upper);
//           lower.dispose();
//           upper.dispose();

//           if (mask == null) {
//             mask = rng;
//           } else {
//             final newMask = cv.bitwiseOR(mask, rng);
//             mask.dispose();
//             rng.dispose();
//             mask = newMask;
//           }
//         }

//         if (mask == null) return;

//         // Combine Masks
//         final tmp = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
//         cv.bitwiseAND(mask, brightMask, dst: tmp);
//         mask.dispose();

//         final finalMask = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
//         cv.bitwiseAND(tmp, coneMask, dst: finalMask);
//         tmp.dispose();

//         final (contours, hierarchy) = cv.findContours(
//           finalMask,
//           cv.RETR_EXTERNAL,
//           cv.CHAIN_APPROX_SIMPLE,
//         );
//         finalMask.dispose();

//         for (final contour in contours) {
//           final area = cv.contourArea(contour);
//           if (area > minContourArea) {
//             final perimeter = cv.arcLength(contour, true);
//             if (perimeter == 0) continue;

//             final circularity = (4 * math.pi * area) / (perimeter * perimeter);

//             if (circularity > circularityThreshold) {
//               final contourMat = cv.Mat.fromVec(contour);
//               final M = cv.moments(contourMat);
//               contourMat.dispose();

//               if (M.m00 != 0) {
//                 final cxLocal = M.m10 / M.m00;
//                 final cyLocal = M.m01 / M.m00;
//                 final globalCentroid = Offset(minX + cxLocal, minY + cyLocal);
//                 final dist = (globalCentroid - topMidGlobal).distance;

//                 candidates.add({
//                   'color': label,
//                   'status': status,
//                   'visColor': visColor,
//                   'dist': dist,
//                   'centroid': globalCentroid,
//                   'area': area,
//                   'circularity': circularity,
//                 });
//               }
//             }
//           }
//         }
//         contours.dispose();
//         hierarchy.dispose();
//       }

//       // --- Ranges ---
//       // Red
//       findCandidatesForColor(
//         "Red",
//         [
//           [0, 40, v, 13, 255, 255],
//           [160, 40, v, 180, 255, 255],
//         ],
//         StockStatus.outOfStock,
//         const Color(0xFFFF0000),
//       );

//       // Yellow
//       findCandidatesForColor(
//         "Yellow",
//         [
//           [20, s, v, 33, 255, 255],
//         ],
//         StockStatus.lowStock,
//         const Color(0xFFFFCC00),
//       );

//       // Green
//       findCandidatesForColor(
//         "Green",
//         [
//           [37, s, v, 85, 255, 255],
//         ],
//         StockStatus.inStock,
//         const Color(0xFF00FF00),
//       );

//       // --- Select Winner ---
//       if (candidates.isNotEmpty) {
//         candidates.sort(
//           (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
//         );
//         final winner = candidates.first;
//         return DetectionResult(
//           qrCode: qrValue,
//           qrCorners: qrCorners,
//           searchRegion: cone,
//           ledCentroid: winner['centroid'] as Offset,
//           detectedColor: winner['visColor'] as Color,
//           status: winner['status'] as StockStatus,
//           algorithmName: name,
//           message: "Found ${winner['status'].label} (${winner['color']})",
//         );
//       }

//       return _fail(qrValue, qrCorners, cone, "No active light found");
//     } finally {
//       roiMat.dispose();
//       roiHsv?.dispose();
//       coneMask?.dispose();
//       brightMask?.dispose();
//     }
//   }

//   // --- Safe Brightness Calculation ---
//   int _computeSafeAdaptiveBrightness(cv.Mat vChannel, cv.Mat mask) {
//     // Return tuple (mean, stddev)
//     final (meanScalar, stdDevScalar) = cv.meanStdDev(vChannel, mask: mask);

//     final meanVal = meanScalar.val1;
//     final stdVal = stdDevScalar.val1;

//     // Note: Scalar objects from meanStdDev in opencv_dart might interact with GC.
//     // If we dispose them, we might get double-free if the library handles it.
//     // Leaving them undisposed for now as they are small structs.

//     // Mean + 1.5 StdDev covers ~93% of normal distribution.
//     // LEDs are outliers above this.
//     double threshold = meanVal + (stdVal * 1.5);

//     return threshold.toInt().clamp(140, 220);
//   }

//   // --- Geometry Helpers (Unchanged) ---
//   List<Offset> _calculateCone(List<Offset> corners) {
//     if (corners.length < 4) return [];
//     final tl = corners[0];
//     final tr = corners[1];
//     final br = corners[2];
//     final bl = corners[3];
//     final topMid = (tl + tr) / 2.0;
//     final botMid = (bl + br) / 2.0;
//     final vecUp = topMid - botMid;
//     final h = vecUp.distance;
//     if (h == 0) return [];
//     final unitUp = vecUp / h;
//     final unitRight = Offset(-unitUp.dy, unitUp.dx);
//     final qrW = (tr - tl).distance;
//     final startCenter = topMid + (unitUp * (h * coneGapPercent));
//     final baseW = qrW * 1.5;
//     final topW = qrW * 2.5;
//     final len = h * coneHeightFactor;
//     return [
//       startCenter - (unitRight * (baseW / 2)),
//       startCenter + (unitUp * len) - (unitRight * (topW / 2)),
//       startCenter + (unitUp * len) + (unitRight * (topW / 2)),
//       startCenter + (unitRight * (baseW / 2)),
//     ];
//   }

//   DetectionResult _fail(
//     String? qr,
//     List<Offset> c,
//     List<Offset> cone,
//     String m,
//   ) => DetectionResult(
//     qrCode: qr,
//     qrCorners: c,
//     searchRegion: cone,
//     message: m,
//     algorithmName: name,
//   );
// }

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:color_detection_app/features/product_management/domain/product.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ConeSearchAlgorithm extends DetectionAlgorithm {
  @override
  String get name => 'Vector Cone Search (v5.3 – Noise Killer)';

  @override
  String get description =>
      'Strict saturation checks to eliminate fake red blobs.';

  final double coneGapPercent = 0.2;
  final double coneHeightFactor = 3.7;

  // --- TUNED PARAMETERS (Standardized for 1080p) ---
  final double brightnessThreshold = 150.0;
  // High saturation requirement eliminates gray background noise detected as red
  final double saturationThreshold = 95.0;
  final double minContourArea = 25.0;
  final double circularityThreshold = 0.65;

  @override
  Future<List<DetectionResult>> process(File image) async {
    final inputImage = InputImage.fromFile(image);
    final mat = cv.imread(image.path);
    if (mat.isEmpty) return [];
    try {
      return await processFrame(inputImage, mat);
    } finally {
      mat.dispose();
    }
  }

  Future<List<DetectionResult>> processFrame(
    InputImage inputImage,
    cv.Mat mat, {
    bool rotationFix = false,
    Size? rawSize,
  }) async {
    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      if (barcodes.isEmpty) {
        return [
          DetectionResult(message: 'No QR Code found.', algorithmName: name),
        ];
      }

      final results = <DetectionResult>[];
      for (final qr in barcodes) {
        final corners = qr.cornerPoints;
        if (corners.length != 4) continue;

        List<Offset> qrCorners = corners
            .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
            .toList();

        // --- COORDINATE MAPPING (The Geometry Fix) ---
        // ML Kit detected QRs in the RAW (Landscape) image.
        // We are processing a ROTATED (Portrait) image.
        // We must rotate the points 90deg Clockwise to match the image we are analyzing.
        // if (rotationFix && rawSize != null) {
        //   qrCorners = qrCorners.map((p) {
        //     // 90 deg clockwise: (x, y) -> (h - y, x)
        //     return Offset(rawSize.height - p.dy, p.dx);
        //   }).toList();
        // }

        final result = _processSingleCone(mat, qr.displayValue, qrCorners);
        results.add(result);
      }
      return results;
    } catch (e) {
      debugPrint("Algorithm Error: $e");
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
    // 1. Geometry
    final cone = _calculateCone(qrCorners);
    if (cone.isEmpty)
      return _fail(qrValue, qrCorners, cone, "Invalid Geometry");

    final tl = qrCorners[0];
    final tr = qrCorners[1];
    final topMidGlobal = (tl + tr) / 2.0;

    // 2. Safe ROI Extraction
    int minX = fullImage.cols, minY = fullImage.rows;
    int maxX = 0, maxY = 0;
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
    final w = maxX - minX;
    final h = maxY - minY;

    if (w <= 0 || h <= 0) return _fail(qrValue, qrCorners, cone, "Invalid ROI");

    final roiMat = fullImage.region(cv.Rect(minX, minY, w, h));
    cv.Mat? roiHsv;
    cv.Mat? coneMask;
    cv.Mat? brightMask;

    try {
      // 3. Pre-process (Blur)
      final roiBlurred = cv.gaussianBlur(roiMat, (5, 5), 0);
      roiHsv = cv.cvtColor(roiBlurred, cv.COLOR_BGR2HSV);
      roiBlurred.dispose();

      // 4. Masks
      coneMask = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
      final localCone = cone
          .map((p) => cv.Point((p.dx - minX).toInt(), (p.dy - minY).toInt()))
          .toList();
      final vecVec = cv.VecVecPoint.fromList([localCone]);
      cv.fillPoly(coneMask, vecVec, cv.Scalar(255, 0, 0, 0));
      vecVec.dispose();

      // Brightness
      final channels = cv.split(roiHsv);
      final vChannel = channels[2];
      final computedThresh = _computeSafeAdaptiveBrightness(vChannel, coneMask);

      final (_, bMask) = cv.threshold(
        vChannel,
        computedThresh.toDouble(),
        255,
        cv.THRESH_BINARY,
      );
      brightMask = bMask;
      for (var c in channels) c.dispose();

      // 5. Candidates Logic
      final candidates = <Map<String, dynamic>>[];

      // We use a high global saturation baseline
      final globalSat = saturationThreshold;
      final v = computedThresh.toDouble();

      void findCandidatesForColor(
        String label,
        List<List<double>> ranges,
        StockStatus status,
        Color visColor,
      ) {
        if (roiHsv == null || brightMask == null || coneMask == null) return;
        cv.Mat? mask;

        // --- STRICT RED FILTER ---
        // Grey/White pixels often register as Hue 0 (Red).
        // We force "Red" candidates to have VERY high saturation (> 100) to prove they are colorful.
        double effectiveSat = label == "Red" ? 100.0 : globalSat;

        for (final range in ranges) {
          final lower = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)
            ..setTo(cv.Scalar(range[0], effectiveSat, v, 0));
          final upper = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)
            ..setTo(cv.Scalar(range[3], range[4], range[5], 0));
          final rng = cv.inRange(roiHsv!, lower, upper);
          lower.dispose();
          upper.dispose();

          if (mask == null) {
            mask = rng;
          } else {
            final newMask = cv.bitwiseOR(mask, rng);
            mask.dispose();
            rng.dispose();
            mask = newMask;
          }
        }
        if (mask == null) return;

        final tmp = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
        cv.bitwiseAND(mask, brightMask!, dst: tmp);
        mask.dispose();

        final finalMask = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
        cv.bitwiseAND(tmp, coneMask!, dst: finalMask);
        tmp.dispose();

        // --- NOISE REMOVAL (Morphology) ---
        // Erode: Shrinks blobs (kills tiny noise).
        // Dilate: Expands them back (restores LED shape).
        final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
        final eroded = cv.erode(finalMask, kernel);
        final dilated = cv.dilate(eroded, kernel);
        finalMask.dispose();
        eroded.dispose();
        kernel.dispose();

        final (contours, hierarchy) = cv.findContours(
          dilated,
          cv.RETR_EXTERNAL,
          cv.CHAIN_APPROX_SIMPLE,
        );
        dilated.dispose();

        for (final contour in contours) {
          final area = cv.contourArea(contour);
          // Only accept significant blobs
          if (area > minContourArea) {
            final perimeter = cv.arcLength(contour, true);
            if (perimeter == 0) continue;
            final circularity = (4 * math.pi * area) / (perimeter * perimeter);

            if (circularity > circularityThreshold) {
              final contourMat = cv.Mat.fromVec(contour);
              final M = cv.moments(contourMat);
              contourMat.dispose();

              if (M.m00 != 0) {
                final cxLocal = M.m10 / M.m00;
                final cyLocal = M.m01 / M.m00;
                final globalCentroid = Offset(minX + cxLocal, minY + cyLocal);
                final dist = (globalCentroid - topMidGlobal).distance;
                // Get the saturation value of the pixel at the centroid

                candidates.add({
                  'color': label,
                  'status': status,
                  'visColor': visColor,
                  'dist': dist,
                  'centroid': globalCentroid,
                });
              }
            }
          }
        }
        contours.dispose();
        hierarchy.dispose();
      }

      // Ranges (H, S, V)
      findCandidatesForColor(
        "Red",
        [
          [0, globalSat, 150, 10, 255, 255],
          [160, globalSat, 180, 180, 255, 255],
        ],
        StockStatus.outOfStock,
        const Color(0xFFFF0000),
      );
      findCandidatesForColor(
        "Yellow",
        [
          [50, globalSat, 150, 65, 255, 255],
        ],
        StockStatus.lowStock,
        const Color(0xFFFFCC00),
      );
      findCandidatesForColor(
        "Green",
        [
          [70, globalSat, 150, 100, 255, 255],
        ],
        StockStatus.inStock,
        const Color(0xFF00FF00),
      );

      if (candidates.isNotEmpty) {
        // Tie-breaker: Closest to QR code center
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
          message: "${winner['status'].label} (${winner['color']})",
        );
      }
      return _fail(qrValue, qrCorners, cone, "No active light found");
    } finally {
      roiMat.dispose();
      roiHsv?.dispose();
      coneMask?.dispose();
      brightMask?.dispose();
    }
  }

  // --- Helpers ---
  int _computeSafeAdaptiveBrightness(cv.Mat vChannel, cv.Mat mask) {
    final (meanScalar, stdDevScalar) = cv.meanStdDev(vChannel, mask: mask);
    double threshold = meanScalar.val1 + (stdDevScalar.val1 * 2.0);
    return threshold.toInt().clamp(140, 220);
  }

  List<Offset> _calculateCone(List<Offset> corners) {
    if (corners.length < 4) return [];
    final tl = corners[0];
    final tr = corners[1];
    final br = corners[2];
    final bl = corners[3];
    final topMid = (tl + tr) / 2.0;
    final botMid = (bl + br) / 2.0;
    final vecUp = topMid - botMid;
    final h = vecUp.distance;
    if (h == 0) return [];
    final unitUp = vecUp / h;
    final unitRight = Offset(-unitUp.dy, unitUp.dx);
    final qrW = (tr - tl).distance;
    final startCenter = topMid + (unitUp * (h * coneGapPercent));
    final baseW = qrW * 1.5;
    final topW = qrW * 2.5;
    final len = h * coneHeightFactor;
    return [
      startCenter - (unitRight * (baseW / 2)),
      startCenter + (unitUp * len) - (unitRight * (topW / 2)),
      startCenter + (unitUp * len) + (unitRight * (topW / 2)),
      startCenter + (unitRight * (baseW / 2)),
    ];
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
