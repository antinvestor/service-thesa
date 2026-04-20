import 'package:antinvestor_api_audit/antinvestor_api_audit.dart';
import 'package:antinvestor_api_billing/antinvestor_api_billing.dart';
import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:connectrpc/connect.dart' as connect;
import 'package:antinvestor_api_device/antinvestor_api_device.dart';
import 'package:antinvestor_api_files/antinvestor_api_files.dart';
import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:antinvestor_api_notification/antinvestor_api_notification.dart'
    hide SearchRequest, SearchResponse;
import 'package:antinvestor_api_payment/antinvestor_api_payment.dart'
    hide SearchRequest, SearchResponse, STATE, STATUS,
         LedgerServiceClient, BillingServiceClient;
import 'package:antinvestor_api_profile/antinvestor_api_profile.dart'
    hide DeviceClient, newDeviceClient, Struct, STATE, STATUS;
import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../networking/runtime_transport.dart';
import 'api_config.dart';
import 'tenant_context.dart';
import 'tenant_interceptor.dart';

// ─── Token Manager (legacy no-op stub) ────────────────────────────────────────
//
// antinvestor_api_common's `newClient` family requires a [TokenManager] +
// [TokenRefreshCallback] pair so its auth interceptors install. Since the
// auth runtime now owns token lifetime, persistence, and refresh end-to-end
// (and [RuntimeTransport] overrides the `Authorization` header before the
// SDK's interceptor sees the request), the manager's hooks are no-ops.
//
// A future dispatch will retire these stubs entirely once the SDK grows a
// "no token manager needed" constructor path.

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenManagerProvider = Provider<TokenManager>((ref) {
  final tokenManager = TokenManager(
    persistTokens: (accessToken, refreshToken) async {
      // No-op: runtime owns token persistence via its own secure storage.
    },
    loadTokens: () async => null,
    onRefreshToken: (String? refreshToken) async {
      // Runtime owns refresh; this path is never reached because
      // RuntimeTransport rewrites Authorization before the SDK's auth
      // interceptor runs.
      throw Exception(
        'TokenManager refresh path retired; AuthRuntime owns refresh',
      );
    },
    onLogout: () async {
      // Delegated to whichever surface triggered logout; the runtime
      // wipes its own credentials on `rt.logout()`.
    },
  );
  ref.onDispose(() => tokenManager.dispose());
  return tokenManager;
});

final tokenRefreshCallbackProvider = Provider<TokenRefreshCallback>((ref) {
  return (String? refreshToken) async {
    throw Exception(
      'Legacy TokenRefreshCallback invoked; AuthRuntime owns refresh',
    );
  };
});

// ─── Tenant Context Interceptor ──────────────────────────────────────────────

/// Provides a Connect RPC interceptor that injects tenant override headers
/// when the effective tenant context differs from the JWT default.
/// This enables cross-tenant administration for "internal" role users.
final tenantInterceptorProvider =
    Provider<List<connect.Interceptor>>((ref) {
  final jwt = ref.watch(jwtTenantContextProvider);
  final jwtCtx = jwt.whenOrNull(data: (ctx) => ctx) ??
      const TenantContext(tenantId: '', partitionId: '');

  if (!jwtCtx.isInternal && !jwtCtx.isOwner) return const [];

  return [
    tenantContextInterceptor(
      getEffectiveContext: () => ref.read(effectiveTenantProvider),
      getJwtContext: () => jwtCtx,
    ),
  ];
});

// ─── Partition Client ────────────────────────────────────────────────────────

/// Tenancy API client provider — routes RPCs through `AuthRuntime.fetch`
/// via [RuntimeTransport].
final tenancyClientProvider =
    FutureProvider<TenancyClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);

  await tokenManager.initialize();

  return newTenancyClient(
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.tenancyBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final tenancyServiceClientProvider =
    FutureProvider<TenancyServiceClient>((ref) async {
  final client = await ref.watch(tenancyClientProvider.future);
  return client.stub;
});

// ─── Profile Client ──────────────────────────────────────────────────────────

final profileClientProvider =
    FutureProvider<ProfileClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);

  await tokenManager.initialize();

  return newProfileClient(
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.profileBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final profileServiceClientProvider =
    FutureProvider<ProfileServiceClient>((ref) async {
  final client = await ref.watch(profileClientProvider.future);
  return client.stub;
});

// ─── Device Client ──────────────────────────────────────────────────────────

final deviceClientProvider =
    FutureProvider<DeviceClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);

  await tokenManager.initialize();

  return newDeviceClient(
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.deviceBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final deviceServiceClientProvider =
    FutureProvider<DeviceServiceClient>((ref) async {
  final client = await ref.watch(deviceClientProvider.future);
  return client.stub;
});

// ─── Notification Client ────────────────────────────────────────────────────

final notificationClientProvider =
    FutureProvider<ConnectClientBase<NotificationServiceClient>>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();
  return newClient<NotificationServiceClient>(
    defaultEndpoint: 'https://notification.antinvestor.com',
    createServiceClient: NotificationServiceClient.new,
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.notificationBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final notificationServiceClientProvider =
    FutureProvider<NotificationServiceClient>((ref) async {
  final client = await ref.watch(notificationClientProvider.future);
  return client.stub;
});

// ─── Payment Client ─────────────────────────────────────────────────────────

final paymentClientProvider =
    FutureProvider<ConnectClientBase<PaymentServiceClient>>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();
  return newClient<PaymentServiceClient>(
    defaultEndpoint: 'https://payment.antinvestor.com',
    createServiceClient: PaymentServiceClient.new,
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.paymentBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final paymentServiceClientProvider =
    FutureProvider<PaymentServiceClient>((ref) async {
  final client = await ref.watch(paymentClientProvider.future);
  return client.stub;
});

// ─── Ledger Client ──────────────────────────────────────────────────────────

final ledgerClientProvider =
    FutureProvider<LedgerClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();
  return newLedgerClient(
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.ledgerBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final ledgerServiceClientProvider =
    FutureProvider<LedgerServiceClient>((ref) async {
  final client = await ref.watch(ledgerClientProvider.future);
  return client.stub;
});

// ─── Settings Client ────────────────────────────────────────────────────────

final settingsClientProvider =
    FutureProvider<SettingsClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();
  return newSettingsClient(
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.settingsBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
});

final settingsServiceClientProvider =
    FutureProvider<SettingsServiceClient>((ref) async {
  final client = await ref.watch(settingsClientProvider.future);
  return client.stub;
});

// ─── Billing Client ────────────────────────────────────────────────────────

final billingServiceClientProvider =
    FutureProvider<BillingServiceClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();

  final client = await newClient<BillingServiceClient>(
    defaultEndpoint: 'https://billing.antinvestor.com',
    createServiceClient: BillingServiceClient.new,
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.billingBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
  return client.stub;
});

// ─── Files Client ──────────────────────────────────────────────────────────

final filesServiceClientProvider =
    FutureProvider<FilesServiceClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();

  final client = await newClient<FilesServiceClient>(
    defaultEndpoint: 'https://files.antinvestor.com',
    createServiceClient: FilesServiceClient.new,
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.filesBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
  return client.stub;
});

// ─── Audit Client ──────────────────────────────────────────────────────────

final auditServiceClientProvider =
    FutureProvider<AuditServiceClient>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final tenantInterceptors = ref.watch(tenantInterceptorProvider);
  final runtime = ref.watch(authRuntimeProvider);
  await tokenManager.initialize();

  final client = await newClient<AuditServiceClient>(
    defaultEndpoint: 'https://audit.antinvestor.com',
    createServiceClient: AuditServiceClient.new,
    createTransport: createRuntimeTransportFactory(runtime),
    endpoint: ApiConfig.auditBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
    additionalInterceptors: tenantInterceptors,
  );
  return client.stub;
});
