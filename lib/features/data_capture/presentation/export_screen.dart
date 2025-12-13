import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
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
    if (await captureDir.exists()) {
      final files = captureDir.listSync();
      setState(() {
        _files = files.whereType<File>().toList();
        _loading = false;
      });
    } else {
      setState(() {
        _files = [];
        _loading = false;
      });
    }
  }

  Future<void> _exportData() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final captureDir = Directory('${directory.path}/captures');
      final zipFile = File('${directory.path}/captures.zip');

      var encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addDirectory(captureDir, followLinks: false);
      encoder.close();

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(zipFile.path)], text: 'Captured Data');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
      }
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data?'),
        content: const Text(
          'This will delete all captured photos and videos. This action cannot be undone.',
        ),
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
      final directory = await getApplicationDocumentsDirectory();
      final captureDir = Directory('${directory.path}/captures');
      if (await captureDir.exists()) {
        await captureDir.delete(recursive: true);
        _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Data cleared')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Data'),
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _clearData,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? const Center(child: Text('No captured data found.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final name = file.path.split('/').last;
                      return ListTile(
                        leading: Icon(
                          name.endsWith('.mp4') ? Icons.videocam : Icons.image,
                        ),
                        title: Text(name),
                        trailing: Text(
                          '${(File(file.path).lengthSync() / 1024).toStringAsFixed(1)} KB',
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.share),
                    label: const Text('Export All Data (ZIP)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
