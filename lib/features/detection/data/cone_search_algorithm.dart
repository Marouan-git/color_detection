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
      20.0; // Lowered slightly to catch washed-out LEDs
  final double strictCircularity = 0.35;

  @override
  Future<List<DetectionResult>> process(File image) async {
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
    //final qrWidth = (qrCorners[1] - qrCorners[0]).distance;
    final qrHeight = (qrCorners[3] - qrCorners[0]).distance; // TL to BL
    final dynamicMinArea = 10.0; //(qrWidth * qrWidth) * 0.0007;

    // NEW: Distance Constraints
    // Min: 90% of QR height (avoids detecting the QR itself or close reflections)
    // Max: 350% of QR height (avoids detecting lights far in the background)
    final minLedDist = qrHeight * 2.0;
    final maxLedDist = qrHeight * 3.5;

    // --- 1. Extract ROI ---
    // (Standard ROI extraction code here - kept brief for readability)
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

      // A. Extract Value Channel
      final channels = cv.split(roiHsv);
      vChannel = channels[2];
      channels[0].dispose();
      channels[1].dispose();

      // B. Compute Threshold
      // We look for things that are SIGNIFICANTLY brighter than the background
      final (meanS, stdS) = cv.meanStdDev(vChannel, mask: coneMask);
      double threshVal = meanS.val1 + (stdS.val1 * 2.0); // Strict threshold
      threshVal = threshVal.clamp(160.0, 240.0); // Sanity clamps

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
        if (area < dynamicMinArea) {
          debugPrint("Area too small: $area");
          continue;
        }

        final perimeter = cv.arcLength(contour, true);
        if (perimeter == 0) continue;
        final circularity = (4 * math.pi * area) / (perimeter * perimeter);

        // Strict circularity because LEDs are round light sources
        if (circularity > 0.35) {
          // --- 6. COLOR SAMPLING (The "Better" Part) ---
          // We don't guess the color. We ASK the blob what color it is.
          // Calculate centroid for distance sorting
          final M = cv.moments(cv.Mat.fromVec(contour));
          if (M.m00 == 0) continue;
          final cx = M.m10 / M.m00;
          final cy = M.m01 / M.m00;
          final globalCentroid = Offset(minX + cx, minY + cy);

          final dist = (globalCentroid - topMidGlobal).distance;

          if (dist < minLedDist || dist > maxLedDist) {
            // Skip this candidate if it is too close or too far
            continue;
          }

          // Create a mask for just this one LED candidate
          final singleLedMask = cv.Mat.zeros(
            roiMat.rows,
            roiMat.cols,
            cv.MatType.CV_8UC1,
          );
          final cVec = cv.VecVecPoint.fromList([
            contour.toList(),
          ]); // tedious conversion
          cv.drawContours(
            singleLedMask,
            cVec,
            -1,
            cv.Scalar(255, 0, 0, 0),
            thickness: -1,
          );
          cVec.dispose();

          // Calculate average color INSIDE the blob
          final meanColor = cv.mean(roiHsv, mask: singleLedMask);
          singleLedMask.dispose();

          final double h = meanColor.val1; // Average Hue
          final double s = meanColor.val2; // Average Saturation

          // CLASSIFICATION LOGIC
          // Even if the center is white (S=0), the halo will pull the average S up.
          // If Average S is still < 20, it's likely a white reflection/glare, not an LED.

          if (s > 25) {
            StockStatus? status;
            String colorLabel = "Unknown";
            Color visColor = const Color(0xFF000000);

            // Hue Ranges (OpenCV Hue is 0-180)
            // Red: 0-10 and 160-180
            // Yellow: 15-35
            // Green: 35-85

            if (h < 12 || h > 160) {
              status = StockStatus.outOfStock;
              colorLabel = "Red";
              visColor = const Color(0xFFFF0000);
            } else if (h > 15 && h < 35) {
              status = StockStatus.lowStock;
              colorLabel = "Yellow";
              visColor = const Color(0xFFFFFF00);
            } else if (h >= 35 && h < 90) {
              // Wide green range
              status = StockStatus.inStock;
              colorLabel = "Green";
              visColor = const Color(0xFF00FF00);
            }

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
        } else {
          debugPrint("Circularity too small: $circularity");
        }
      }
      contours.dispose();
      hierarchy.dispose();

      // --- 7. Winner Selection ---
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
      // Dispose all Mats
      roiMat.dispose();
      roiHsv?.dispose();
      mask?.dispose();
      vChannel?.dispose();
    }
  }

  // --- 0. Geometry & Cone (Revised with Homography) ---
  // --- 0. Geometry & Cone (Revised with 1000x Scale Fix) ---
  List<Offset> _calculateCone(List<Offset> corners) {
    if (corners.length != 4) return [];

    // CONSTANT: Scale ideal world up by 1000 to preserve precision with Integers
    const double scale = 1000.0;

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

      // 4. Define Cone in "1000x World"
      // We multiply all our ratio constants by `scale`
      const double startY = -0.2 * scale; // 20% gap
      const double endY = (-0.2 - 3.9) * scale; // 390% length
      const double baseHalfW = (1.5 / 2.0) * scale;
      const double topHalfW = (2.5 / 2.0) * scale;
      const double centerX = 0.5 * scale;

      final idealConePoints = [
        cv.Point2f(centerX - baseHalfW, startY),
        cv.Point2f(centerX - topHalfW, endY),
        cv.Point2f(centerX + topHalfW, endY),
        cv.Point2f(centerX + baseHalfW, startY),
      ];

      // 5. Transform
      // Even though M was made with Ints, it works on Floats for the projection.
      idealConeMat = cv.Mat.fromVec(cv.VecPoint2f.fromList(idealConePoints));
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
