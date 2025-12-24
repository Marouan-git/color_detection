import 'package:go_router/go_router.dart';
import '../features/product_management/presentation/home_screen.dart';
import '../features/product_management/presentation/qr_screen.dart';
import '../features/product_management/presentation/dashboard_screen.dart';
import '../features/data_capture/presentation/gallery_screen.dart';

// Placeholder screens for routing setup
import '../features/data_capture/presentation/data_capture_screen.dart';
import '../features/detection/presentation/analysis_screen.dart';

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
    GoRoute(
      path: '/export',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/analysis',
      builder: (context, state) => const AnalysisScreen(),
    ),
  ],
);
