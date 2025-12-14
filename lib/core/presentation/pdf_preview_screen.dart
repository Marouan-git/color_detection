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
        ),
      ),
    );
  }
}
