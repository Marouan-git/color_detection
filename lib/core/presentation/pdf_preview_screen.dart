import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.buildPdf,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // Force a consistent theme for the preview to ensure icons are visible
      body: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: Colors.blue,
          colorScheme: Theme.of(context).colorScheme.copyWith(
            secondary: Colors.blue, // Targeted for FABs
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: PdfPreview(
          build: buildPdf,
          useActions: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          pdfFileName: '$title.pdf',
          canDebug: false,
          actions: [
            // Custom Download Button matching the requested "Direct Download" features
            PdfPreviewAction(
              icon: const Icon(Icons.download),
              onPressed: (context, build, pageFormat) async {
                // Generate PDF bytes
                final bytes = await build(pageFormat);
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/$title.pdf');
                await file.writeAsBytes(bytes);

                if (context.mounted) {
                  // Use our shared utility (imported manually or via copy-paste for now to ensure scope)
                  // Since I can't import the new file instantly without adding import to top,
                  // I will rely on the standard "Save to Downloads" logic directly here or assume import is added.
                  // IMPORTANT: I will add the import in a subsequent step or use fully qualified if I must.
                  // For now, I'll assume standard 'Save' in PdfPreview is enough if visually fixed,
                  // BUT to be safe I'll just use the Printing package's save (which works)
                  // OR re-implement the specific path logic if they really want it in /Downloads/ specifically on Android.

                  // Let's implement the specific logic here inline to be 100% sure.
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

                    if (downloadsDir != null) {
                      final path = '${downloadsDir.path}/$title.pdf';
                      await file.copy(path);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saved PDF to: $path')),
                        );
                      }
                      return; // Success, exit early
                    }
                  } catch (e) {
                    debugPrint('Download failed, falling back to share: $e');
                  }
                  // Fallback to share if direct download failed or wasn't possible
                  await Share.shareXFiles([
                    XFile(file.path),
                  ], text: '$title.pdf');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
