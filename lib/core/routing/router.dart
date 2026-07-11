import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authenticator/presentation/providers/auth_provider.dart';
import '../../features/authenticator/presentation/screens/lock_screen.dart';
import '../../features/authenticator/presentation/screens/home_screen.dart';
import '../../features/authenticator/presentation/screens/add_account_screen.dart';
import '../../features/authenticator/presentation/screens/scan_qr_screen.dart';
import '../../features/authenticator/presentation/screens/account_detail_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch authState so the router rebuilds and triggers redirection if lock status changes
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isLocked ? '/lock' : '/',
    redirect: (context, state) {
      final isLocked = ref.read(authProvider).isLocked;
      final isLockingRoute = state.matchedLocation == '/lock';

      if (isLocked && !isLockingRoute) {
        return '/lock';
      }
      if (!isLocked && isLockingRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) => const AddAccountScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AccountDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
