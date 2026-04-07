import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_state_provider.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/splash_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/payment/pages/account_detail_page.dart';
import '../../features/profile/pages/device_detail_page.dart';
import '../services/service_registry.dart';
import '../widgets/responsive_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the app router with auth-aware redirect logic.
///
/// Three states are handled:
/// - **Loading**: auth is being determined → show splash (no redirect)
/// - **Unauthenticated**: redirect to /login
/// - **Authenticated**: redirect away from /login and /auth/callback to /
GoRouter createAppRouter(Ref ref, {String initialLocation = '/'}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final routePath = state.uri.path;
      final isLoginRoute = routePath == '/login';
      final isLogoutRoute = routePath == '/logout';
      final isAuthCallback = routePath == '/auth/callback';
      final isSplash = routePath == '/splash';

      // Handle logout — always process immediately
      if (isLogoutRoute) {
        ref.read(authStateProvider.notifier).logout();
        return '/login';
      }

      // Determine auth status with proper loading handling
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.whenOrNull(
            data: (s) => s == AuthState.authenticated,
          ) ??
          false;

      // While auth is loading, send to splash unless already there or on
      // the callback route (which needs to complete the OAuth flow).
      if (isLoading) {
        if (isAuthCallback || isSplash) return null;
        return '/splash';
      }

      // Auth callback while unauthenticated — let it through so the
      // OAuth exchange can complete.
      if (isAuthCallback && !isAuthenticated) return null;

      // Unauthenticated user on any protected route → login
      if (!isAuthenticated && !isLoginRoute) return '/login';

      // Authenticated user on login, callback, or splash → dashboard
      if (isAuthenticated && (isLoginRoute || isAuthCallback || isSplash)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashPage(),
        ),
      ),
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
      // Web OAuth redirect callback — shows splash while processing
      GoRoute(
        path: '/auth/callback',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashPage(),
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
            redirect: (context, state) => '/services/settings/all',
          ),
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
                      GoRoute(
                        path: 'accounts/:accountId',
                        pageBuilder: (context, state) {
                          final ledgerId = state.pathParameters['entityId']!;
                          final accountId =
                              state.pathParameters['accountId']!;
                          return NoTransitionPage(
                            child: AccountDetailPage(
                              ledgerId: ledgerId,
                              accountId: accountId,
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
