import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/presentation/pdf_preview_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../core/utils/file_saver.dart';
import 'package:color_detection_app/features/detection/presentation/analysis_screen.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = ProductRepository();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _repository.getProducts();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to delete product "${product.id}"?',
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
      await _repository.deleteProduct(product.id);
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted')));
      }
    }
  }

  // Future<void> _saveToDownloads(File tempFile, String fileName) async {
  //   try {
  //     Directory? downloadsDir;
  //     if (Platform.isAndroid) {
  //       // Standard Android Download directory
  //       downloadsDir = Directory('/storage/emulated/0/Download');
  //       // Ensure it exists (though it should on standard Android)
  //       if (!await downloadsDir.exists()) {
  //         // Fallback if standard path doesn't exist (e.g. some emulators)
  //         downloadsDir = await getExternalStorageDirectory();
  //       }
  //     } else {
  //       // iOS/Desktop
  //       downloadsDir = await getApplicationDocumentsDirectory();
  //     }

  //     if (downloadsDir == null) {
  //       throw Exception('Could not determine download directory');
  //     }

  //     final newPath = '${downloadsDir.path}/$fileName';
  //     final newFile = await tempFile.copy(newPath);

  //     if (Platform.isAndroid) {
  //       // Show specific success for Android direct download
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Saved to Downloads: $fileName')),
  //         );
  //       }
  //     } else {
  //       // Fallback or iOS 'Save to Files'
  //       final xFile = XFile(newFile.path);
  //       await Share.shareXFiles([xFile], text: 'Exported $fileName');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
  //     }
  //   }
  // }

  Future<void> _exportCsv() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No products to export')));
      return;
    }

    try {
      final header = 'Product ID,Supplier,Stock Status\n';
      final rows = _products
          .map((p) => '${p.id},${p.supplier},${p.stockStatus.label}')
          .join('\n');
      final csvContent = '$header$rows';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/products_export.csv');
      await file.writeAsString(csvContent);

      if (mounted) {
        await saveFileToDownloads(context, file, 'products_export.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _printAllQrs() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('Product QR Codes')),
            pw.Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _products.map((product) {
                return pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: product.id,
                      width: 100,
                      height: 100,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      product.id,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          title: 'All_Product_QRs',
          buildPdf: (format) async {
            // Rebuild the PDF for the preview to ensure it matches the format if needed,
            // or just save the one we already built.
            // Since PdfPreview might request specific formats, best to rely on its callback if we want to be strict,
            // but for simplicity we'll just save the one we built above or rebuild it here if we want to support dynamic formats.
            // Actually, let's just use the one we built.
            return pdf.save();
          },
        ),
      ),
    );
  }

  Color _getStockColor(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return Colors.green;
      case StockStatus.lowStock:
        return Colors.orange;
      case StockStatus.outOfStock:
        return Colors.red;
    }
  }

  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Static Analysis',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalysisScreen()),
              );
            },
          ),
          if (_products.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_view),
              onPressed: _exportCsv,
              tooltip: 'Export to CSV',
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printAllQrs,
              tooltip: 'Print All QRs',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text('No products registered yet.'))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.swipe, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Swipe table to view actions',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _horizontalController,
                        notificationPredicate: (notification) =>
                            notification.depth == 1,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Product ID')),
                              DataColumn(label: Text('Supplier')),
                              DataColumn(label: Text('Stock')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: _products.map((product) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(product.id)),
                                  DataCell(Text(product.supplier)),
                                  DataCell(
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getStockColor(
                                              product.stockStatus,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(product.stockStatus.label),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.qr_code),
                                          onPressed: () => context.push(
                                            '/qr',
                                            extra: product.id,
                                          ),
                                          tooltip: 'View QR',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteProduct(product),
                                          tooltip: 'Delete Product',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
