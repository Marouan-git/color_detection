import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

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
      body: PdfPreview(
        build: buildPdf,
        useActions: true, // Standard print/share actions
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: '$title.pdf',
        // Force actions to be visible by using standard Material widgets inside PdfPreview
        // Note: PdfPreview usually uses standard IconButtons which respect theme.
        // If native 'layoutPdf' was using a platform dialog, this widget uses Flutter UI.
      ),
    );
  }
}
