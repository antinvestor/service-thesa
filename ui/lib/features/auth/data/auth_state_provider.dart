import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_service.dart';

/// Authentication state.
enum AuthState { authenticated, unauthenticated, loading }

/// Notifier that manages auth state transitions.
class AuthStateNotifier extends AsyncNotifier<AuthState> {
  Timer? _refreshTimer;

  @override
  Future<AuthState> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());

    final authRepo = ref.watch(authRepositoryProvider);
    final isLoggedIn = await authRepo.isLoggedIn();

    if (isLoggedIn) {
      final result = await authRepo.ensureValidAccessTokenWithStatus();
      if (result.token != null) {
        _scheduleTokenRefresh();
        return AuthState.authenticated;
      }
      if (result.needsRelogin) return AuthState.unauthenticated;
      // Transient error — keep session alive
      _scheduleTokenRefresh();
      return AuthState.authenticated;
    }
    return AuthState.unauthenticated;
  }

  /// Trigger OAuth login flow.
  Future<void> login() async {
    state = const AsyncValue.loading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final isAuthenticated = await authRepo.login();
      if (!ref.mounted) return;
      if (isAuthenticated) {
        _scheduleTokenRefresh();
        state = const AsyncValue.data(AuthState.authenticated);
        return;
      }
      state = const AsyncValue.data(AuthState.unauthenticated);
    } catch (e, stack) {
      if (ref.mounted) state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Clear tokens and redirect to login.
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      _refreshTimer?.cancel();
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.logout();
      if (!ref.mounted) return;
      state = const AsyncValue.data(AuthState.unauthenticated);
    } catch (e, stack) {
      if (ref.mounted) state = AsyncValue.error(e, stack);
    }
  }

  /// Proactive background token refresh.
  /// Refreshes 5 minutes before expiry, retries with backoff on transient errors.
  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();

    // Check every 30 seconds whether we need to refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final authRepo = ref.read(authRepositoryProvider);
        final timeUntil = await authRepo.getTimeUntilRefreshNeeded();

        if (timeUntil != null && timeUntil <= Duration.zero) {
          debugPrint('[Auth] Token expiring soon, refreshing...');
          final result = await authRepo.refreshTokenWithResult();

          switch (result.result) {
            case TokenRefreshResult.success:
              debugPrint('[Auth] Background token refresh succeeded');
              break;
            case TokenRefreshResult.permanentError:
              debugPrint('[Auth] Permanent refresh error, logging out');
              await logout();
              break;
            case TokenRefreshResult.transientError:
              debugPrint('[Auth] Transient refresh error, will retry');
              break;
          }
        }
      } catch (e) {
        debugPrint('[Auth] Background refresh check error: $e');
      }
    });
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
