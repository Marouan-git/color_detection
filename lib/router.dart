import 'package:go_router/go_router.dart';
import '../features/product_management/presentation/home_screen.dart';
import '../features/product_management/presentation/qr_screen.dart';

// Placeholder screens for routing setup
import '../features/data_capture/presentation/data_capture_screen.dart';
import '../features/data_capture/presentation/export_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/qr',
      builder: (context, state) {
        final productId = state.extra as String? ?? 'Unknown';
        return QrScreen(productId: productId);
      },
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) => const DataCaptureScreen(),
    ),
    GoRoute(path: '/export', builder: (context, state) => const ExportScreen()),
  ],
);
