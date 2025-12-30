import 'dart:io';
import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';

import 'package:color_detection_app/features/detection/presentation/real_time_analysis_screen.dart';
import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
import 'package:color_detection_app/features/product_management/data/product_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  File? _selectedImage;
  Size? _imageSize; // Add this
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze Product')),
      body: Column(
        children: [
          // Top Bar: Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image),
                    label: const Text('Upload Image'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RealTimeAnalysisScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam),
                label: const Text('Real-time Detection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.blue[900],
                ),
              ),
            ),
          ),

          // Main Content: Image & Overlay
          Expanded(
            child: Center(
              child: _selectedImage == null
                  ? const Text('Select an image to start analysis')
                  : _isProcessing
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

          // 3. Results Panel (Multiple Results)
          if (_results.isNotEmpty)
            Container(
              color: Colors.black87,
              height: 150, // Fixed height for the list
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
      ),
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
}
