import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_config.dart';
import 'auth_service.dart';

/// High-level repository for authentication operations.
class AuthRepository {
  AuthRepository(this._authService, this._storage);
  final AuthService _authService;
  final FlutterSecureStorage _storage;

  /// Direct token storage access for TokenManager integration.
  Future<String?> readToken(String key) => _storage.read(key: key);
  Future<void> writeToken(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> deleteToken(String key) => _storage.delete(key: key);

  Future<void> login() async {
    final token = await _authService.authenticate();
    if (token == null) {
      throw Exception('Authentication did not return a token');
    }
  }

  Future<void> logout() => _authService.logout();
  Future<bool> isLoggedIn() => _authService.isAuthenticated();
  Future<bool> isTokenExpired() => _authService.isTokenExpired();
  Future<String?> getAccessToken() => _authService.getAccessToken();
  Future<bool> hasValidAccessToken() => _authService.hasValidAccessToken();
  Future<Map<String, dynamic>?> getUserInfo() => _authService.getUserInfo();
  Future<Duration?> getTimeUntilRefreshNeeded() =>
      _authService.getTimeUntilRefreshNeeded();

  Future<({TokenRefreshResult result, dynamic token, String? error})>
      refreshTokenWithResult() => _authService.refreshTokenWithResult();

  Future<({String? token, bool needsRelogin})>
      ensureValidAccessTokenWithStatus({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) =>
          _authService.ensureValidAccessTokenWithStatus(
            maxRetries: maxRetries,
            retryDelay: retryDelay,
          );
}

/// Riverpod provider for secure storage.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Riverpod provider for auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final authService = AuthService(
    storage,
    issuerUrl: ApiConfig.oauth2IssuerUrl,
    clientId: ApiConfig.oauth2ClientId,
  );
  return AuthRepository(authService, storage);
});
