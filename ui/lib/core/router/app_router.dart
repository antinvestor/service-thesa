import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_state_provider.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/profile/pages/device_detail_page.dart';
import '../../features/settings/settings_page.dart';
import '../services/service_registry.dart';
import '../widgets/responsive_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the app router with auth-aware redirect logic.
///
/// Uses [authStateProvider] to redirect:
/// - Unauthenticated users → /login
/// - Authenticated users on /login → /
/// - /logout triggers logout + redirect to /login
GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.when(
        data: (s) => s == AuthState.authenticated,
        loading: () => false,
        error: (_, _) => false,
      );
      final path = state.uri.toString();
      final isLoginRoute = path == '/login';
      final isLogoutRoute = path == '/logout';
      final isAuthCallback = path.startsWith('/auth/callback');

      // Handle logout route
      if (isLogoutRoute) {
        // Trigger logout asynchronously; redirect will handle the rest
        ref.read(authStateProvider.notifier).logout();
        return '/login';
      }

      // Allow auth callback through only while unauthenticated
      if (isAuthCallback && !isLoggedIn) return null;

      // Redirect unauthenticated users to login
      if (!isLoggedIn && !isLoginRoute) return '/login';

      // Redirect authenticated users away from login or callback
      if (isLoggedIn && (isLoginRoute || isAuthCallback)) return '/';

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginPage(),
        ),
      ),
      GoRoute(
        path: '/logout',
        redirect: (context, state) => '/login',
      ),
      // Web OAuth redirect callback — handled by auth platform
      GoRoute(
        path: '/auth/callback',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginPage(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveScaffold(
            currentRoute: state.uri.toString(),
            onNavigate: (route) => context.go(route),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
          // Service analytics page: /services/:serviceId
          GoRoute(
            path: '/services/:serviceId',
            pageBuilder: (context, state) {
              final serviceId = state.pathParameters['serviceId']!;
              return NoTransitionPage(
                child: Builder(
                  builder: (context) => ServiceRegistry.instance
                      .buildAnalyticsPage(context, serviceId),
                ),
              );
            },
            routes: [
              // Sub-feature entity list: /services/:serviceId/:featureId
              GoRoute(
                path: ':featureId',
                pageBuilder: (context, state) {
                  final serviceId = state.pathParameters['serviceId']!;
                  final featureId = state.pathParameters['featureId']!;
                  return NoTransitionPage(
                    child: Builder(
                      builder: (context) => ServiceRegistry.instance
                          .buildFeaturePage(
                              context, serviceId, featureId),
                    ),
                  );
                },
                routes: [
                  // Entity detail: /services/:serviceId/:featureId/:entityId
                  GoRoute(
                    path: ':entityId',
                    pageBuilder: (context, state) {
                      final serviceId = state.pathParameters['serviceId']!;
                      final featureId = state.pathParameters['featureId']!;
                      final entityId = state.pathParameters['entityId']!;
                      return NoTransitionPage(
                        child: Builder(
                          builder: (context) => ServiceRegistry.instance
                              .buildEntityDetailPage(
                                  context, serviceId, featureId, entityId),
                        ),
                      );
                    },
                    routes: [
                      // Device detail: /services/profile/profiles/:profileId/devices/:deviceId
                      GoRoute(
                        path: 'devices/:deviceId',
                        pageBuilder: (context, state) {
                          final profileId = state.pathParameters['entityId']!;
                          final deviceId = state.pathParameters['deviceId']!;
                          return NoTransitionPage(
                            child: DeviceDetailPage(
                              deviceId: deviceId,
                              profileId: profileId,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Provider for the app router, reactive to auth state changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(ref);

  // Re-evaluate redirects when auth state changes.
  ref.listen(authStateProvider, (previous, next) {
    router.refresh();
  });

  return router;
});
