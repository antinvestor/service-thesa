import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart'
    as runtime;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesa/features/auth/data/auth_state_provider.dart';

import 'support/mock_auth_runtime.dart';

/// Exercises the thesa-level [authStateProvider] adapter, which mirrors
/// the runtime's `AuthState` stream into the tri-state enum (authenticated /
/// unauthenticated / loading) that the router + UI consume.
void main() {
  ProviderContainer containerWith(MockAuthRuntime rt) {
    final container = ProviderContainer(
      overrides: [runtime.authRuntimeProvider.overrideWithValue(rt)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'initial auth state is unauthenticated when runtime has no session',
    () async {
      final rt = MockAuthRuntime();
      final container = containerWith(rt);

      final state = await container.read(authStateProvider.future);

      expect(state, AuthState.unauthenticated);
    },
  );

  test('existing authenticated runtime surfaces as authenticated', () async {
    final rt = MockAuthRuntime.authenticated(
      claimsMap: const {'sub': 'user-1', 'tenant_id': 'tenant-42'},
    );
    final container = containerWith(rt);

    final state = await container.read(authStateProvider.future);

    expect(state, AuthState.authenticated);
  });

  test(
    'login delegates to runtime.ensureAuthenticated and flips state',
    () async {
      final rt = MockAuthRuntime();
      final container = containerWith(rt);

      await container.read(authStateProvider.future);
      expect(rt.ensureAuthenticatedCalls, 0);

      await container.read(authStateProvider.notifier).login();

      expect(rt.ensureAuthenticatedCalls, 1);
      expect(
        container.read(authStateProvider).requireValue,
        AuthState.authenticated,
      );
    },
  );

  test(
    'logout delegates to runtime.logout and flips state to unauthenticated',
    () async {
      final rt = MockAuthRuntime.authenticated();
      final container = containerWith(rt);

      await container.read(authStateProvider.future);
      expect(
        container.read(authStateProvider).requireValue,
        AuthState.authenticated,
      );

      await container.read(authStateProvider.notifier).logout();

      expect(rt.logoutCalls, 1);
      expect(
        container.read(authStateProvider).requireValue,
        AuthState.unauthenticated,
      );
    },
  );

  test('runtime refreshing state collapses to thesa-level loading', () async {
    final rt = MockAuthRuntime.authenticated();
    final container = containerWith(rt);

    await container.read(authStateProvider.future);

    // Drive the runtime into a transient refreshing state; thesa's
    // adapter must map this to `AuthState.loading`, not unauthenticated,
    // so the router doesn't bounce the user to /login mid-refresh.
    rt.setAuthState(runtime.AuthState.refreshing);
    // Allow the subscription to settle.
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authStateProvider),
      const AsyncValue<AuthState>.data(AuthState.loading),
    );
  });
}
