import 'dart:convert';

import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../../core/services/connect_client.dart';
import '../../../core/services/tenant_context.dart';

/// Repository wrapping [TenancyServiceClient] with error handling
/// and stream-to-list conversion for all partition service entities.
///
/// Also provides permission management methods. These currently use REST
/// because the generated Dart client (antinvestor_api_tenancy) does not yet
/// include ListServiceNamespaces / GrantPermission / RevokePermission RPCs.
/// Once the BSR-generated code is updated, replace the REST calls with:
///   _client.listServiceNamespaces(...)
///   _client.grantPermission(...)
///   _client.revokePermission(...)
class PartitionRepository {
  PartitionRepository({
    required TenancyServiceClient client,
    required String baseUrl,
    required String accessToken,
    required TenantContext effectiveContext,
    required TenantContext jwtContext,
  })  : _client = client,
        _baseUrl = baseUrl,
        _accessToken = accessToken,
        _effectiveContext = effectiveContext,
        _jwtContext = jwtContext;

  final TenancyServiceClient _client;

  // HTTP credentials for REST-based permission endpoints (temporary).
  final String _baseUrl;
  final String _accessToken;
  final TenantContext _effectiveContext;
  final TenantContext _jwtContext;

  /// Collect items from a streaming list RPC where each chunk has a repeated field.
  Future<List<T>> _collectStream<T>(
    Stream<dynamic> stream,
    List<T> Function(dynamic response) getData,
  ) async {
    final items = <T>[];
    await for (final response in stream) {
      items.addAll(getData(response));
    }
    return items;
  }

  // ── Tenants ──────────────────────────────────────────────────────────────

  Future<List<TenantObject>> listTenants({
    String query = '',
  }) =>
      _collectStream(
        _client.listTenant(ListTenantRequest(
          query: query,
        )),
        (r) => (r as ListTenantResponse).data,
      );

  Future<TenantObject> getTenant(String id) async =>
      (await _client.getTenant(GetTenantRequest(id: id))).data;

  Future<TenantObject> createTenant({
    required String name,
    String description = '',
    TenantEnvironment? environment,
    Struct? properties,
  }) async =>
      (await _client.createTenant(CreateTenantRequest(
        name: name,
        description: description,
        environment: environment,
        properties: properties,
      )))
          .data;

  Future<TenantObject> updateTenant({
    required String id,
    String? name,
    String? description,
    STATE? state,
    TenantEnvironment? environment,
    Struct? properties,
  }) async =>
      (await _client.updateTenant(UpdateTenantRequest(
        id: id,
        name: name,
        description: description,
        state: state,
        environment: environment,
        properties: properties,
      )))
          .data;

  // ── Partitions ───────────────────────────────────────────────────────────

  Future<List<PartitionObject>> listPartitions({
    String query = '',
  }) =>
      _collectStream(
        _client.listPartition(ListPartitionRequest(
          query: query,
        )),
        (r) => (r as ListPartitionResponse).data,
      );

  Future<PartitionObject> getPartition(String id) async =>
      (await _client.getPartition(GetPartitionRequest(id: id))).data;

  Future<GetPartitionParentsResponse> getPartitionParents(
          String id) async =>
      _client.getPartitionParents(GetPartitionParentsRequest(id: id));

  Future<PartitionObject> createPartition({
    required String tenantId,
    required String name,
    String? parentId,
    String description = '',
    String? domain,
    Struct? properties,
  }) async =>
      (await _client.createPartition(CreatePartitionRequest(
        tenantId: tenantId,
        name: name,
        parentId: parentId,
        description: description,
        domain: domain,
        properties: properties,
      )))
          .data;

  Future<PartitionObject> updatePartition({
    required String id,
    String? name,
    String? description,
    String? domain,
    STATE? state,
    Struct? properties,
  }) async =>
      (await _client.updatePartition(UpdatePartitionRequest(
        id: id,
        name: name,
        description: description,
        domain: domain,
        state: state,
        properties: properties,
      )))
          .data;

  // ── Partition Roles ──────────────────────────────────────────────────────

  Future<List<PartitionRoleObject>> listPartitionRoles({
    String? partitionId,
  }) =>
      _collectStream(
        _client.listPartitionRole(ListPartitionRoleRequest(
          partitionId: partitionId,
        )),
        (r) => (r as ListPartitionRoleResponse).data,
      );

  Future<PartitionRoleObject> createPartitionRole({
    required String partitionId,
    required String name,
    Struct? properties,
  }) async =>
      (await _client.createPartitionRole(CreatePartitionRoleRequest(
        partitionId: partitionId,
        name: name,
        properties: properties,
      )))
          .data;

  Future<void> removePartitionRole(String id) async =>
      _client.removePartitionRole(RemovePartitionRoleRequest(id: id));

  // ── Pages ────────────────────────────────────────────────────────────────

  Future<List<PageObject>> listPages({
    String? partitionId,
  }) =>
      _collectStream(
        _client.listPage(ListPageRequest(
          partitionId: partitionId,
        )),
        (r) => (r as ListPageResponse).data,
      );

  Future<PageObject> getPage(String pageId) async =>
      (await _client.getPage(GetPageRequest(pageId: pageId))).data;

  Future<PageObject> createPage({
    required String partitionId,
    required String name,
    String html = '',
  }) async =>
      (await _client.createPage(CreatePageRequest(
        partitionId: partitionId,
        name: name,
        html: html,
      )))
          .data;

  Future<void> removePage(String id) async =>
      _client.removePage(RemovePageRequest(id: id));

  // ── Access ───────────────────────────────────────────────────────────────

  Future<List<AccessObject>> listAccess({
    String? partitionId,
    String? profileId,
  }) =>
      _collectStream(
        _client.listAccess(ListAccessRequest(
          partitionId: partitionId,
          profileId: profileId,
        )),
        (r) => (r as ListAccessResponse).data,
      );

  Future<AccessObject> getAccess({
    required String accessId,
    String? profileId,
  }) async =>
      (await _client.getAccess(GetAccessRequest(
        accessId: accessId,
        profileId: profileId,
      )))
          .data;

  Future<AccessObject> createAccess({
    required String partitionId,
    required String profileId,
  }) async =>
      (await _client.createAccess(CreateAccessRequest(
        partitionId: partitionId,
        profileId: profileId,
      )))
          .data;

  Future<void> removeAccess(String id) async =>
      _client.removeAccess(RemoveAccessRequest(id: id));

  // ── Access Roles ─────────────────────────────────────────────────────────

  Future<List<AccessRoleObject>> listAccessRoles({
    String? accessId,
  }) =>
      _collectStream(
        _client.listAccessRole(ListAccessRoleRequest(
          accessId: accessId,
        )),
        (r) => (r as ListAccessRoleResponse).data,
      );

  Future<AccessRoleObject> createAccessRole({
    required String accessId,
    required String partitionRoleId,
  }) async =>
      (await _client.createAccessRole(CreateAccessRoleRequest(
        accessId: accessId,
        partitionRoleId: partitionRoleId,
      )))
          .data;

  Future<void> removeAccessRole(String id) async =>
      _client.removeAccessRole(RemoveAccessRoleRequest(id: id));

  // ── Service Accounts ────────────────────────────────────────────────────

  Future<List<ServiceAccountObject>> listServiceAccounts({
    String? partitionId,
  }) =>
      _collectStream(
        _client.listServiceAccount(ListServiceAccountRequest(
          partitionId: partitionId,
        )),
        (r) => (r as ListServiceAccountResponse).data,
      );

  Future<ServiceAccountObject> createServiceAccount({
    required String partitionId,
    required String name,
    String type = 'internal',
    List<String>? audiences,
    List<String>? roles,
  }) async =>
      (await _client.createServiceAccount(CreateServiceAccountRequest(
        partitionId: partitionId,
        name: name,
        type: type,
        audiences: audiences,
        roles: roles,
      )))
          .data;

  Future<void> removeServiceAccount(String id) async =>
      _client.removeServiceAccount(RemoveServiceAccountRequest(id: id));

  // ── Clients ─────────────────────────────────────────────────────────────

  Future<List<ClientObject>> listClients({
    String? partitionId,
    String? serviceAccountId,
  }) =>
      _collectStream(
        _client.listClient(ListClientRequest(
          partitionId: partitionId,
          serviceAccountId: serviceAccountId,
        )),
        (r) => (r as ListClientResponse).data,
      );

  Future<ClientObject> createClient({
    required String name,
    String? partitionId,
    String? serviceAccountId,
    String type = 'public',
    String scopes = 'openid',
    List<String>? grantTypes,
    List<String>? responseTypes,
    List<String>? redirectUris,
    List<String>? audiences,
    List<String>? roles,
  }) async =>
      (await _client.createClient(CreateClientRequest(
        name: name,
        partitionId: partitionId,
        serviceAccountId: serviceAccountId,
        type: type,
        scopes: scopes,
        grantTypes: grantTypes,
        responseTypes: responseTypes,
        redirectUris: redirectUris,
        audiences: audiences,
        roles: roles,
      )))
          .data;

  Future<void> removeClient(String id) async =>
      _client.removeClient(RemoveClientRequest(id: id));

  // ── Permissions (REST until proto codegen catches up) ───────────────────

  /// HTTP headers for REST-based permission endpoints.
  /// Includes tenant override headers for cross-tenant administration.
  Map<String, String> get _permissionHeaders {
    final headers = <String, String>{
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
    if (_effectiveContext.tenantId.isNotEmpty &&
        _effectiveContext.partitionId.isNotEmpty &&
        (_effectiveContext.tenantId != _jwtContext.tenantId ||
            _effectiveContext.partitionId != _jwtContext.partitionId)) {
      headers['X-Tenant-Id'] = _effectiveContext.tenantId;
      headers['X-Partition-Id'] = _effectiveContext.partitionId;
      if (_effectiveContext.accessId.isNotEmpty) {
        headers['X-Access-Id'] = _effectiveContext.accessId;
      }
    }
    return headers;
  }

  /// List registered service namespaces and their permissions.
  ///
  /// TODO: Replace with `_client.listServiceNamespaces(ListServiceNamespacesRequest())`
  /// once the generated Dart client includes the RPC.
  Future<List<ServiceNamespace>> listServiceNamespaces() async {
    final uri = Uri.parse('$_baseUrl/api/permissions/');
    final response = await http.get(uri, headers: _permissionHeaders);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load permissions (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceNamespace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Grant a permission to a profile within a namespace.
  ///
  /// TODO: Replace with `_client.grantPermission(GrantPermissionRequest(...))`
  /// once the generated Dart client includes the RPC.
  Future<void> grantPermission({
    required String namespace,
    required String permission,
    required String profileId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/permissions/grant');
    final response = await http.post(
      uri,
      headers: _permissionHeaders,
      body: jsonEncode({
        'namespace': namespace,
        'permission': permission,
        'profile_id': profileId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to grant permission (${response.statusCode}): ${response.body}');
    }
  }

  /// Revoke a permission from a profile within a namespace.
  ///
  /// TODO: Replace with `_client.revokePermission(RevokePermissionRequest(...))`
  /// once the generated Dart client includes the RPC.
  Future<void> revokePermission({
    required String namespace,
    required String permission,
    required String profileId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/permissions/revoke');
    final response = await http.post(
      uri,
      headers: _permissionHeaders,
      body: jsonEncode({
        'namespace': namespace,
        'permission': permission,
        'profile_id': profileId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to revoke permission (${response.statusCode}): ${response.body}');
    }
  }
}

// ─── Permissions Model ──────────────────────────────────────────────────────

/// A registered service namespace with its available permissions and role bindings.
///
/// TODO: Replace with the proto-generated `ServiceNamespaceObject` once
/// the generated Dart client includes ListServiceNamespaces.
class ServiceNamespace {
  const ServiceNamespace({
    required this.namespace,
    required this.permissions,
    required this.roleBindings,
    required this.registeredAt,
  });

  final String namespace;
  final List<String> permissions;
  final Map<String, List<String>> roleBindings;
  final String registeredAt;

  factory ServiceNamespace.fromJson(Map<String, dynamic> json) {
    final roleBindingsRaw = json['role_bindings'] as Map<String, dynamic>? ?? {};
    final roleBindings = roleBindingsRaw.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((e) => e.toString()).toList(),
      ),
    );
    return ServiceNamespace(
      namespace: json['namespace'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      roleBindings: roleBindings,
      registeredAt: json['registered_at'] as String? ?? '',
    );
  }
}

// ─── Riverpod Providers ─────────────────────────────────────────────────────

final partitionRepositoryProvider =
    FutureProvider<PartitionRepository>((ref) async {
  final client = await ref.watch(tenancyServiceClientProvider.future);

  final tokenManager = ref.watch(tokenManagerProvider);
  await tokenManager.initialize();
  final accessToken = tokenManager.accessToken ?? '';

  final jwtCtx = ref.watch(jwtTenantContextProvider);
  final jwt = jwtCtx.whenOrNull(data: (ctx) => ctx) ??
      const TenantContext(tenantId: '', partitionId: '');
  final effective = ref.watch(effectiveTenantProvider);

  return PartitionRepository(
    client: client,
    baseUrl: ApiConfig.tenancyBaseUrl,
    accessToken: accessToken,
    effectiveContext: effective,
    jwtContext: jwt,
  );
});
