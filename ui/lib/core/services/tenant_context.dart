import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the active tenant/partition context for the admin console.
class TenantContext {
  const TenantContext({
    required this.tenantId,
    required this.partitionId,
    this.accessId = '',
    this.roles = const [],
    this.profileId = '',
  });

  final String tenantId;
  final String partitionId;
  final String accessId;
  final List<String> roles;
  final String profileId;

  /// Whether this is the root context (no specific tenant selected).
  bool get isRoot => tenantId.isEmpty;

  /// Whether the user has the owner role.
  bool get isOwner => roles.contains('owner');

  /// Whether the user has admin or owner role.
  bool get isAdmin => roles.contains('admin') || isOwner;

  /// Whether the user has the "internal" role (root-tenant owner/admin).
  /// Internal users can switch tenant context for cross-tenant administration.
  bool get isInternal => roles.contains('internal');

  /// Whether the user can switch partition context.
  /// Internal users can switch across tenants; owners can switch across
  /// partitions within their tenant.
  bool get canSwitchContext => isInternal || isOwner;

  TenantContext copyWith({String? tenantId, String? partitionId}) =>
      TenantContext(
        tenantId: tenantId ?? this.tenantId,
        partitionId: partitionId ?? this.partitionId,
        accessId: accessId,
        roles: roles,
        profileId: profileId,
      );
}

/// Extracts tenant context from the runtime's decoded token claims.
///
/// The runtime owns the access/ID tokens; it surfaces the decoded claims
/// via `getClaims()` / `getUserClaims()` without letting the raw token
/// cross back into application code.
final jwtTenantContextProvider = FutureProvider<TenantContext>((ref) async {
  final runtime = ref.watch(authRuntimeProvider);
  if (!runtime.isAuthenticated) {
    return const TenantContext(tenantId: '', partitionId: '');
  }

  try {
    final claims = await runtime.getClaims();
    final tenantId = claims['tenant_id'] as String? ?? '';
    final partitionId = claims['partition_id'] as String? ?? '';
    final accessId = claims['access_id'] as String? ?? '';
    final profileId = claims['sub'] as String? ?? '';
    final rolesRaw = claims['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      roles.addAll(rolesRaw.map((e) => e.toString()));
    } else {
      // Fall back to realm_access.roles (Hydra / Keycloak shape).
      final realm = claims['realm_access'];
      if (realm is Map) {
        final realmRoles = realm['roles'];
        if (realmRoles is List) {
          roles.addAll(realmRoles.map((e) => e.toString()));
        }
      }
    }

    return TenantContext(
      tenantId: tenantId,
      partitionId: partitionId,
      accessId: accessId,
      roles: roles,
      profileId: profileId,
    );
  } catch (_) {
    return const TenantContext(tenantId: '', partitionId: '');
  }
});

/// Notifier for the active working tenant/partition context.
///
/// Defaults to the JWT context but can be overridden by the user
/// to work within a different tenant/partition scope.
class ActiveTenantNotifier extends Notifier<TenantContext?> {
  @override
  TenantContext? build() => null;

  void set(TenantContext? context) => state = context;

  void clear() => state = null;
}

final activeTenantProvider =
    NotifierProvider<ActiveTenantNotifier, TenantContext?>(
      ActiveTenantNotifier.new,
    );

/// The effective tenant context - either the user's override or the JWT default.
final effectiveTenantProvider = Provider<TenantContext>((ref) {
  final override = ref.watch(activeTenantProvider);
  if (override != null) return override;

  final jwt = ref.watch(jwtTenantContextProvider);
  return jwt.whenOrNull(data: (ctx) => ctx) ??
      const TenantContext(tenantId: '', partitionId: '');
});
