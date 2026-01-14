import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/product.dart';
import '../domain/order_record.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

class ProductRepository {
  static const String _productsFileName = 'products.json';
  static const String _ordersFileName = 'order_history.json';

  Future<File> get _productsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_productsFileName');
  }

  Future<File> get _ordersFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_ordersFileName');
  }

  // ==================== Products ====================

  Future<List<Product>> getProducts() async {
    try {
      final file = await _productsFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveProduct(Product product) async {
    final products = await getProducts();
    // Remove if exists to replace
    products.removeWhere((p) => p.id == product.id);
    products.add(product);

    final file = await _productsFile;
    final jsonList = products.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> deleteProduct(String id) async {
    final products = await getProducts();
    products.removeWhere((p) => p.id == id);

    final file = await _productsFile;
    final jsonList = products.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<Product?> getProduct(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // ==================== Order History ====================

  Future<List<OrderRecord>> getOrderHistory() async {
    try {
      final file = await _ordersFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => OrderRecord.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<OrderRecord>> getOrderHistoryForProduct(String productId) async {
    final allOrders = await getOrderHistory();
    return allOrders.where((o) => o.productId == productId).toList();
  }

  Future<void> addOrderRecord(OrderRecord order) async {
    final orders = await getOrderHistory();
    orders.add(order);

    final file = await _ordersFile;
    final jsonList = orders.map((o) => o.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> updateOrderRecord(OrderRecord order) async {
    final orders = await getOrderHistory();
    final index = orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      orders[index] = order;
      final file = await _ordersFile;
      final jsonList = orders.map((o) => o.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    }
  }

  Future<void> deleteOrderRecord(String orderId) async {
    final orders = await getOrderHistory();
    orders.removeWhere((o) => o.id == orderId);

    final file = await _ordersFile;
    final jsonList = orders.map((o) => o.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Gets pending (non-delivered) orders for a specific product and supplier (case-insensitive)
  Future<List<OrderRecord>> getPendingOrdersForProductAndSupplier(
    String productId,
    String supplier,
  ) async {
    final allOrders = await getOrderHistory();
    return allOrders
        .where(
          (o) =>
              !o.delivered &&
              o.productId == productId &&
              o.supplier.toLowerCase() == supplier.toLowerCase(),
        )
        .toList();
  }

  /// Creates an order record and updates the product's order status
  /// [supplier] - Optional custom supplier, defaults to product's default supplier
  Future<void> createOrder(
    Product product,
    int quantity, {
    String? supplier,
  }) async {
    final orderSupplier = supplier ?? product.supplier;

    // Find the most recent order for this product to get previous order date
    final existingOrders = await getOrderHistoryForProduct(product.id);
    DateTime? previousOrderDate;
    if (existingOrders.isNotEmpty) {
      existingOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      previousOrderDate = existingOrders.first.orderDate;
    }

    // Create order record
    final order = OrderRecord(
      id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      supplier: orderSupplier,
      orderDate: DateTime.now(),
      quantity: quantity,
      previousOrderDate: previousOrderDate,
    );
    await addOrderRecord(order);

    // Update product status
    final updatedProduct = product.copyWith(
      isOrdered: true,
      isDelivered: false,
      quantityOrdered: quantity,
      lastOrderDate: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
    await saveProduct(updatedProduct);
  }

  /// Marks an order as delivered and updates product status
  Future<void> markDelivered(Product product) async {
    // Find and update the most recent undelivered order
    final orders = await getOrderHistoryForProduct(product.id);
    final undeliveredOrders = orders.where((o) => !o.delivered).toList();

    if (undeliveredOrders.isNotEmpty) {
      // Sort by date, mark most recent as delivered
      undeliveredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      final latestOrder = undeliveredOrders.first.copyWith(
        delivered: true,
        deliveryDate: DateTime.now(),
      );
      await updateOrderRecord(latestOrder);
    }

    // Update product: clear ordered flag (per user requirement)
    final updatedProduct = product.copyWith(
      isOrdered: false,
      isDelivered: true,
      lastUpdated: DateTime.now(),
    );
    await saveProduct(updatedProduct);
  }
}
