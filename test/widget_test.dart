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
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Enter Product ID or Name'), findsOneWidget);

    // Verify Buttons - find by icon to be safe or just text
    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('Go to Data Capture'), findsOneWidget);
  });
}
