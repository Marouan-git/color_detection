import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final directory = await getApplicationDocumentsDirectory();
    final captureDir = Directory('${directory.path}/captures');

    // Create folders if they don't exist logic should be in capture, but safe check here
    final imagesDir = Directory('${captureDir.path}/images');
    final videosDir = Directory('${captureDir.path}/videos');

    List<FileSystemEntity> files = [];

    if (await imagesDir.exists()) {
      files.addAll(imagesDir.listSync());
    }
    if (await videosDir.exists()) {
      files.addAll(videosDir.listSync());
    }

    // Sort by modification time descending
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    setState(() {
      _files = files.whereType<File>().toList();
      _loading = false;
    });
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await file.delete();
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
          ),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete ALL captured images and videos. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        final directory = await getApplicationDocumentsDirectory();
        final captureDir = Directory('${directory.path}/captures');
        if (await captureDir.exists()) {
          await captureDir.delete(recursive: true);
        }
        await _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('All data cleared')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing data: $e')));
        }
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveToDownloads(File tempFile, String fileName) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir != null) {
        final newPath = '${downloadsDir.path}/$fileName';
        await tempFile.copy(newPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to $newPath'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            ),
          );
        }
        return;
      }
    } catch (e) {
      // Fallback to share
    }

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(tempFile.path)], text: fileName);
  }

  Future<void> _exportZip() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No files to export')));
      return;
    }

    setState(() => _loading = true);
    try {
      final directory =
          await getTemporaryDirectory(); // Use temp for zip creation
      final captureDir = await getApplicationDocumentsDirectory().then(
        (d) => Directory('${d.path}/captures'),
      );

      var encoder = ZipFileEncoder();
      final zipPath = '${directory.path}/captures_export.zip';
      encoder.create(zipPath);

      if (await captureDir.exists()) {
        await encoder.addDirectory(captureDir);
      }
      encoder.close();

      final zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await _saveToDownloads(zipFile, 'captures_export.zip');
      } else {
        throw Exception('Zip file creation failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _viewFile(File file) async {
    final bool? deleted = await (file.path.endsWith('.mp4')
        ? Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(file: file),
            ),
          )
        : Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => ImageViewerScreen(file: file),
            ),
          ));

    if (deleted == true) {
      _loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Gallery'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download,
            ), // Changed to download icon as requested
            tooltip: 'Export/Save ZIP',
            onPressed: _exportZip,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearAllData();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Text('Clear All Data'),
                ),
              ];
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? const Center(child: Text('No captures found.'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index] as File;
                final isVideo = file.path.endsWith('.mp4');
                return GestureDetector(
                  onTap: () => _viewFile(file),
                  onLongPress: () => _deleteFile(file),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!isVideo)
                        Image.file(file, fit: BoxFit.cover)
                      else
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isVideo)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final File file;
  const ImageViewerScreen({super.key, required this.file});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await file.delete();
      if (context.mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Center(child: Image.file(file)),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File file;
  const VideoPlayerScreen({super.key, required this.file});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
          _controller.play();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    // Pause playback before confirming
    _controller.pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.file.delete();
      if (context.mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
