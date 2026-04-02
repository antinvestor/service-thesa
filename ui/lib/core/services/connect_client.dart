import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:antinvestor_api_device/antinvestor_api_device.dart';
import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_service.dart' as auth;
import 'api_config.dart';
import 'transport/transport.dart';

// ─── Token Manager ───────────────────────────────────────────────────────────

/// Token manager using antinvestor_api_common's TokenManager.
///
/// Handles:
/// - Persistent token storage via FlutterSecureStorage
/// - Reactive refresh on 401 via auth service
/// - Automatic logout on permanent errors
final tokenManagerProvider = Provider<TokenManager>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  final tokenManager = TokenManager(
    persistTokens: (accessToken, refreshToken) async {
      // Access token managed here; refresh token managed by AuthService
      if (accessToken != null) {
        await authRepo.writeToken('access_token', accessToken);
      } else {
        await authRepo.deleteToken('access_token');
      }
      // Only clear refresh token during logout (both null)
      if (accessToken == null && refreshToken == null) {
        await authRepo.deleteToken('refresh_token');
      }
    },
    loadTokens: () async {
      final accessToken = await authRepo.readToken('access_token');
      final refreshToken = await authRepo.readToken('refresh_token');
      if (accessToken != null) {
        return TokenPair(
            accessToken: accessToken, refreshToken: refreshToken);
      }
      return null;
    },
    onRefreshToken: (String? refreshToken) async {
      debugPrint('[TokenManager] onRefreshToken called, refreshing...');
      final result = await authRepo.refreshTokenWithResult();
      if (result.result != auth.TokenRefreshResult.success) {
        throw Exception(result.error ?? 'Token refresh failed');
      }
      final token = await authRepo.getAccessToken();
      if (token == null) throw Exception('No access token after refresh');
      return token;
    },
    onLogout: () async {
      debugPrint('[TokenManager] Permanent error, logging out');
      await authRepo.logout();
    },
  );

  ref.onDispose(() => tokenManager.dispose());
  return tokenManager;
});

/// Token refresh callback for API clients.
final tokenRefreshCallbackProvider =
    Provider<TokenRefreshCallback>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return (String? refreshToken) async {
    final result = await authRepo.refreshTokenWithResult();
    if (result.result == auth.TokenRefreshResult.permanentError) {
      throw Exception(result.error ?? 'Token refresh failed permanently');
    }
    if (result.result != auth.TokenRefreshResult.success) {
      throw Exception(result.error ?? 'Token refresh failed');
    }
    final token = await authRepo.getAccessToken();
    if (token == null) throw Exception('No token after refresh');
    return token;
  };
});

// ─── Partition Client ────────────────────────────────────────────────────────

/// Partition API client provider.
///
/// Creates an authenticated TenancyClient using [newTenancyClient]
/// with TokenManager for automatic token management.
final tenancyClientProvider =
    FutureProvider<TenancyClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);

  await tokenManager.initialize();

  return newTenancyClient(
    createTransport: createTransportFactory(),
    endpoint: ApiConfig.tenancyBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
  );
});

/// Expose the raw TenancyServiceClient stub for direct RPC calls.
final tenancyServiceClientProvider =
    FutureProvider<TenancyServiceClient>((ref) async {
  final client = await ref.watch(tenancyClientProvider.future);
  return client.stub;
});

// ─── Profile Client ──────────────────────────────────────────────────────────

/// Profile API client provider.
final profileClientProvider =
    FutureProvider<ProfileClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);

  await tokenManager.initialize();

  return newProfileClient(
    createTransport: createTransportFactory(),
    endpoint: ApiConfig.profileBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
  );
});

/// Expose the raw ProfileServiceClient stub.
final profileServiceClientProvider =
    FutureProvider<ProfileServiceClient>((ref) async {
  final client = await ref.watch(profileClientProvider.future);
  return client.stub;
});

// ─── Device Client ──────────────────────────────────────────────────────────

/// Device API client provider.
final deviceClientProvider =
    FutureProvider<DeviceClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);

  await tokenManager.initialize();

  return newDeviceClient(
    createTransport: createTransportFactory(),
    endpoint: ApiConfig.deviceBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
  );
});

/// Expose the raw DeviceServiceClient stub.
final deviceServiceClientProvider =
    FutureProvider<DeviceServiceClient>((ref) async {
  final client = await ref.watch(deviceClientProvider.future);
  return client.stub;
});
