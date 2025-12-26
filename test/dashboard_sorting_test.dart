import 'package:color_detection_app/features/product_management/data/product_repository.dart';
import 'package:color_detection_app/features/product_management/domain/product.dart';
import 'package:color_detection_app/features/product_management/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple Mock ProductRepository
class MockProductRepository implements ProductRepository {
  final List<Product> _products;
  MockProductRepository(this._products);

  @override
  Future<List<Product>> getProducts() async {
    return _products;
  }

  // Implement other methods as needed, or throw UnimplementedError
  @override
  Future<void> saveProduct(Product product) async {}
  @override
  Future<Product?> getProduct(String id) async => null;
  @override
  Future<void> deleteProduct(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final products = [
    Product(
      id: 'P1',
      supplier: 'Sup1',
      stockStatus: StockStatus.inStock,
      lastUpdated: DateTime(2023, 1, 1, 10, 0, 0), // Older
    ),
    Product(
      id: 'P2',
      supplier: 'Sup2',
      stockStatus: StockStatus.outOfStock,
      lastUpdated: DateTime(2023, 1, 2, 10, 0, 0), // Newer
    ),
    Product(
      id: 'P3',
      supplier: 'Sup3',
      stockStatus: StockStatus.lowStock,
      lastUpdated: DateTime(2023, 1, 1, 12, 0, 0), // Middle
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

    final p1Finder = find.text('P1');
    final p2Finder = find.text('P2');
    final p3Finder = find.text('P3');

    expect(p1Finder, findsOneWidget);
    expect(p2Finder, findsOneWidget);
    expect(p3Finder, findsOneWidget);

    final p2Position = tester.getTopLeft(p2Finder).dy;
    final p3Position = tester.getTopLeft(p3Finder).dy;
    final p1Position = tester.getTopLeft(p1Finder).dy;

    // Ordered list: P2, P3, P1
    expect(p2Position, lessThan(p3Position), reason: 'P2 should be above P3');
    expect(p3Position, lessThan(p1Position), reason: 'P3 should be above P1');
  });

  testWidgets('DashboardScreen displays seconds in Last Updated column', (
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

    // Check for the specific formatted string for P2: "2023-01-02 10:00:00"
    // P2 is: DateTime(2023, 1, 2, 10, 0, 0)
    // Format: yyyy-MM-dd HH:mm:ss
    expect(find.text('2023-01-02 10:00:00'), findsOneWidget);
  });
}
