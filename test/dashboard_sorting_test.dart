import 'package:color_detection_app/features/product_management/data/product_repository.dart';
import 'package:color_detection_app/features/product_management/domain/product.dart';
import 'package:color_detection_app/features/product_management/domain/order_record.dart';
import 'package:color_detection_app/features/product_management/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple Mock ProductRepository
class MockProductRepository implements ProductRepository {
  final List<Product> _products;
  final List<OrderRecord> _orders = [];
  MockProductRepository(this._products);

  @override
  Future<List<Product>> getProducts() async => _products;

  @override
  Future<void> saveProduct(Product product) async {
    _products.removeWhere((p) => p.id == product.id);
    _products.add(product);
  }

  @override
  Future<Product?> getProduct(String id) async {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
  }

  // Order history methods
  @override
  Future<List<OrderRecord>> getOrderHistory() async => _orders;

  @override
  Future<List<OrderRecord>> getOrderHistoryForProduct(String productId) async {
    return _orders.where((o) => o.productId == productId).toList();
  }

  @override
  Future<void> addOrderRecord(OrderRecord order) async {
    _orders.add(order);
  }

  @override
  Future<void> updateOrderRecord(OrderRecord order) async {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) _orders[index] = order;
  }

  @override
  Future<void> deleteOrderRecord(String orderId) async {
    _orders.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<List<OrderRecord>> getPendingOrdersForProductAndSupplier(
    String productId,
    String supplier,
  ) async {
    return _orders
        .where(
          (o) =>
              !o.delivered &&
              o.productId == productId &&
              o.supplier.toLowerCase() == supplier.toLowerCase(),
        )
        .toList();
  }

  @override
  Future<void> createOrder(
    Product product,
    int quantity, {
    String? supplier,
  }) async {
    final orderSupplier = supplier ?? product.supplier;

    // Find the most recent order for this product to get previous order date
    final existingOrders = _orders
        .where((o) => o.productId == product.id)
        .toList();
    DateTime? previousOrderDate;
    if (existingOrders.isNotEmpty) {
      existingOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      previousOrderDate = existingOrders.first.orderDate;
    }

    final order = OrderRecord(
      id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      supplier: orderSupplier,
      orderDate: DateTime.now(),
      quantity: quantity,
      previousOrderDate: previousOrderDate,
    );
    _orders.add(order);

    final updated = product.copyWith(
      isOrdered: true,
      quantityOrdered: quantity,
      lastOrderDate: DateTime.now(),
    );
    await saveProduct(updated);
  }

  @override
  Future<void> markDelivered(Product product) async {
    final updated = product.copyWith(isOrdered: false, isDelivered: true);
    await saveProduct(updated);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final products = [
    Product(
      id: 'P1',
      supplier: 'Sup1',
      stockCode: 'SC001',
      stockStatus: StockStatus.inStock,
      lastUpdated: DateTime(2023, 1, 1, 10, 0, 0),
      lastOrderDate: DateTime(2023, 1, 1, 10, 0, 0), // Older
    ),
    Product(
      id: 'P2',
      supplier: 'Sup2',
      stockCode: 'SC002',
      stockStatus: StockStatus.outOfStock,
      lastUpdated: DateTime(2023, 1, 2, 10, 0, 0),
      lastOrderDate: DateTime(2023, 1, 2, 10, 0, 0), // Newer
    ),
    Product(
      id: 'P3',
      supplier: 'Sup3',
      stockCode: 'SC003',
      stockStatus: StockStatus.lowStock,
      lastUpdated: DateTime(2023, 1, 1, 12, 0, 0),
      lastOrderDate: DateTime(2023, 1, 1, 12, 0, 0), // Middle
    ),
  ];

  testWidgets('DashboardScreen sorts products by lastUpdated descending', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(repository: MockProductRepository(products)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check for stock codes instead of product IDs in the table
    final sc001Finder = find.text('SC001');
    final sc002Finder = find.text('SC002');
    final sc003Finder = find.text('SC003');

    expect(sc001Finder, findsOneWidget);
    expect(sc002Finder, findsOneWidget);
    expect(sc003Finder, findsOneWidget);

    final sc002Position = tester.getTopLeft(sc002Finder).dy;
    final sc003Position = tester.getTopLeft(sc003Finder).dy;
    final sc001Position = tester.getTopLeft(sc001Finder).dy;

    // Ordered list: SC002, SC003, SC001 (by date descending)
    expect(
      sc002Position,
      lessThan(sc003Position),
      reason: 'SC002 should be above SC003',
    );
    expect(
      sc003Position,
      lessThan(sc001Position),
      reason: 'SC003 should be above SC001',
    );
  });

  testWidgets('DashboardScreen displays date in Last ordered column', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(repository: MockProductRepository(products)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check for the formatted date from lastOrderDate
    // P2 has lastOrderDate: DateTime(2023, 1, 2, 10, 0, 0)
    // Format: yyyy-MM-dd HH:mm
    expect(find.text('2023-01-02 10:00'), findsOneWidget);
  });
}
