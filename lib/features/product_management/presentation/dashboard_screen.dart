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
import 'order_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ProductRepository? repository;
  const DashboardScreen({super.key, this.repository});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ProductRepository _repository;
  List<Product> _products = [];
  bool _loading = true;

  // Sorting
  String _sortBy = 'date_newest';

  // Filtering
  StockStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductRepository();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _repository.getProducts();
    _sortProducts(products);
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _sortProducts(List<Product> products) {
    switch (_sortBy) {
      case 'date_newest':
        products.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case 'date_oldest':
        products.sort((a, b) => a.lastUpdated.compareTo(b.lastUpdated));
        break;
      case 'supplier':
        products.sort((a, b) => a.supplier.compareTo(b.supplier));
        break;
      case 'stock_code':
        products.sort((a, b) => a.stockCode.compareTo(b.stockCode));
        break;
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to delete product "${product.stockCode}"?',
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

  /// Shows order confirmation dialog with quantity input and editable supplier
  Future<void> _showOrderDialog(Product product) async {
    final quantityController = TextEditingController(text: '1');
    final supplierController = TextEditingController(text: product.supplier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: ${product.stockCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier',
                border: OutlineInputBorder(),
                helperText: 'Edit if ordering from a different supplier',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final quantity = int.tryParse(quantityController.text) ?? 1;
      final supplier = supplierController.text.trim();

      if (supplier.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier cannot be empty')),
          );
        }
        return;
      }

      // Check for existing pending orders with the same product and supplier
      final pendingOrders = await _repository
          .getPendingOrdersForProductAndSupplier(product.id, supplier);

      if (pendingOrders.isNotEmpty && mounted) {
        final action = await _showDuplicateOrderDialog(pendingOrders.length);
        if (action == null || action == 'cancel') return;
        if (action == 'replace') {
          // Delete existing pending orders for this supplier
          for (final order in pendingOrders) {
            await _repository.deleteOrderRecord(order.id);
          }
        }
        // 'add' action falls through to create the order
      }

      await _repository.createOrder(product, quantity, supplier: supplier);
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order created for ${product.stockCode} (Qty: $quantity) with $supplier',
            ),
          ),
        );
      }
    }
  }

  /// Shows dialog when duplicate pending order exists for same supplier
  Future<String?> _showDuplicateOrderDialog(int pendingCount) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Order Exists'),
        content: Text(
          'There ${pendingCount == 1 ? 'is' : 'are'} already $pendingCount pending order(s) '
          'for this supplier. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Add Alongside'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv({bool onlyToBeOrdered = false}) async {
    var productsToExport = _products;

    // Filter to only red (out of stock) and yellow (low stock) if requested
    if (onlyToBeOrdered) {
      productsToExport = _products
          .where(
            (p) =>
                p.stockStatus == StockStatus.outOfStock ||
                p.stockStatus == StockStatus.lowStock,
          )
          .toList();
    }

    if (productsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onlyToBeOrdered
                ? 'No products need ordering'
                : 'No products to export',
          ),
        ),
      );
      return;
    }

    try {
      final header =
          'Default Supplier,Stock Code,Stock Status,Last Scanned,Last Order Date,Quantity Ordered\n';
      final rows = productsToExport
          .map((p) {
            final lastScanned =
                p.lastUpdated?.toIso8601String().substring(0, 16) ?? '';
            final lastOrder =
                p.lastOrderDate?.toIso8601String().substring(0, 16) ?? '';
            return '${p.supplier},${p.stockCode},${p.stockStatus.label},$lastScanned,$lastOrder,${p.quantityOrdered ?? ''}';
          })
          .join('\n');
      final csvContent = '$header$rows';

      final directory = await getTemporaryDirectory();
      final filename = onlyToBeOrdered
          ? 'products_to_order.csv'
          : 'products_export.csv';
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csvContent);

      if (mounted) {
        await saveFileToDownloads(context, file, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Show export options dialog
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export to CSV'),
        content: const Text('Choose what to export:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportCsv(onlyToBeOrdered: true);
            },
            child: const Text(
              'To Be Ordered\n(Red & Yellow)',
              textAlign: TextAlign.center,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportCsv(onlyToBeOrdered: false);
            },
            child: const Text('Full Inventory'),
          ),
        ],
      ),
    );
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
                      data: product.stockCode, // Use stockCode for QR
                      width: 100,
                      height: 100,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      product.stockCode,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      product.supplier,
                      style: const pw.TextStyle(fontSize: 8),
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
          buildPdf: (format) async => pdf.save(),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Filter logic
    final displayedProducts = _filterStatus == null
        ? _products
        : _products.where((p) => p.stockStatus == _filterStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                  break;
                case 'analysis':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalysisScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadProducts();
                  }
                  break;
                case 'csv':
                  _showExportOptions();
                  break;
                case 'print':
                  _printAllQrs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Order History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'analysis',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined),
                    SizedBox(width: 8),
                    Text('Analysis'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_view),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text('Print QRs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Status Summary
                if (_products.isNotEmpty) _buildStatusSummary(),

                // 2. Filter & Sort Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      // Filter dropdown
                      const Icon(Icons.filter_list, size: 20),
                      const SizedBox(width: 8),
                      DropdownButton<StockStatus>(
                        value: _filterStatus,
                        hint: const Text('Filter'),
                        underline: Container(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All'),
                          ),
                          ...StockStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getStockColor(status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(status.label),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _filterStatus = val),
                      ),
                      const SizedBox(width: 16),

                      // Sort dropdown
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(
                            value: 'date_newest',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'date_oldest',
                            child: Text('Oldest'),
                          ),
                          DropdownMenuItem(
                            value: 'supplier',
                            child: Text('Supplier'),
                          ),
                          DropdownMenuItem(
                            value: 'stock_code',
                            child: Text('Stock Code'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortBy = val;
                              _sortProducts(_products);
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      const Icon(Icons.swipe, size: 15, color: Colors.grey),
                      //const SizedBox(width: 4),
                      // const Text(
                      //   'Swipe',
                      //   style: TextStyle(
                      //     color: Colors.grey,
                      //     fontStyle: FontStyle.italic,
                      //     fontSize: 12,
                      //   ),
                      // ),
                    ],
                  ),
                ),

                // 3. Data Table
                Expanded(
                  child: displayedProducts.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : Scrollbar(
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
                                    DataColumn(label: Text('Default Supplier')),
                                    DataColumn(label: Text('Stock Code')),
                                    DataColumn(label: Text('Stock')),
                                    DataColumn(label: Text('Last Scanned')),
                                    DataColumn(label: Text('Last ordered')),
                                    DataColumn(label: Text('Order')),
                                    DataColumn(label: Text('History')),
                                    DataColumn(label: Text('QR')),
                                    DataColumn(label: Text('Delete')),
                                  ],
                                  rows: displayedProducts.map((product) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(product.supplier)),
                                        DataCell(Text(product.stockCode)),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
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
                                        // Last Scanned
                                        DataCell(
                                          Text(
                                            _formatDate(product.lastUpdated),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        // Last Ordered
                                        DataCell(
                                          Text(
                                            product.lastOrderDate != null
                                                ? _formatDate(
                                                    product.lastOrderDate!,
                                                  )
                                                : '-',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_shopping_cart,
                                            ),
                                            onPressed: () =>
                                                _showOrderDialog(product),
                                            tooltip: 'New Order',
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.history),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      OrderHistoryScreen(
                                                        filterProductId:
                                                            product.id,
                                                      ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Order History',
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.qr_code),
                                            onPressed: () => context.push(
                                              '/qr',
                                              extra: product.stockCode,
                                            ),
                                            tooltip: 'View QR',
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _deleteProduct(product),
                                            tooltip: 'Delete',
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

  Widget _buildStatusSummary() {
    final counts = <StockStatus, int>{};
    for (var s in StockStatus.values) {
      counts[s] = _products.where((p) => p.stockStatus == s).length;
    }

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: StockStatus.values.map((status) {
            final color = _getStockColor(status);
            return Column(
              children: [
                Text(
                  counts[status].toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(status.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
