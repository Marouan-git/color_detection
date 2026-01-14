import 'dart:io';
import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';

import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
import 'package:color_detection_app/features/product_management/data/product_repository.dart';

import 'package:color_detection_app/features/detection/presentation/camera_capture_screen.dart';
import 'package:color_detection_app/features/detection/presentation/realtime_detection_screen.dart';
import 'package:color_detection_app/features/detection/presentation/video_analysis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  File? _selectedImage;
  Size? _imageSize;
  List<DetectionResult> _results = [];
  bool _isProcessing = false;

  // Use the single production algorithm directly
  final DetectionAlgorithm _algorithm = ConeSearchAlgorithm();

  final ImagePicker _picker = ImagePicker();

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _results = [];
    });

    try {
      final results = await _algorithm.process(_selectedImage!);

      if (mounted) {
        setState(() {
          _results = results;
          _isProcessing = false;
        });

        for (final result in results) {
          await _updateProductStatus(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
      }
    }
  }

  Future<void> _updateProductStatus(DetectionResult result) async {
    if (result.status != null && result.qrCode != null) {
      try {
        final repo = ref.read(productRepositoryProvider);
        final product = await repo.getProduct(result.qrCode!);
        if (product != null) {
          final updatedProduct = product.copyWith(
            stockStatus: result.status!,
            lastUpdated: DateTime.now(),
          );
          await repo.saveProduct(updatedProduct);
        }
      } catch (e) {
        debugPrint('Error updating product: $e');
      }
    }
  }

  /// Opens the camera and processes the captured image
  /// Uses CameraCaptureScreen on Android, image_picker on iOS
  Future<void> _captureFromCamera() async {
    if (Platform.isIOS) {
      // iOS: Use image_picker which is more reliable
      try {
        final XFile? capturedFile = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
        );

        if (capturedFile != null) {
          // iOS images may have EXIF orientation that OpenCV doesn't handle
          // Preprocess to apply EXIF rotation and save as corrected file
          final File processedFile = await _preprocessIosImage(
            File(capturedFile.path),
          );
          await _setImageAndProcess(processedFile);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
        }
      }
    } else {
      // Android: Use custom camera screen
      final File? capturedFile = await Navigator.of(context).push<File>(
        MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
      );

      if (capturedFile != null) {
        await _setImageAndProcess(capturedFile);
      }
    }
  }

  /// Preprocesses iOS images to apply EXIF orientation correction.
  /// OpenCV's imdecode doesn't respect EXIF orientation, so we need to
  /// bake the rotation into the pixel data.
  Future<File> _preprocessIosImage(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();

      // Decode image with EXIF orientation applied
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('Failed to decode image for preprocessing');
        return originalFile;
      }

      // The decodeImage function already applies EXIF orientation!
      // Re-encode to JPEG to bake in the correct orientation
      final correctedBytes = img.encodeJpg(image, quality: 95);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/ios_captured_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(correctedBytes);

      return tempFile;
    } catch (e) {
      debugPrint('Error preprocessing iOS image: $e');
      return originalFile;
    }
  }

  /// Picks an image from gallery and processes it
  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        await _setImageAndProcess(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  /// Sets the image and triggers processing
  Future<void> _setImageAndProcess(File file) async {
    // Decode image to get size for overlay scaling
    final decodedImage = await decodeImageFromList(file.readAsBytesSync());

    setState(() {
      _selectedImage = file;
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      _results = [];
      _isProcessing = false;
    });

    // Auto-process the new image
    await _processImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze Product')),
      body: _selectedImage == null ? _buildButtonsOnly() : _buildWithImage(),
      floatingActionButton: _selectedImage != null
          ? FloatingActionButton(
              onPressed: () => setState(() {
                _selectedImage = null;
                _results = [];
              }),
              child: const Icon(Icons.close),
            )
          : null,
    );
  }

  /// Build layout with centered buttons only (no image selected)
  Widget _buildButtonsOnly() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 150.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Take Photo & Upload Image row (hidden per user request)
            // Row(
            //   children: [
            //     Expanded(
            //       child: ElevatedButton.icon(
            //         onPressed: _captureFromCamera,
            //         icon: const Icon(Icons.camera_alt),
            //         label: const Text('Take Photo'),
            //       ),
            //     ),
            //     const SizedBox(width: 16),
            //     Expanded(
            //       child: OutlinedButton.icon(
            //         onPressed: _pickFromGallery,
            //         icon: const Icon(Icons.image),
            //         label: const Text('Upload Image'),
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 32),

            // Video Upload Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VideoAnalysisScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.video_library),
              label: const Text('Upload Video'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),

            // Real-time Detection Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RealtimeDetectionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Real-time Detection'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build layout with image and results
  Widget _buildWithImage() {
    return Column(
      children: [
        // Main Content: Image & Overlay
        Expanded(
          child: Center(
            child: _isProcessing
                ? const CircularProgressIndicator()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                          ),
                          if (_results.isNotEmpty && _imageSize != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: DetectionResultPainter(
                                  results: _results,
                                  imageSize: _imageSize!,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),

        // Results Panel (Multiple Results)
        if (_results.isNotEmpty)
          Container(
            color: Colors.black87,
            height: 150,
            width: double.infinity,
            child: ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: _results.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white24),
              itemBuilder: (context, index) {
                final result = _results[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                        Text(
                          'Result: ${result.status?.label ?? "Unknown"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (result.qrCode != null)
                      Text(
                        'Product: ${result.qrCode}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (result.message != null)
                      Text(
                        result.message!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
