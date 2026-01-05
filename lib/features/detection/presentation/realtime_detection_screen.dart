import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
import 'package:color_detection_app/features/product_management/data/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Real-time camera detection screen with live overlays.
class RealtimeDetectionScreen extends ConsumerStatefulWidget {
  const RealtimeDetectionScreen({super.key});

  @override
  ConsumerState<RealtimeDetectionScreen> createState() =>
      _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState
    extends ConsumerState<RealtimeDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isDisposed = false; // Track disposal state to prevent crash

  // Detection
  final ConeSearchAlgorithm _algorithm = ConeSearchAlgorithm();
  List<DetectionResult> _currentResults = [];
  bool _isDetecting = false;

  // Aggregated products detected in this session
  final Map<String, DetectionResult> _detectedProducts = {};

  // Processing timer for throttling (target: 10 FPS = 100ms interval)
  Timer? _processingTimer;
  static const int _targetFps = 10;
  static const Duration _processingInterval = Duration(
    milliseconds: 1000 ~/ _targetFps,
  );

  // Temp file for frame processing
  String? _tempFramePath;

  // Size of captured frames for overlay scaling
  Size? _capturedImageSize;

  // Platform check
  bool get _isIOS => Platform.isIOS;

  // Latest camera image for iOS processing
  CameraImage? _latestCameraImage;
  bool _isStreamActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed FIRST to prevent crash
    WidgetsBinding.instance.removeObserver(this);
    _stopProcessing();
    _stopImageStream();
    _controller?.dispose();
    // Clean up temp file
    if (_tempFramePath != null) {
      try {
        File(_tempFramePath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopProcessing();
      _stopImageStream();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'No cameras available');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // iOS: Use BGRA8888 for image stream, Android: Use JPEG for takePicture
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high, // Use high for better QR detection
        enableAudio: false,
        imageFormatGroup: _isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Get temp directory for frame processing
      final tempDir = await getTemporaryDirectory();
      _tempFramePath = '${tempDir.path}/realtime_frame.jpg';

      if (mounted && !_isDisposed) {
        setState(() => _isInitialized = true);

        if (_isIOS) {
          _startImageStream();
        }

        _startProcessing();
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Camera init failed: $e');
      }
    }
  }

  void _startImageStream() {
    if (_isDisposed || _controller == null || _isStreamActive) return;

    try {
      _controller!.startImageStream((CameraImage image) {
        if (!_isDisposed) {
          _latestCameraImage = image;
        }
      });
      _isStreamActive = true;
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  void _stopImageStream() {
    if (!_isStreamActive) return;

    try {
      _controller?.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
    _isStreamActive = false;
    _latestCameraImage = null;
  }

  void _startProcessing() {
    if (_isDisposed) return;
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_processingInterval, (_) {
      if (!_isDisposed) {
        _captureAndProcess();
      }
    });
  }

  void _stopProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  Future<void> _captureAndProcess() async {
    if (_isDisposed ||
        _isDetecting ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    _isDetecting = true;

    try {
      List<DetectionResult> results;
      Size imageSize;

      if (_isIOS) {
        // iOS: Process BGRA bytes directly (no JPEG compression)
        final cameraImage = _latestCameraImage;
        if (cameraImage == null || _isDisposed) {
          _isDetecting = false;
          return;
        }

        // Strip stride padding and get raw BGRA bytes
        final bgraBytes = _extractBgraBytes(cameraImage);
        if (bgraBytes == null || _isDisposed) {
          _isDetecting = false;
          return;
        }

        final width = cameraImage.width;
        final height = cameraImage.height;
        imageSize = Size(width.toDouble(), height.toDouble());

        // Process directly using BGRA bytes (no JPEG compression!)
        results = await _algorithm.processFromBgra(bgraBytes, width, height);
      } else {
        // Android: Use takePicture (original working approach)
        final XFile imageFile = await _controller!.takePicture();
        final frameFile = File(imageFile.path);

        // Get actual image dimensions for overlay scaling
        final imageBytes = await frameFile.readAsBytes();
        final decodedImage = await decodeImageFromList(imageBytes);
        imageSize = Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        );

        if (_isDisposed) {
          _isDetecting = false;
          return;
        }

        // Process the frame
        results = await _algorithm.process(frameFile);

        // Clean up captured file
        try {
          frameFile.deleteSync();
        } catch (_) {}
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _currentResults = results;
          _capturedImageSize = imageSize;
        });

        // Update product database for detected products
        for (final result in results) {
          if (result.qrCode != null && result.status != null) {
            _detectedProducts[result.qrCode!] = result;
            await _updateProductStatus(result);
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Real-time detection error: $e');
      }
    } finally {
      _isDetecting = false;
    }
  }

  /// Extract raw BGRA bytes from CameraImage, handling stride padding.
  /// Returns null if the format is unsupported.
  Uint8List? _extractBgraBytes(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group != ImageFormatGroup.bgra8888) {
        debugPrint('Unsupported camera format: ${cameraImage.format.group}');
        return null;
      }

      final plane = cameraImage.planes[0];
      final bytesPerRow = plane.bytesPerRow;
      final width = cameraImage.width;
      final height = cameraImage.height;
      final bytesPerPixel = 4; // BGRA = 4 bytes per pixel
      final expectedBytesPerRow = width * bytesPerPixel;

      if (bytesPerRow == expectedBytesPerRow) {
        // No padding, return bytes directly
        return Uint8List.fromList(plane.bytes);
      } else {
        // Has stride padding, need to strip it row by row
        final strippedBytes = Uint8List(width * height * bytesPerPixel);
        for (int y = 0; y < height; y++) {
          final srcOffset = y * bytesPerRow;
          final dstOffset = y * expectedBytesPerRow;
          for (int x = 0; x < expectedBytesPerRow; x++) {
            strippedBytes[dstOffset + x] = plane.bytes[srcOffset + x];
          }
        }
        return strippedBytes;
      }
    } catch (e) {
      debugPrint('Error extracting BGRA bytes: $e');
      return null;
    }
  }

  Future<void> _updateProductStatus(DetectionResult result) async {
    if (_isDisposed || result.status == null || result.qrCode == null) return;

    try {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.getProduct(result.qrCode!);
      if (product != null) {
        final updated = product.copyWith(
          stockStatus: result.status!,
          lastUpdated: DateTime.now(),
        );
        await repo.saveProduct(updated);
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Real-time Detection'),
        actions: [
          // FPS indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '$_targetFps FPS',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview with overlay
          Expanded(child: _buildCameraPreview()),

          // Results panel
          if (_detectedProducts.isNotEmpty) _buildResultsPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    // Camera aspect ratio: previewSize is (height, width) so we need to invert
    final previewSize = _controller!.value.previewSize;
    final cameraAspect = previewSize != null
        ? previewSize.height / previewSize.width
        : 4.0 / 3.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate actual preview dimensions that fit within constraints
        double previewWidth;
        double previewHeight;

        final constraintAspect = constraints.maxWidth / constraints.maxHeight;

        if (cameraAspect > constraintAspect) {
          // Camera is wider than container - fit to width
          previewWidth = constraints.maxWidth;
          previewHeight = previewWidth / cameraAspect;
        } else {
          // Camera is taller than container - fit to height
          previewHeight = constraints.maxHeight;
          previewWidth = previewHeight * cameraAspect;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview - centered with correct aspect ratio
            Center(
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: CameraPreview(_controller!),
              ),
            ),

            // Detection overlay - must match preview exactly
            if (_currentResults.isNotEmpty && _capturedImageSize != null)
              Center(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: CustomPaint(
                    size: Size(previewWidth, previewHeight),
                    painter: DetectionResultPainter(
                      results: _currentResults,
                      imageSize: _capturedImageSize!,
                    ),
                  ),
                ),
              ),

            // Status indicator
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isDetecting
                      ? Colors.orange.withValues(alpha: 0.8)
                      : Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDetecting ? Icons.hourglass_top : Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isDetecting ? 'Processing...' : 'Ready',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultsPanel() {
    final results = _detectedProducts.values.toList();

    return Container(
      color: Colors.black87,
      height: 150,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Products Detected (${results.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white24, height: 1),
              itemBuilder: (context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: result.detectedColor ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.qrCode ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        result.status?.label ?? 'Unknown',
                        style: TextStyle(
                          color: result.detectedColor ?? Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
