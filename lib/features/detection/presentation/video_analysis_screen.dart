import 'dart:async';
import 'dart:io';

import 'package:color_detection_app/features/detection/data/cone_search_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_algorithm.dart';
import 'package:color_detection_app/features/detection/domain/detection_result.dart';
import 'package:color_detection_app/features/detection/presentation/widgets/detection_visualizer.dart';
import 'package:color_detection_app/features/product_management/data/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Screen for uploading, processing, and viewing video with detection overlays.
class VideoAnalysisScreen extends ConsumerStatefulWidget {
  const VideoAnalysisScreen({super.key});

  @override
  ConsumerState<VideoAnalysisScreen> createState() =>
      _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends ConsumerState<VideoAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  final DetectionAlgorithm _algorithm = ConeSearchAlgorithm();

  // Video state
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Processing state
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = '';

  static const int _analysisFps = 2; // Process 2 frames per second

  // Detection results per frame (keyed by milliseconds)
  final Map<int, List<DetectionResult>> _frameResults = {};
  int _videoDurationMs = 0;

  // Aggregated unique product results (for display)
  final Map<String, DetectionResult> _productResults = {};

  // Size of frames used for detection (for overlay scaling)
  Size? _frameSize;

  // Current position for overlay sync
  int _currentPositionMs = 0;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Pick video from gallery
  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _videoFile = File(pickedFile.path);
          _frameResults.clear();
          _productResults.clear();
          _isVideoInitialized = false;
        });
        await _processVideo();
      }
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  /// Process video: extract frames using video_thumbnail and run detection
  Future<void> _processVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Getting video info...';
    });

    try {
      final tempDir = await getTemporaryDirectory();

      // Initialize video controller to get duration and size
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!);
      await _videoController!.initialize();

      final duration = _videoController!.value.duration;
      final videoSize = _videoController!.value.size;

      if (duration.inSeconds <= 0) {
        throw Exception('Could not determine video duration');
      }

      _videoDurationMs = duration.inMilliseconds;
      // Store frame size for overlay (video's native resolution)
      _frameSize = videoSize;

      setState(() {
        _processingStatus = 'Extracting and analyzing frames...';
      });

      // Extract and process frames at the defined FPS
      final int intervalMs = (1000 / _analysisFps).round();
      int processedCount = 0;
      final int totalFramesToProcess = (_videoDurationMs / intervalMs).ceil();

      for (int timeMs = 0; timeMs < _videoDurationMs; timeMs += intervalMs) {
        // Extract thumbnail at this timestamp
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: _videoFile!.path,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          maxHeight: _videoController!.value.size.height.toInt(),
          quality: 95,
          timeMs: timeMs,
        );

        if (thumbnailPath != null) {
          final frameFile = File(thumbnailPath);

          // Run detection algorithm
          final results = await _algorithm.process(frameFile);

          // Store results for this timestamp
          _frameResults[timeMs] = results;

          // Aggregate unique product results (latest wins)
          for (final result in results) {
            if (result.qrCode != null && result.status != null) {
              _productResults[result.qrCode!] = result;
              // Update stock status
              await _updateProductStatus(result);
            }
          }

          // Clean up temp frame
          try {
            frameFile.deleteSync();
          } catch (_) {}
        }

        processedCount++;

        // Update progress
        setState(() {
          _processingProgress = processedCount / totalFramesToProcess;
          _processingStatus =
              'Analyzing frame $processedCount / $totalFramesToProcess';
        });
      }

      // Initialize video player for playback
      await _initializeVideoPlayer();

      setState(() {
        _isProcessing = false;
        _processingStatus =
            'Completed! Found ${_productResults.length} products';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error: $e';
      });
      _showError('Video processing failed: $e');
    }
  }

  /// Initialize video player for playback
  Future<void> _initializeVideoPlayer() async {
    if (_videoFile == null) return;

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(_videoFile!);

    await _videoController!.initialize();

    // Listen to position changes for overlay sync
    _videoController!.addListener(_onVideoPositionChanged);

    setState(() {
      _isVideoInitialized = true;
    });
  }

  /// Sync overlay with video position
  void _onVideoPositionChanged() {
    if (_videoController == null || !_isVideoInitialized) return;

    final position = _videoController!.value.position.inMilliseconds;

    // Only update state if we crossed into a new frame interval window
    // This optimization prevents excessive rebuilds
    final int intervalMs = (1000 / _analysisFps).round();
    final int currentFrameTime = (position / intervalMs).floor() * intervalMs;

    if (currentFrameTime != _currentPositionMs) {
      setState(() {
        _currentPositionMs = currentFrameTime;
      });
    }
  }

  /// Get results for current timestamp (or nearest processed timestamp)
  List<DetectionResult> _getCurrentFrameResults() {
    if (_frameResults.isEmpty) return [];

    // Keys are sorted if inserted in order, but let's be safe or just find nearest
    // Since we key by specific intervals, we can try to look up exact or nearest match

    // Direct lookup for best performance if we synced _currentPositionMs correctly
    if (_frameResults.containsKey(_currentPositionMs)) {
      return _frameResults[_currentPositionMs]!;
    }

    // Fallback: find nearest if exact match missing (e.g. at end of video)
    int closestTime = _frameResults.keys.first;
    int minDiff = (_currentPositionMs - closestTime).abs();

    for (final time in _frameResults.keys) {
      final diff = (_currentPositionMs - time).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestTime = time;
      }
      // Optimization: if we moved past current position significantly, break?
      // But keys might not be sorted in map iteration.
    }

    return _frameResults[closestTime] ?? [];
  }

  /// Update product status in database
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

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Analysis')),
      body: Column(
        children: [
          // Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickVideo,
              icon: const Icon(Icons.video_library),
              label: Text(
                _videoFile == null ? 'Upload Video' : 'Upload New Video',
              ),
            ),
          ),

          // Main Content Area
          Expanded(child: _buildMainContent()),

          // Results Panel
          if (_productResults.isNotEmpty) _buildResultsPanel(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Processing state
    if (_isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: _processingProgress),
              const SizedBox(height: 16),
              Text(
                '${(_processingProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _processingStatus,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // No video selected
    if (_videoFile == null) {
      return const Center(child: Text('Select a video to start analysis'));
    }

    // Video not initialized yet
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Video player with overlay
    return Column(
      children: [
        // Video with overlay
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final currentResults = _getCurrentFrameResults();

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video player fills the AspectRatio box
                      VideoPlayer(_videoController!),
                      // Overlay matches exactly using stored frame size
                      if (currentResults.isNotEmpty && _frameSize != null)
                        CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: DetectionResultPainter(
                            results: currentResults,
                            imageSize: _frameSize!,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Video controls
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Play/Pause
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                },
              ),

              // Progress slider
              Expanded(
                child: VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.blue,
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),

              // Duration
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  _formatDuration(_videoController!.value.position),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    final results = _productResults.values.toList();

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
              'Products Updated (${results.length})',
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
