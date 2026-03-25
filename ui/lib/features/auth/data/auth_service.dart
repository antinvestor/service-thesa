import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openid_client/openid_client.dart';

import 'platform/auth_platform.dart';
import 'platform/auth_platform_stub.dart'
    if (dart.library.io) 'platform/auth_platform_io.dart'
    if (dart.library.html) 'platform/auth_platform_web.dart';

/// Result of a token refresh attempt.
enum TokenRefreshResult { success, transientError, permanentError }

/// OAuth2/OIDC authentication service for the admin console.
///
/// Handles:
/// - OAuth2 login with PKCE (desktop loopback / web redirect)
/// - Secure token storage via flutter_secure_storage
/// - Token refresh with concurrent-safe mutex
/// - Error classification (transient vs permanent)
class AuthService {
  AuthService(
    this._storage, {
    required String issuerUrl,
    required String clientId,
  })  : _issuerUrl = issuerUrl,
        _clientId = clientId;

  final FlutterSecureStorage _storage;
  final String _issuerUrl;
  final String _clientId;
  final AuthPlatform _platform = getAuthPlatform();

  static const _defaultTokenLifetime = Duration(hours: 1);

  Future<void> _ensureInitialized() async {
    await _platform.initialize(_issuerUrl, _clientId);
  }

  // ── Login ──────────────────────────────────────────────────────────────

  Future<TokenResponse?> authenticate() async {
    await _ensureInitialized();

    final token = await _platform.authenticate(
      ['openid', 'profile', 'offline_access'],
      audiences: const [
        'service_tenancy',
        'service_device',
        'service_profile',
        'service_notification',
        'service_payment',
        'service_thesa',
        'service_file',
      ],
    );

    if (token != null) {
      if (token.accessToken == null || token.accessToken!.isEmpty) {
        throw Exception('No access token received');
      }
      await _saveTokens(token);
      final saved = await getAccessToken();
      if (saved == null) throw Exception('Could not save credentials');
    }
    return token;
  }

  Future<void> cancelAuthentication() async {
    try {
      await _platform.cancelAuthentication();
    } catch (_) {}
  }

  // ── Token Storage ──────────────────────────────────────────────────────

  Future<void> _saveTokens(TokenResponse token) async {
    await _storage.write(key: 'access_token', value: token.accessToken);
    await _storage.write(key: 'refresh_token', value: token.refreshToken);
    try {
      await _storage.write(
        key: 'id_token',
        value: token.idToken.toCompactSerialization(),
      );
    } catch (_) {}

    final expiresAt =
        token.expiresAt ?? DateTime.now().add(_defaultTokenLifetime);
    await _storage.write(
      key: 'token_expires_at',
      value: expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');
  Future<String?> getIdToken() => _storage.read(key: 'id_token');

  // ── Token Expiry ───────────────────────────────────────────────────────

  Future<bool> isTokenExpired({
    Duration buffer = const Duration(minutes: 2),
  }) async {
    final expiresAtStr = await _storage.read(key: 'token_expires_at');
    if (expiresAtStr == null) return true;
    try {
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr));
      return DateTime.now().isAfter(expiresAt.subtract(buffer));
    } catch (_) {
      return true;
    }
  }

  Future<Duration?> getTimeUntilRefreshNeeded() async {
    final expiresAtStr = await _storage.read(key: 'token_expires_at');
    if (expiresAtStr == null) return null;
    try {
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr));
      const refreshBuffer = Duration(minutes: 5);
      final refreshAt = expiresAt.subtract(refreshBuffer);
      if (DateTime.now().isAfter(refreshAt)) return Duration.zero;
      return refreshAt.difference(DateTime.now());
    } catch (_) {
      return Duration.zero;
    }
  }

  // ── Token Refresh ──────────────────────────────────────────────────────

  Completer<({TokenRefreshResult result, TokenResponse? token, String? error})>?
      _refreshCompleter;

  /// Refresh the access token. Concurrent-safe via mutex.
  Future<({TokenRefreshResult result, TokenResponse? token, String? error})>
      refreshTokenWithResult() async {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<
        ({TokenRefreshResult result, TokenResponse? token, String? error})>();

    try {
      final refreshTokenValue = await getRefreshToken();
      if (refreshTokenValue == null) {
        const r = (
          result: TokenRefreshResult.permanentError,
          token: null as TokenResponse?,
          error: 'No refresh token',
        );
        _refreshCompleter!.complete(r);
        return r;
      }

      try {
        await _ensureInitialized();
      } catch (e) {
        final r = (
          result: TokenRefreshResult.transientError,
          token: null as TokenResponse?,
          error: 'OIDC initialization failed: $e',
        );
        _refreshCompleter!.complete(r);
        return r;
      }

      if (_platform.client == null) {
        const r = (
          result: TokenRefreshResult.transientError,
          token: null as TokenResponse?,
          error: 'Auth client not initialized',
        );
        _refreshCompleter!.complete(r);
        return r;
      }

      final credential = _platform.client!.createCredential(
        accessToken: await getAccessToken(),
        refreshToken: refreshTokenValue,
      );

      final newCred = await credential
          .getTokenResponse(true)
          .timeout(const Duration(seconds: 30));

      if (newCred.accessToken == null || newCred.accessToken!.isEmpty) {
        const r = (
          result: TokenRefreshResult.permanentError,
          token: null as TokenResponse?,
          error: 'Refresh returned empty access token',
        );
        _refreshCompleter!.complete(r);
        return r;
      }

      await _saveTokens(newCred);

      final r = (
        result: TokenRefreshResult.success,
        token: newCred as TokenResponse?,
        error: null as String?,
      );
      _refreshCompleter!.complete(r);
      return r;
    } on TimeoutException {
      const r = (
        result: TokenRefreshResult.transientError,
        token: null as TokenResponse?,
        error: 'Refresh timed out',
      );
      _refreshCompleter!.complete(r);
      return r;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isPermanent = _isPermanentRefreshError(errorStr);
      final r = (
        result:
            isPermanent ? TokenRefreshResult.permanentError : TokenRefreshResult.transientError,
        token: null as TokenResponse?,
        error: e.toString(),
      );
      _refreshCompleter!.complete(r);
      return r;
    } finally {
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.completeError(
          StateError('Token refresh exited without completing'),
        );
      }
      _refreshCompleter = null;
    }
  }

  /// Ensure we have a valid access token, refreshing if necessary.
  Future<({String? token, bool needsRelogin})>
      ensureValidAccessTokenWithStatus({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final accessToken = await getAccessToken();
    if (accessToken != null) {
      final expired = await isTokenExpired();
      if (!expired) return (token: accessToken, needsRelogin: false);
    }

    final refreshTokenValue = await getRefreshToken();
    if (refreshTokenValue == null) {
      return (token: null, needsRelogin: true);
    }

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await refreshTokenWithResult();
      switch (result.result) {
        case TokenRefreshResult.success:
          return (
            token: result.token?.accessToken ?? await getAccessToken(),
            needsRelogin: false,
          );
        case TokenRefreshResult.permanentError:
          await logout();
          return (token: null, needsRelogin: true);
        case TokenRefreshResult.transientError:
          if (attempt < maxRetries) {
            await Future.delayed(retryDelay * attempt);
          } else {
            return (token: null, needsRelogin: false);
          }
      }
    }
    return (token: null, needsRelogin: false);
  }

  // ── User Info ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserInfo() async {
    final idToken = await getIdToken();
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = base64.normalize(parts[1]);
      final decoded = utf8.decode(base64.decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to decode ID token: $e');
      return null;
    }
  }

  // ── Auth Status ────────────────────────────────────────────────────────

  Future<bool> isAuthenticated() async {
    await _handleRedirectResult();
    final accessToken = await getAccessToken();
    if (accessToken != null) return true;
    final refreshTokenValue = await getRefreshToken();
    return refreshTokenValue != null;
  }

  Future<bool> hasValidAccessToken() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return false;
    return !(await isTokenExpired());
  }

  // ── Logout ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'id_token');
    await _storage.delete(key: 'token_expires_at');
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<bool> _handleRedirectResult() async {
    try {
      await _ensureInitialized();
      final token = await _platform.getRedirectResult();
      if (token != null) {
        await _saveTokens(token);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _isPermanentRefreshError(String errorStr) {
    const transientPatterns = [
      'timeout', 'timed out', 'connection refused', 'connection reset',
      'connection closed', 'no route to host', 'network is unreachable',
      'host not found', 'dns', 'socket', 'eof', 'broken pipe',
      'ssl', 'tls', 'certificate', 'handshake',
      '500', '502', '503', '504', '429',
      'too many requests', 'rate limit', 'temporarily unavailable',
      'service unavailable', 'try again', 'retry',
    ];
    for (final p in transientPatterns) {
      if (errorStr.contains(p)) return false;
    }

    const permanentErrors = [
      'invalid_grant', 'invalid_client', 'unauthorized_client',
      'access_denied',
    ];
    for (final e in permanentErrors) {
      if (errorStr.contains(e)) return true;
    }

    const permanentMessages = [
      'refresh token has been revoked',
      'refresh token was revoked',
      'the refresh token is no longer valid',
    ];
    for (final m in permanentMessages) {
      if (errorStr.contains(m)) return true;
    }

    return false; // Default to transient — never logout on ambiguous errors
  }
}
