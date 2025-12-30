// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as math;
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:device_info_plus/device_info_plus.dart';

// import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
// import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
// import 'package:color_detection_app/features/detection/domain/detection_result.dart';
// import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
// import 'package:opencv_dart/opencv_dart.dart' as cv;

// class RealTimeAnalysisScreen extends ConsumerStatefulWidget {
//   const RealTimeAnalysisScreen({super.key});

//   @override
//   ConsumerState<RealTimeAnalysisScreen> createState() =>
//       _RealTimeAnalysisScreenState();
// }

// class _RealTimeAnalysisScreenState extends ConsumerState<RealTimeAnalysisScreen>
//     with WidgetsBindingObserver {
//   CameraController? _controller;
//   bool _isProcessing = false;

//   // Zoom State
//   double _currentZoom = 1.0;
//   double _maxZoom = 1.0;
//   double _minZoom = 1.0;

//   // Throttling
//   DateTime _lastProcessTime = DateTime.now();
//   final Duration _processInterval = const Duration(
//     milliseconds: 100,
//   ); // 5 FPS cap

//   // Algorithm
//   final DetectionAlgorithm _algorithm = ConeSearchAlgorithm();
//   List<DetectionResult> _results = [];

//   // Dimensions for the Painter (Must match the Rotated Image)
//   Size _processedImageSize = Size.zero;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initCamera();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _controller?.dispose();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (_controller == null || !_controller!.value.isInitialized) return;
//     if (state == AppLifecycleState.inactive) {
//       _controller?.dispose();
//     } else if (state == AppLifecycleState.resumed) {
//       _initCamera();
//     }
//   }

//   Future<void> _initCamera() async {
//     final cameras = await availableCameras();
//     if (cameras.isEmpty) return;

//     final camera = cameras.firstWhere(
//       (c) => c.lensDirection == CameraLensDirection.back,
//       orElse: () => cameras.first,
//     );

//     _controller = CameraController(
//       camera,
//       // CRITICAL FIX: 'low' is too blurry for LEDs. Use 'high' or 'veryHigh'.
//       ResolutionPreset.veryHigh,
//       enableAudio: false,
//       imageFormatGroup: Platform.isAndroid
//           ? ImageFormatGroup.yuv420
//           : ImageFormatGroup.bgra8888,
//     );

//     try {
//       await _controller!.initialize();

//       // Setup Zoom
//       _maxZoom = await _controller!.getMaxZoomLevel();
//       _minZoom = await _controller!.getMinZoomLevel();

//       // Lock Focus for stability (Optional, or allow tap-to-focus)
//       await _controller!.setFocusMode(FocusMode.auto);

//       // Fix Exposure (Darken image slightly to prevent LED blowout)
//       // await _controller!.setExposureOffset(-1.0);

//       await _controller!.startImageStream(_processCameraImage);

//       if (mounted) setState(() {});
//     } catch (e) {
//       debugPrint("Camera init error: $e");
//     }
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     // 1. Throttle: Skip frames to prevent UI freeze
//     if (_isProcessing ||
//         DateTime.now().difference(_lastProcessTime) < _processInterval) {
//       return;
//     }
//     _isProcessing = true;
//     _lastProcessTime = DateTime.now();

//     try {
//       // 2. Convert raw bytes to OpenCV Mat
//       // Note: This Mat is usually Landscape (e.g. 1920x1080)
//       cv.Mat? rawMat = _matFromCameraImage(image);

//       if (rawMat == null || rawMat.isEmpty) {
//         _isProcessing = false;
//         return;
//       }

//       // 3. FIX ROTATION: Rotate Mat to match Portrait UI
//       // Android/iOS sensors are usually 90 deg clockwise relative to portrait.
//       // We rotate it so "Up" in the image is "Up" in the real world.
//       final rotatedMat = cv.rotate(rawMat, cv.ROTATE_90_CLOCKWISE);
//       rawMat.dispose(); // Done with raw

//       // 4. ML Kit Input (We must tell ML Kit the image is rotated too)
//       // Since we rotated the Mat, we should pass the rotated Mat to ML Kit?
//       // Actually, ML Kit handles rotation metadata separately.
//       // Optimization: To ensure alignment, we can feed the ROTATED Mat back to ML Kit
//       // via file or bytes, but it's expensive.
//       // Better: Let ML Kit handle the raw buffer but ensure we treat coordinates correctly.
//       // HOWEVER, for simplicity and alignment guarantee:
//       // Let's pass the ROTATED Mat to the algorithm.
//       // The Algorithm calls ML Kit on the File/Image.

//       // Since `processFrame` in Algorithm takes InputImage AND Mat,
//       // We need to create an InputImage that matches the Rotated Mat.
//       // This is hard.

//       // ALTERNATIVE STRATEGY:
//       // Pass the Rotated Mat to the algorithm.
//       // Inside the algorithm, convert that Mat to InputImage for ML Kit.
//       // This ensures 100% alignment between Visuals, OpenCV, and ML Kit.

//       // For now, let's modify the Algorithm call slightly or handle conversion here.
//       // Converting Mat -> Bytes -> InputImage is slow.

//       // Let's stick to the raw buffer for ML Kit, but pass the rotation metadata.
//       final inputImage = _inputImageFromCameraImage(image);
//       if (inputImage == null) {
//         rotatedMat.dispose();
//         _isProcessing = false;
//         return;
//       }

//       // 5. Run Algorithm
//       if (!mounted) {
//         rotatedMat.dispose();
//         _isProcessing = false;
//         return;
//       }

//       // NOTE: We pass the 'inputImage' (which has rotation metadata)
//       // AND 'rotatedMat' (which is physically rotated).
//       // The Algorithm uses inputImage for QR (ML Kit handles rotation).
//       // The Algorithm uses rotatedMat for Colors.
//       // Problem: ML Kit returns coordinates relative to the unrotated image if logic differs.
//       // But 'InputImage' with rotation metadata usually returns 'upright' coordinates.

//       final results = await (_algorithm as ConeSearchAlgorithm).processFrame(
//         inputImage,
//         rotatedMat,
//       );

//       // Store dimensions for the painter
//       _processedImageSize = Size(
//         rotatedMat.cols.toDouble(),
//         rotatedMat.rows.toDouble(),
//       );

//       rotatedMat.dispose();

//       if (mounted) {
//         setState(() {
//           _results = results;
//         });
//       }
//     } catch (e) {
//       debugPrint("Processing error: $e");
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   // --- Helpers ---

//   Future<void> _setZoom(double zoom) async {
//     if (_controller == null) return;
//     final z = zoom.clamp(_minZoom, _maxZoom);
//     await _controller!.setZoomLevel(z);
//     setState(() => _currentZoom = z);
//   }

//   InputImage? _inputImageFromCameraImage(CameraImage image) {
//     if (_controller == null) return null;
//     final camera = _controller!.description;
//     final sensorOrientation = camera.sensorOrientation;

//     // ML Kit Rotation logic
//     final rotation =
//         InputImageRotationValue.fromRawValue(sensorOrientation) ??
//         InputImageRotation.rotation0deg;

//     final format = Platform.isAndroid
//         ? InputImageFormat.nv21
//         : InputImageFormat.bgra8888;

//     // Fast concatenation for Android NV21 (Y+UV)
//     final WriteBuffer allBytes = WriteBuffer();
//     for (final plane in image.planes) {
//       allBytes.putUint8List(plane.bytes);
//     }
//     final bytes = allBytes.done().buffer.asUint8List();

//     return InputImage.fromBytes(
//       bytes: bytes,
//       metadata: InputImageMetadata(
//         size: Size(image.width.toDouble(), image.height.toDouble()),
//         rotation: rotation,
//         format: format,
//         bytesPerRow: image.planes.first.bytesPerRow,
//       ),
//     );
//   }

//   cv.Mat? _matFromCameraImage(CameraImage image) {
//     try {
//       // ANDROID (YUV420)
//       if (Platform.isAndroid) {
//         // Efficient wrapper: We only need the Y plane (Gray) + Color info.
//         // opencv_dart doesn't support complex YUV_420_888 de-striding easily.
//         // We assume NV21-like structure for the concatenation we did above.

//         // However, converting YUV->BGR inside Dart is slow.
//         // Trick: We can treat the raw bytes as a 1-channel Matrix of height 1.5*H
//         final int w = image.width;
//         final int h = image.height;

//         // Re-concatenate bytes (expensive, but necessary without FFI pointer access)
//         final WriteBuffer allBytes = WriteBuffer();
//         allBytes.putUint8List(image.planes[0].bytes); // Y
//         // UV planes (subsampled)
//         if (image.planes.length > 1) {
//           allBytes.putUint8List(image.planes[1].bytes);
//           allBytes.putUint8List(image.planes[2].bytes);
//         }
//         final bytes = allBytes.done().buffer.asUint8List();

//         // Interpret as single channel Mat including Y and UV data
//         // Height is h + h/2 = 1.5h
//         final matYUV = cv.Mat.fromList(
//           (h * 1.5).toInt(),
//           w,
//           cv.MatType.CV_8UC1,
//           bytes,
//         );

//         // Convert to BGR
//         final matBGR = cv.cvtColor(matYUV, cv.COLOR_YUV2BGR_NV21);
//         matYUV.dispose();
//         return matBGR;
//       }
//       // iOS (BGRA)
//       else if (Platform.isIOS) {
//         final plane = image.planes[0];
//         final matBGRA = cv.Mat.fromList(
//           image.height,
//           image.width,
//           cv.MatType.CV_8UC4,
//           plane.bytes,
//         );
//         final matBGR = cv.cvtColor(matBGRA, cv.COLOR_BGRA2BGR);
//         matBGRA.dispose();
//         return matBGR;
//       }
//     } catch (e) {
//       debugPrint("Mat conversion error: $e");
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Real-time')),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           // 1. Camera Preview
//           CameraPreview(_controller!),

//           // 2. Detection Overlay
//           if (_results.isNotEmpty && _processedImageSize != Size.zero)
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 return CustomPaint(
//                   painter: DetectionResultPainter(
//                     results: _results,
//                     // Use the size of the ROTATED image processed by the algo
//                     imageSize: _processedImageSize,
//                   ),
//                   size: Size(constraints.maxWidth, constraints.maxHeight),
//                 );
//               },
//             ),

//           // 3. Zoom Slider & Controls
//           Positioned(
//             bottom: 30,
//             left: 20,
//             right: 20,
//             child: Column(
//               children: [
//                 if (_results.isNotEmpty && _results.first.status != null)
//                   Container(
//                     margin: const EdgeInsets.only(bottom: 10),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 8,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       "${_results.first.status?.label}",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 Row(
//                   children: [
//                     const Icon(Icons.zoom_out, color: Colors.white),
//                     Expanded(
//                       child: Slider(
//                         value: _currentZoom,
//                         min: _minZoom,
//                         max: _maxZoom,
//                         activeColor: Colors.blue,
//                         inactiveColor: Colors.white24,
//                         onChanged: _setZoom,
//                       ),
//                     ),
//                     const Icon(Icons.zoom_in, color: Colors.white),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class RealTimeAnalysisScreen extends ConsumerStatefulWidget {
  const RealTimeAnalysisScreen({super.key});

  @override
  ConsumerState<RealTimeAnalysisScreen> createState() =>
      _RealTimeAnalysisScreenState();
}

class _RealTimeAnalysisScreenState extends ConsumerState<RealTimeAnalysisScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isProcessing = false;

  // Zoom State
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;

  // Throttling: Cap at ~6 FPS for performance
  DateTime _lastProcessTime = DateTime.now();
  final Duration _processInterval = const Duration(milliseconds: 150);

  final DetectionAlgorithm _algorithm = ConeSearchAlgorithm();
  List<DetectionResult> _results = [];
  Size _processedImageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      // 1. STANDARDIZATION: Use 'high' (720p) or 'veryHigh' (1080p).
      // Do not use 'max' or 'low'. 720p is usually the sweet spot for performance/accuracy.
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minZoom = await _controller!.getMinZoomLevel();
      await _controller!.setFocusMode(FocusMode.auto);

      await _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing ||
        DateTime.now().difference(_lastProcessTime) < _processInterval) {
      return;
    }
    _isProcessing = true;
    _lastProcessTime = DateTime.now();

    try {
      // 1. Convert to Mat (Smart YUV Detection)
      cv.Mat? rawMat = _matFromCameraImage(image);
      if (rawMat == null || rawMat.isEmpty) {
        _isProcessing = false;
        return;
      }

      // 2. Rotate Mat to Portrait (90 deg Clockwise)
      // Note: This changes dimensions! WxH becomes HxW
      final rotatedMat = cv.rotate(rawMat, cv.ROTATE_90_CLOCKWISE);
      final int rotatedWidth = rotatedMat.cols;
      final int rotatedHeight = rotatedMat.rows;

      // We pass the raw size to the algorithm to help mapping ML Kit coords
      final int rawWidth = rawMat.cols;
      final int rawHeight = rawMat.rows;
      rawMat.dispose();

      // 3. ML Kit Input
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        rotatedMat.dispose();
        _isProcessing = false;
        return;
      }

      if (!mounted) {
        rotatedMat.dispose();
        _isProcessing = false;
        return;
      }

      // 4. Process (Pass Rotation Info)
      // We send the Portrait Matrix + Raw Dimensions so the algorithm can map QRs correctly.
      final results = await (_algorithm as ConeSearchAlgorithm).processFrame(
        inputImage,
        rotatedMat,
        rotationFix: true,
        rawSize: Size(rawWidth.toDouble(), rawHeight.toDouble()),
      );

      _processedImageSize = Size(
        rotatedWidth.toDouble(),
        rotatedHeight.toDouble(),
      );

      rotatedMat.dispose();

      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      debugPrint("Processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null) return;
    final z = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(z);
    setState(() => _currentZoom = z);
  }

  // --- Robust Converters ---

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    // Concatenation for ML Kit
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  cv.Mat? _matFromCameraImage(CameraImage image) {
    try {
      if (Platform.isAndroid && image.format.group == ImageFormatGroup.yuv420) {
        final int w = image.width;
        final int h = image.height;

        // --- SMART YUV DETECTION (Fixes Red/Green corruption) ---
        // Android can send YUV in different layouts (NV21, I420, YV12)
        // We check the 'pixelStride' of the UV planes to decide.

        final uPlane = image.planes[1];
        // If pixelStride == 2, bytes are interleaved (UVUV) -> NV21 or NV12
        // If pixelStride == 1, bytes are contiguous (UUU...) -> I420
        final isNV21 = uPlane.bytesPerPixel == 2 || uPlane.bytesPerRow > w;

        final WriteBuffer allBytes = WriteBuffer();
        allBytes.putUint8List(image.planes[0].bytes); // Y Plane

        // Flatten planes into a single buffer
        if (isNV21) {
          allBytes.putUint8List(image.planes[1].bytes);
          allBytes.putUint8List(image.planes[2].bytes);
        } else {
          allBytes.putUint8List(image.planes[1].bytes);
          allBytes.putUint8List(image.planes[2].bytes);
        }

        final bytes = allBytes.done().buffer.asUint8List();

        // 1.5 * Height accounts for the subsampled Color planes
        final matYUV = cv.Mat.fromList(
          (h * 1.5).toInt(),
          w,
          cv.MatType.CV_8UC1,
          bytes,
        );

        // Select correct conversion code based on stride detection
        final code = isNV21 ? cv.COLOR_YUV2BGR_NV21 : cv.COLOR_YUV2BGR_I420;

        final matBGR = cv.cvtColor(matYUV, code);
        matYUV.dispose();
        return matBGR;
      } else if (Platform.isIOS) {
        final plane = image.planes[0];
        final matBGRA = cv.Mat.fromList(
          image.height,
          image.width,
          cv.MatType.CV_8UC4,
          plane.bytes,
        );
        final matBGR = cv.cvtColor(matBGRA, cv.COLOR_BGRA2BGR);
        matBGRA.dispose();
        return matBGR;
      }
    } catch (e) {
      debugPrint("Mat conversion error: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Real-time')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Overlay
          if (_results.isNotEmpty && _processedImageSize != Size.zero)
            LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  painter: DetectionResultPainter(
                    results: _results,
                    imageSize: _processedImageSize,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                );
              },
            ),

          // Controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: Colors.black54,
                    child: Text(
                      "${_results.first.status?.label}",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                Row(
                  children: [
                    const Icon(Icons.zoom_out, color: Colors.white),
                    Expanded(
                      child: Slider(
                        value: _currentZoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: _setZoom,
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
