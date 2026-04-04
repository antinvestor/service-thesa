import 'package:antinvestor_api_common/antinvestor_api_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';

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

  TenantContext copyWith({
    String? tenantId,
    String? partitionId,
  }) =>
      TenantContext(
        tenantId: tenantId ?? this.tenantId,
        partitionId: partitionId ?? this.partitionId,
        accessId: accessId,
        roles: roles,
        profileId: profileId,
      );
}

/// Extracts tenant context from the JWT access token claims.
final jwtTenantContextProvider =
    FutureProvider<TenantContext>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final accessToken = await authRepo.readToken('access_token');
  if (accessToken == null) {
    return const TenantContext(tenantId: '', partitionId: '');
  }

  try {
    final claims = JwtUtils.parseJwt(accessToken);
    final tenantId = claims['tenant_id'] as String? ?? '';
    final partitionId = claims['partition_id'] as String? ?? '';
    final accessId = claims['access_id'] as String? ?? '';
    final profileId = claims['sub'] as String? ?? '';
    final rolesRaw = claims['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      roles.addAll(rolesRaw.map((e) => e.toString()));
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
