import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

Future<void> saveFileToDownloads(
  BuildContext context,
  File tempFile,
  String fileName,
) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      // Use flutter_file_dialog for proper system integration
      final extension = fileName.split('.').last.toLowerCase();
      String? mimeType;
      if (extension == 'zip') {
        mimeType = 'application/zip';
      } else if (extension == 'csv') {
        mimeType = 'text/csv';
      } else if (extension == 'pdf') {
        mimeType = 'application/pdf';
      }

      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeTypesFilter: mimeType != null ? [mimeType] : null,
      );

      final filePath = await FlutterFileDialog.saveFile(params: params);

      if (filePath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ File saved successfully'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Desktop fallback
      await _shareFile(tempFile, fileName);
    }
  } catch (e) {
    debugPrint('Error saving file: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save failed. Using share instead.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _shareFile(tempFile, fileName);
  }
}

Future<void> _shareFile(File file, String fileName) async {
  // ignore: deprecated_member_use
  await Share.shareXFiles([XFile(file.path)], text: fileName);
}
