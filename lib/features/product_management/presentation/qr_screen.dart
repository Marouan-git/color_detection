// import 'dart:io';
// import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/presentation/pdf_preview_screen.dart';
// import 'package:share_plus/share_plus.dart';

class QrScreen extends StatefulWidget {
  final String productId;
  const QrScreen({super.key, required this.productId});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _saveAsPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(widget.productId, style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: widget.productId,
                  width: 200,
                  height: 200,
                ),
              ],
            ),
          );
        },
      ),
    );

    // Navigate to preview instead of direct print
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          title: 'QR_${widget.productId}',
          buildPdf: (format) async {
            // Rebuild PDF with format if needed, or just return saved byte data
            // The previous logic built it on the fly. Let's keep it simple.
            // We need to return Uint8List.
            final pdf = pw.Document();
            pdf.addPage(
              pw.Page(
                pageFormat: format,
                build: (pw.Context context) {
                  return pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          widget.productId,
                          style: const pw.TextStyle(fontSize: 24),
                        ),
                        pw.SizedBox(height: 20),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: widget.productId,
                          width: 200,
                          height: 200,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
            return pdf.save();
          },
        ),
      ),
    );
  }

  /*
  Future<void> _shareImage() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${widget.productId}.png');
      await file.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'QR Code for ${widget.productId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
      }
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.productId,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(
                  data: widget.productId,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _saveAsPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Print / Save PDF'),
                  style: ElevatedButton.styleFrom(
                    // Ensure visibility in dark mode (Blue BG, White Text)
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                // const SizedBox(width: 16),
                // OutlinedButton.icon(
                //   onPressed: _shareImage,
                //   icon: const Icon(Icons.share),
                //   label: const Text('Share Image'),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
