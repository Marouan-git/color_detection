import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveFileToDownloads(
  BuildContext context,
  File file,
  String fileName,
) async {
  try {
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      throw Exception('Could not determine download directory');
    }

    final newPath = '${downloadsDir.path}/$fileName';
    final newFile = await file.copy(newPath);

    if (Platform.isAndroid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads: $fileName')),
        );
      }
    } else {
      final xFile = XFile(newFile.path);
      await Share.shareXFiles([xFile], text: 'Exported $fileName');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
    }
  }
}
