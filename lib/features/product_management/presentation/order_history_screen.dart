import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/file_saver.dart';
import '../data/product_repository.dart';
import '../domain/order_record.dart';

class OrderHistoryScreen extends StatefulWidget {
  final ProductRepository? repository;
  final String? filterProductId; // Optional: filter by product

  const OrderHistoryScreen({super.key, this.repository, this.filterProductId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late final ProductRepository _repository;
  List<OrderRecord> _orders = [];
  bool _loading = true;

  // Sorting
  String _sortBy = 'date_newest';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductRepository();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    List<OrderRecord> orders;
    if (widget.filterProductId != null) {
      orders = await _repository.getOrderHistoryForProduct(
        widget.filterProductId!,
      );
    } else {
      orders = await _repository.getOrderHistory();
    }

    _sortOrders(orders);

    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  void _sortOrders(List<OrderRecord> orders) {
    switch (_sortBy) {
      case 'date_newest':
        orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        break;
      case 'date_oldest':
        orders.sort((a, b) => a.orderDate.compareTo(b.orderDate));
        break;
      case 'supplier':
        orders.sort((a, b) => a.supplier.compareTo(b.supplier));
        break;
      case 'product':
        orders.sort((a, b) => a.productId.compareTo(b.productId));
        break;
    }
  }

  Future<void> _exportCsv() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No orders to export')));
      return;
    }

    try {
      final header =
          'Order ID,Stock Code,Supplier,Order Date,Previous Order Date,Order Interval,Quantity,Delivered,Delivery Date\n';
      final rows = _orders
          .map((o) {
            final interval = o.previousOrderDate != null
                ? _formatInterval(o.orderDate.difference(o.previousOrderDate!))
                : '';
            // Format dates without seconds (yyyy-MM-ddTHH:mm)
            final orderDate = o.orderDate.toIso8601String().substring(0, 16);
            final prevDate =
                o.previousOrderDate?.toIso8601String().substring(0, 16) ?? '';
            final delivDate =
                o.deliveryDate?.toIso8601String().substring(0, 16) ?? '';
            return '${o.id},${o.productId},${o.supplier},$orderDate,$prevDate,$interval,${o.quantity},${o.delivered},$delivDate';
          })
          .join('\n');
      final csvContent = '$header$rows';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/order_history_export.csv');
      await file.writeAsString(csvContent);

      if (mounted) {
        await saveFileToDownloads(context, file, 'order_history_export.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Formats a Duration as "Xd Yh Zm"
  String _formatInterval(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Future<void> _confirmDeleteOrder(OrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order?'),
        content: Text(
          'Are you sure you want to delete this pending order for "${order.productId}"?\n\nThis action cannot be undone.',
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
      await _repository.deleteOrderRecord(order.id);
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order for ${order.productId} deleted')),
        );
      }
    }
  }

  Future<void> _confirmDelivery(OrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text(
          'Mark order for "${order.productId}" (Qty: ${order.quantity}) as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedOrder = order.copyWith(
        delivered: true,
        deliveryDate: DateTime.now(),
      );
      await _repository.updateOrderRecord(updatedOrder);
      await _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${order.productId} marked as delivered')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filterProductId != null
              ? 'Order History: ${widget.filterProductId}'
              : 'All Order History',
        ),
        actions: [
          if (_orders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.table_view),
              onPressed: _exportCsv,
              tooltip: 'Export to CSV',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sort options
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(
                            value: 'date_newest',
                            child: Text('Newest First'),
                          ),
                          DropdownMenuItem(
                            value: 'date_oldest',
                            child: Text('Oldest First'),
                          ),
                          DropdownMenuItem(
                            value: 'supplier',
                            child: Text('By Supplier'),
                          ),
                          DropdownMenuItem(
                            value: 'product',
                            child: Text('By Product'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortBy = val;
                              _sortOrders(_orders);
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${_orders.length} orders',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Orders list
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(child: Text('No orders found.'))
                      : ListView.builder(
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: order.delivered
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                  child: Icon(
                                    order.delivered
                                        ? Icons.check
                                        : Icons.hourglass_top,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(order.productId),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Supplier: ${order.supplier}'),
                                    Text(
                                      'Ordered: ${_formatDate(order.orderDate)}',
                                    ),
                                    if (order.previousOrderDate != null) ...[
                                      Text(
                                        'Previous Order: ${_formatDate(order.previousOrderDate!)}',
                                      ),
                                      Text(
                                        'Interval: ${_formatInterval(order.orderDate.difference(order.previousOrderDate!))}',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    Text('Quantity: ${order.quantity}'),
                                    if (order.delivered &&
                                        order.deliveryDate != null)
                                      Text(
                                        'Delivered: ${_formatDate(order.deliveryDate!)}',
                                      ),
                                    const SizedBox(height: 8),
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: order.delivered
                                            ? Colors.green[50]
                                            : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: order.delivered
                                              ? Colors.green[300]!
                                              : Colors.orange[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        order.delivered
                                            ? 'Delivered'
                                            : 'Pending',
                                        style: TextStyle(
                                          color: order.delivered
                                              ? Colors.green[800]
                                              : Colors.orange[800],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: order.delivered
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteOrder(order),
                                            tooltip: 'Delete order',
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: false,
                                                onChanged: (_) =>
                                                    _confirmDelivery(order),
                                              ),
                                              const Text(
                                                'Delivered',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
