import 'dart:async';

import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart'
    as runtime;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication state exposed to the thesa admin console.
///
/// Mirrors the legacy tri-state enum so existing consumers (router,
/// login page, splash, drawer) continue to compile unchanged. The
/// underlying source of truth is [runtime.AuthRuntime.authStateStream]
/// — the runtime owns all OAuth + refresh logic.
enum AuthState { authenticated, unauthenticated, loading }

AuthState _map(runtime.AuthState s) {
  switch (s) {
    case runtime.AuthState.authenticated:
      return AuthState.authenticated;
    case runtime.AuthState.unauthenticated:
      return AuthState.unauthenticated;
    case runtime.AuthState.initializing:
    case runtime.AuthState.refreshing:
      return AuthState.loading;
    case runtime.AuthState.error:
      return AuthState.unauthenticated;
  }
}

/// Thesa-level auth state notifier. Delegates to the runtime but keeps
/// the `login()` / `logout()` surface expected by existing UI call
/// sites (login page, router redirect).
class AuthStateNotifier extends AsyncNotifier<AuthState> {
  StreamSubscription<runtime.AuthState>? _sub;

  @override
  Future<AuthState> build() async {
    final rt = ref.watch(runtime.authRuntimeProvider);

    _sub?.cancel();
    _sub = rt.authStateStream.listen((rs) {
      if (!ref.mounted) return;
      state = AsyncValue.data(_map(rs));
    });
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    return _map(rt.state);
  }

  /// Trigger login via the runtime.
  Future<void> login() async {
    state = const AsyncValue.loading();
    try {
      final rt = ref.read(runtime.authRuntimeProvider);
      await rt.ensureAuthenticated();
      if (!ref.mounted) return;
      state = AsyncValue.data(_map(rt.state));
    } catch (e, stack) {
      debugPrint('[Auth] Login failed: $e');
      if (ref.mounted) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  /// Trigger logout via the runtime.
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final rt = ref.read(runtime.authRuntimeProvider);
      await rt.logout();
      if (!ref.mounted) return;
      state = const AsyncValue.data(AuthState.unauthenticated);
    } catch (e, stack) {
      debugPrint('[Auth] Logout failed: $e');
      if (ref.mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
