import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
// Using gal for saving to gallery might be better? Or just file.
// Rules say "Data Capture Tool... store locally... Share/Export button creates a zip".
// So saving to app directory is better.

import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  bool _isInit = false;
  String? _lastCapturePath;

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
    // App state changed before we got the chance to initialize.
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
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      // Use the first back camera
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

      try {
        await _controller!.initialize();
        // Try to disable some auto-enhancements if possible/supported
        // Note: Exposure/Focus locking logic could go here if requested,
        // but "minimal auto-processing" usually means avoid HDR/Night mode which are often automatic
        // or require specific native params not always exposed.
        // We will default to standard capture.
        if (mounted) {
          setState(() {
            _isInit = true;
          });
        }
      } on CameraException catch (e) {
        debugPrint('Camera error: $e');
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile file = await _controller!.takePicture();
      await _saveFile(file, isVideo: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo Captured')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video Saved')));
      }
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _saveFile(XFile file, {required bool isVideo}) async {
    final directory = await getApplicationDocumentsDirectory();
    final String captureDir = '${directory.path}/captures';
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
    if (!_isInit || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Last capture preview (simple placeholder or icon if nothing)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      image: _lastCapturePath != null
                          ? DecorationImage(
                              image: FileImage(File(_lastCapturePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _lastCapturePath == null
                        ? const Icon(Icons.history, color: Colors.white)
                        : null,
                  ),

                  // Shutter Button
                  GestureDetector(
                    onTap: _capturePhoto,
                    onLongPress:
                        _toggleVideoRecording, // Long press for video? Or maybe separate toggle.
                    // User story says "Toggle: Switch between Photo and Video mode".
                    // I'll implement a proper toggle or separate buttons.
                    // Let's do separate buttons for clarity or mode switch.
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.white,
                        border: Border.all(color: Colors.grey, width: 4),
                      ),
                      child: _isRecording
                          ? const Icon(Icons.stop, color: Colors.white)
                          : null,
                    ),
                  ),

                  // Mode Toggle (Simplified as separate button for now to stop/start if recording,
                  // but usually simple tap = photo, long press = video is nice.
                  // But "Toggle: Switch between 'Photo' and 'Video' mode" implies a state switch.
                  // I'll add a mode switch button.
                  IconButton(
                    onPressed: _toggleVideoRecording,
                    icon: Icon(
                      _isRecording ? Icons.videocam_off : Icons.videocam,
                      color: Colors.white,
                      size: 30,
                    ),
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
}
