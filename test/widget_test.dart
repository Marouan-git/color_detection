import 'package:color_detection_app/features/product_management/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen has input and buttons', (WidgetTester tester) async {
    // Wrapped in MaterialApp with default theme to avoid GoogleFonts loading in tests
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Verify Title
    expect(find.text('Traffic Sensor Detection'), findsOneWidget);

    // Verify Product Management Header
    expect(find.text('Product Management'), findsOneWidget);

    // Verify Inputs
    expect(find.text('Product ID'), findsOneWidget);
    expect(find.text('Supplier'), findsOneWidget);
    expect(
      find.byType(TextFormField),
      findsNWidgets(2),
    ); // Product ID and Supplier
    expect(
      find.text('Stock Status'),
      findsOneWidget,
    ); // Find label for Dropdown

    // Verify Buttons
    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('View Product Dashboard'), findsOneWidget);
    expect(find.text('Go to Data Capture'), findsOneWidget);
    expect(find.text('Manage Captured Data'), findsOneWidget);
  });
}
