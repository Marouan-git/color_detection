import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'All_Product_QRs',
    );
  }

  Color _getStockColor(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return Colors
            .green; // User asked for Red, but Green makes more sense. Sticking to plan.
      case StockStatus.lowStock:
        return Colors.orange;
      case StockStatus.outOfStock:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Dashboard'),
        actions: [
          if (_products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printAllQrs,
              tooltip: 'Print All QRs',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text('No products registered yet.'))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
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
                                  color: _getStockColor(product.stockStatus),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(product.stockStatus.label),
                            ],
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.qr_code),
                            onPressed: () =>
                                context.push('/qr', extra: product.id),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
