import 'package:connectrpc/connect.dart' as connect;

import 'tenant_context.dart';

/// Connect RPC interceptor that injects tenant override headers for
/// cross-tenant administration.
///
/// When the effective tenant (selected via the tenant picker) differs from
/// the JWT default, this interceptor adds X-Tenant-Id and X-Partition-Id
/// headers. Frame's [EnrichTenancyClaims] on the server side picks these
/// up for users with the "internal" role, enabling cross-tenant operations.
connect.Interceptor tenantContextInterceptor({
  required TenantContext Function() getEffectiveContext,
  required TenantContext Function() getJwtContext,
}) {
  return <I extends Object, O extends Object>(
    connect.AnyFn<I, O> next,
  ) {
    return (connect.Request<I, O> req) {
      final jwt = getJwtContext();
      final effective = getEffectiveContext();

      // Only inject override headers when the effective tenant differs from JWT.
      if (effective.tenantId.isNotEmpty &&
          effective.partitionId.isNotEmpty &&
          (effective.tenantId != jwt.tenantId ||
              effective.partitionId != jwt.partitionId)) {
        req.headers['X-Tenant-Id'] = effective.tenantId;
        req.headers['X-Partition-Id'] = effective.partitionId;
        if (effective.accessId.isNotEmpty) {
          req.headers['X-Access-Id'] = effective.accessId;
        }
      }

      return next(req);
    };
  };
}
