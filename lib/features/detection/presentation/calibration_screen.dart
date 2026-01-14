import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import '../data/calibration_repository.dart';
import '../domain/cone_calibration_settings.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  File? _selectedImage;
  Size? _imageSize;
  List<Offset>? _qrCorners;
  bool _isLoading = false;
  String? _errorMessage;

  // Calibration settings
  double _heightMultiplier = 1.0;
  int _rotationAngle = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(calibrationRepositoryProvider);
    final settings = await repo.getSettings();
    setState(() {
      _heightMultiplier = settings.heightMultiplier;
      _rotationAngle = settings.rotationAngle;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking image: $e');
    }
  }

  Future<void> _processImage(File file) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _qrCorners = null;
    });

    try {
      // Decode image to get size
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());
      final imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );

      // Detect QR code
      final inputImage = InputImage.fromFile(file);
      final barcodeScanner = BarcodeScanner();
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      if (barcodes.isEmpty) {
        setState(() {
          _selectedImage = file;
          _imageSize = imageSize;
          _qrCorners = null;
          _errorMessage =
              'No QR code detected. Please upload a different image.';
          _isLoading = false;
        });
        return;
      }

      // Get QR corners
      final barcode = barcodes.first;
      final corners = barcode.cornerPoints;
      if (corners == null || corners.length != 4) {
        setState(() {
          _selectedImage = file;
          _imageSize = imageSize;
          _qrCorners = null;
          _errorMessage =
              'Could not detect QR corners. Please try another image.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _selectedImage = file;
        _imageSize = imageSize;
        _qrCorners = corners
            .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
            .toList();
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing image: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final settings = ConeCalibrationSettings(
      heightMultiplier: _heightMultiplier,
      rotationAngle: _rotationAngle,
    );
    final repo = ref.read(calibrationRepositoryProvider);
    await repo.saveSettings(settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calibration saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cone Calibration'),
        actions: [
          if (_qrCorners != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedImage == null) {
      return _buildUploadPrompt();
    }

    return Column(
      children: [
        // Image preview with cone overlay
        Expanded(
          flex: 3,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildImagePreview(),
        ),

        // Controls
        if (_qrCorners != null) ...[
          const Divider(),
          Expanded(flex: 2, child: _buildControls()),
        ],

        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red[50],
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _pickImage,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Upload an image with a QR code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo from the front, close to the QR code and LED',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload),
              label: const Text('Upload Image'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Image
            Center(
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
            // Cone overlay
            if (_qrCorners != null && _imageSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: ConePreviewPainter(
                    qrCorners: _qrCorners!,
                    imageSize: _imageSize!,
                    heightMultiplier: _heightMultiplier,
                    rotationAngle: _rotationAngle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hint text - more subtle styling
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Position the LED inside the cone. Avoid making the cone too large to prevent misdetections.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Height slider
          Text(
            'Cone Height: ${_heightMultiplier.toStringAsFixed(1)}x',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _heightMultiplier,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            label: '${_heightMultiplier.toStringAsFixed(1)}x',
            onChanged: (value) {
              setState(() => _heightMultiplier = value);
            },
          ),
          const SizedBox(height: 16),

          // Rotation slider (degree by degree)
          Text(
            'Cone Direction: $_rotationAngle°',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _rotationAngle.toDouble(),
            min: 0,
            max: 359,
            divisions: 359,
            label: '$_rotationAngle°',
            onChanged: (value) {
              setState(() => _rotationAngle = value.round());
            },
          ),
          // Direction labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDirectionLabel('Up', 0),
                _buildDirectionLabel('Right', 90),
                _buildDirectionLabel('Down', 180),
                _buildDirectionLabel('Left', 270),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionLabel(String label, int angle) {
    final isSelected =
        (_rotationAngle - angle).abs() < 15 ||
        (_rotationAngle - angle).abs() > 345;
    return GestureDetector(
      onTap: () => setState(() => _rotationAngle = angle),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
        ),
      ),
    );
  }
}

/// Painter for cone preview overlay
class ConePreviewPainter extends CustomPainter {
  final List<Offset> qrCorners;
  final Size imageSize;
  final double heightMultiplier;
  final int rotationAngle;

  ConePreviewPainter({
    required this.qrCorners,
    required this.imageSize,
    required this.heightMultiplier,
    required this.rotationAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (qrCorners.length != 4) return;

    // Calculate scale to fit image in view
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = math.min(scaleX, scaleY);

    // Center offset
    final offsetX = (size.width - imageSize.width * scale) / 2;
    final offsetY = (size.height - imageSize.height * scale) / 2;

    // Transform QR corners to view coordinates
    final scaledCorners = qrCorners.map((c) {
      return Offset(c.dx * scale + offsetX, c.dy * scale + offsetY);
    }).toList();

    // Draw QR boundary
    final qrPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final qrPath = Path()
      ..moveTo(scaledCorners[0].dx, scaledCorners[0].dy)
      ..lineTo(scaledCorners[1].dx, scaledCorners[1].dy)
      ..lineTo(scaledCorners[2].dx, scaledCorners[2].dy)
      ..lineTo(scaledCorners[3].dx, scaledCorners[3].dy)
      ..close();
    canvas.drawPath(qrPath, qrPaint);

    // Calculate cone
    final conePoints = _calculateCone(scaledCorners);
    if (conePoints.length != 4) return;

    // Draw cone
    final conePaint = Paint()
      ..color = Colors.green.withAlpha(80)
      ..style = PaintingStyle.fill;

    final conePath = Path()
      ..moveTo(conePoints[0].dx, conePoints[0].dy)
      ..lineTo(conePoints[1].dx, conePoints[1].dy)
      ..lineTo(conePoints[2].dx, conePoints[2].dy)
      ..lineTo(conePoints[3].dx, conePoints[3].dy)
      ..close();
    canvas.drawPath(conePath, conePaint);

    // Draw cone border
    final coneBorderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(conePath, coneBorderPaint);
  }

  List<Offset> _calculateCone(List<Offset> corners) {
    if (corners.length != 4) return [];

    // Calculate QR center
    final centerX = corners.fold(0.0, (sum, c) => sum + c.dx) / 4;
    final centerY = corners.fold(0.0, (sum, c) => sum + c.dy) / 4;
    final center = Offset(centerX, centerY);

    // Estimate QR size
    final qrWidth = (corners[1] - corners[0]).distance;
    final qrHeight = (corners[3] - corners[0]).distance;
    final qrSize = (qrWidth + qrHeight) / 2;

    // Cone dimensions (relative to QR size)
    const gapRatio = 0.2;
    final lengthRatio = 3.9 * heightMultiplier;
    const baseWidthRatio = 1.5;
    const topWidthRatio = 2.5;

    // Calculate unrotated cone points (pointing up, relative to center)
    final gap = qrSize * gapRatio;
    final length = qrSize * lengthRatio;
    final baseHalfWidth = qrSize * baseWidthRatio / 2;
    final topHalfWidth = qrSize * topWidthRatio / 2;

    // Cone points in local coordinates (0,0 at QR center)
    final localPoints = [
      Offset(-baseHalfWidth, -(qrSize / 2 + gap)), // Bottom left of cone
      Offset(-topHalfWidth, -(qrSize / 2 + gap + length)), // Top left
      Offset(topHalfWidth, -(qrSize / 2 + gap + length)), // Top right
      Offset(baseHalfWidth, -(qrSize / 2 + gap)), // Bottom right
    ];

    // Rotate points around center
    final radians = rotationAngle * math.pi / 180;
    return localPoints.map((p) {
      final rotatedX = p.dx * math.cos(radians) - p.dy * math.sin(radians);
      final rotatedY = p.dx * math.sin(radians) + p.dy * math.cos(radians);
      return Offset(center.dx + rotatedX, center.dy + rotatedY);
    }).toList();
  }

  @override
  bool shouldRepaint(ConePreviewPainter oldDelegate) {
    return oldDelegate.heightMultiplier != heightMultiplier ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.qrCorners != qrCorners;
  }
}
