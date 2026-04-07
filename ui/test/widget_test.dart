import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thesa/features/auth/data/auth_repository.dart';
import 'package:thesa/features/auth/data/auth_service.dart';
import 'package:thesa/features/auth/data/auth_state_provider.dart';

class _StubAuthService extends AuthService {
  _StubAuthService()
      : super(
          const FlutterSecureStorage(),
          issuerUrl: 'https://example.com',
          clientId: 'test-client',
        );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required this.initiallyLoggedIn,
    required this.loginCompletesLocally,
  }) : super(_StubAuthService(), const FlutterSecureStorage());

  final bool initiallyLoggedIn;
  final bool loginCompletesLocally;

  bool _loggedIn = false;
  bool _loggedOut = false;

  @override
  Future<bool> isLoggedIn() async {
    return _loggedOut ? false : (_loggedIn || initiallyLoggedIn);
  }

  @override
  Future<bool> login() async {
    _loggedIn = loginCompletesLocally;
    return loginCompletesLocally;
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
    _loggedOut = true;
  }

  @override
  Future<({String? token, bool needsRelogin})> ensureValidAccessTokenWithStatus({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    if (_loggedOut) return (token: null, needsRelogin: true);
    if (_loggedIn || initiallyLoggedIn) {
      return (token: 'token', needsRelogin: false);
    }
    return (token: null, needsRelogin: true);
  }

  @override
  Future<Duration?> getTimeUntilRefreshNeeded() async {
    return const Duration(hours: 1);
  }
}

void main() {
  ProviderContainer makeContainer(_FakeAuthRepository authRepository) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('initial auth state is unauthenticated when there is no session', () async {
    final container = makeContainer(
      _FakeAuthRepository(
        initiallyLoggedIn: false,
        loginCompletesLocally: false,
      ),
    );

    final state = await container.read(authStateProvider.future);

    expect(state, AuthState.unauthenticated);
  });

  test('web login redirect does not mark the user authenticated early', () async {
    final container = makeContainer(
      _FakeAuthRepository(
        initiallyLoggedIn: false,
        loginCompletesLocally: false,
      ),
    );

    await container.read(authStateProvider.future);
    await container.read(authStateProvider.notifier).login();

    expect(
      container.read(authStateProvider).requireValue,
      AuthState.unauthenticated,
    );
  });

  test('completed login marks the user authenticated', () async {
    final container = makeContainer(
      _FakeAuthRepository(
        initiallyLoggedIn: false,
        loginCompletesLocally: true,
      ),
    );

    await container.read(authStateProvider.future);
    await container.read(authStateProvider.notifier).login();

    expect(
      container.read(authStateProvider).requireValue,
      AuthState.authenticated,
    );
  });

  test('existing valid session resolves as authenticated', () async {
    final container = makeContainer(
      _FakeAuthRepository(
        initiallyLoggedIn: true,
        loginCompletesLocally: false,
      ),
    );

    final state = await container.read(authStateProvider.future);

    expect(state, AuthState.authenticated);
  });
}
