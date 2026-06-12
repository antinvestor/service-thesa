import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart'
    show AuditRouteModule;
import 'package:antinvestor_ui_billing/antinvestor_ui_billing.dart'
    show BillingRouteModule;
import 'package:antinvestor_ui_core/antinvestor_ui_core.dart'
    show RouteModule;
import 'package:antinvestor_ui_device/antinvestor_ui_device.dart'
    show DeviceRouteModule;
import 'package:antinvestor_ui_files/antinvestor_ui_files.dart'
    show FilesRouteModule;
import 'package:antinvestor_ui_fort/antinvestor_ui_fort.dart'
    show FortRouteModule;
import 'package:antinvestor_ui_geolocation/antinvestor_ui_geolocation.dart'
    show GeolocationRouteModule;
import 'package:antinvestor_ui_ledger/antinvestor_ui_ledger.dart'
    show LedgerRouteModule;
import 'package:antinvestor_ui_notification/antinvestor_ui_notification.dart'
    show NotificationRouteModule;
import 'package:antinvestor_ui_payment/antinvestor_ui_payment.dart'
    show PaymentRouteModule;
import 'package:antinvestor_ui_profile/antinvestor_ui_profile.dart'
    show ProfileRouteModule;
import 'package:antinvestor_ui_settings/antinvestor_ui_settings.dart'
    show SettingsRouteModule;
import 'package:antinvestor_ui_tenancy/antinvestor_ui_tenancy.dart'
    show TenancyRouteModule;
import 'package:antinvestor_ui_trustage/antinvestor_ui_trustage.dart'
    show TrustageRouteModule;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_state_provider.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/splash_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/support/support_page.dart';
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
      final isAuthenticated =
          authState.whenOrNull(data: (s) => s == AuthState.authenticated) ??
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
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(path: '/logout', redirect: (context, state) => '/login'),
      // Web OAuth redirect callback — shows splash while processing
      GoRoute(
        path: '/auth/callback',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashPage()),
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
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          // Sidebar Support item — informational page (contacts, docs,
          // version) so the route resolves instead of "no routes for
          // location: /support".
          GoRoute(
            path: '/support',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportPage()),
          ),
          // Package route modules own their canonical paths (/notifications,
          // /payments, /profiles, /files, /billing, /settings, /services/audit,
          // /services/tenancy, /services/fort, …). Their screens hard-navigate
          // to these paths, so every module must be merged here — otherwise
          // buttons like Compose or Send Payment dead-end on "no routes for
          // location". Declared BEFORE /services/:serviceId so module-owned
          // literal /services/* trees win over the generic parametric route.
          for (final RouteModule module in [
            AuditRouteModule(),
            BillingRouteModule(),
            DeviceRouteModule(),
            FilesRouteModule(),
            FortRouteModule(),
            GeolocationRouteModule(),
            LedgerRouteModule(),
            NotificationRouteModule(),
            PaymentRouteModule(),
            ProfileRouteModule(),
            SettingsRouteModule(),
            TenancyRouteModule(),
            TrustageRouteModule(),
          ])
            ...module.buildRoutes(),
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
                          .buildFeaturePage(context, serviceId, featureId),
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
                          builder: (context) =>
                              ServiceRegistry.instance.buildEntityDetailPage(
                                context,
                                serviceId,
                                featureId,
                                entityId,
                              ),
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
