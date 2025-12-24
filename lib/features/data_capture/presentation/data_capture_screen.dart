import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

enum CaptureMode { photo, video }

class DataCaptureScreen extends StatefulWidget {
  const DataCaptureScreen({super.key});

  @override
  State<DataCaptureScreen> createState() => _DataCaptureScreenState();
}

class _DataCaptureScreenState extends State<DataCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;

  String? _lastCapturePath;
  CaptureMode _mode = CaptureMode.photo;

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
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (!iosInfo.isPhysicalDevice) {
        if (mounted) {
          setState(() {});
        }
        return;
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final camera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          camera,
          ResolutionPreset.high,
          enableAudio: true,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _controller!.initialize();
        // Lower exposure to highlight LEDs vs background
        try {
          await _controller!.setExposureOffset(-2.0);
        } catch (e) {
          debugPrint('Error setting exposure offset: $e');
        }

        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint('No cameras found');
        if (mounted) {}
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {}
    }
  }

  void _showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150, // Top area
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile file = await _controller!.takePicture();
      await _saveFile(file, isVideo: false);
      if (mounted) {
        _showTopSnackBar('Photo Captured');
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      await _saveFile(file, isVideo: true);
      if (mounted) {
        _showTopSnackBar('Video Saved');
      }
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _onShutterPressed() async {
    if (_mode == CaptureMode.photo) {
      await _capturePhoto();
    } else {
      await _toggleVideoRecording();
    }
  }

  Future<void> _saveFile(XFile file, {required bool isVideo}) async {
    final directory = await getApplicationDocumentsDirectory();
    final String subDir = isVideo ? 'videos' : 'images';
    final String captureDir = '${directory.path}/captures/$subDir';
    await Directory(captureDir).create(recursive: true);

    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${isVideo ? "video.mp4" : "photo.jpg"}';
    final String newPath = '$captureDir/$fileName';

    await file.saveTo(newPath);
    setState(() {
      _lastCapturePath = newPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    // if (!_isInit) {
    //   return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // }

    // if (_isSimulator) {
    //   return Scaffold(
    //     appBar: AppBar(title: const Text('Data Capture')),
    //     body: const Center(
    //       child: Padding(
    //         padding: EdgeInsets.all(20.0),
    //         child: Text(
    //           'Camera not available on iOS Simulator.\nPlease use a physical device to test camera features.',
    //           textAlign: TextAlign.center,
    //           style: TextStyle(fontSize: 16),
    //         ),
    //       ),
    //     ),
    //   );
    // }

    // if (_controller == null || !_controller!.value.isInitialized) {
    //   return const Scaffold(
    //     body: Center(child: Text('Camera not initialized')),
    //   );
    // }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          //CameraPreview(_controller!),

          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton(CaptureMode.photo, 'Photo'),
                      const SizedBox(width: 20),
                      _buildModeButton(CaptureMode.video, 'Video'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Last capture preview
                      GestureDetector(
                        onTap: () => context.push('/gallery'),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            image:
                                _lastCapturePath != null &&
                                    _lastCapturePath!.endsWith('.jpg')
                                ? DecorationImage(
                                    image: FileImage(File(_lastCapturePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              _lastCapturePath == null ||
                                  !_lastCapturePath!.endsWith('.jpg')
                              ? const Icon(
                                  Icons.collections,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),

                      // Shutter Button
                      GestureDetector(
                        onTap: _onShutterPressed,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _mode == CaptureMode.video && _isRecording
                                ? Colors.red
                                : Colors.white,
                            border: Border.all(color: Colors.grey, width: 4),
                          ),
                          child: _mode == CaptureMode.video && _isRecording
                              ? const Center(
                                  child: Icon(Icons.stop, color: Colors.white),
                                )
                              : null,
                        ),
                      ),

                      // Placeholder for symmetry or settings
                      const SizedBox(width: 50),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // AppBar / Back
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 8,
            child: const BackButton(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(CaptureMode mode, String label) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (!_isRecording) {
          setState(() => _mode = mode);
        }
      },
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.yellow : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }
}
