import 'package:antinvestor_api_common/antinvestor_api_common.dart'
    show STATE, PageCursor, Struct;
import 'package:antinvestor_api_partition/antinvestor_api_partition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [PartitionServiceClient] with error handling
/// and stream-to-list conversion for all partition service entities.
class PartitionRepository {
  PartitionRepository(this._client);

  final PartitionServiceClient _client;

  /// Collect items from a streaming list RPC where each chunk has a repeated `data` field.
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
    int pageSize = 50,
    TenantEnvironment? environment,
  }) =>
      _collectStream(
        _client.listTenant(ListTenantRequest(
          query: query,
          cursor: PageCursor(limit: pageSize),
          environment: environment,
        )),
        (r) => (r as ListTenantResponse).data,
      );

  Future<TenantObject> getTenant(String id) async =>
      (await _client.getTenant(GetTenantRequest(id: id))).data;

  Future<TenantObject> createTenant({
    required String name,
    String description = '',
    TenantEnvironment environment =
        TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION,
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
    Struct? properties,
  }) async =>
      (await _client.updateTenant(UpdateTenantRequest(
        id: id,
        name: name,
        description: description,
        state: state,
        properties: properties,
      )))
          .data;

  Future<void> removeTenant(String id) async =>
      _client.removeTenant(RemoveTenantRequest(id: id));

  // ── Partitions ───────────────────────────────────────────────────────────

  Future<List<PartitionObject>> listPartitions({
    String query = '',
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listPartition(ListPartitionRequest(
          query: query,
          cursor: PageCursor(limit: pageSize),
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
    Struct? properties,
  }) async =>
      (await _client.createPartition(CreatePartitionRequest(
        tenantId: tenantId,
        name: name,
        parentId: parentId,
        description: description,
        properties: properties,
      )))
          .data;

  Future<PartitionObject> updatePartition({
    required String id,
    String? name,
    String? description,
    STATE? state,
    Struct? properties,
  }) async =>
      (await _client.updatePartition(UpdatePartitionRequest(
        id: id,
        name: name,
        description: description,
        state: state,
        properties: properties,
      )))
          .data;

  Future<void> removePartition(String id) async =>
      _client.removePartition(RemovePartitionRequest(id: id));

  // ── Partition Roles ──────────────────────────────────────────────────────

  Future<List<PartitionRoleObject>> listPartitionRoles({
    String? partitionId,
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listPartitionRole(ListPartitionRoleRequest(
          cursor: PageCursor(limit: pageSize),
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

  Future<PartitionRoleObject> updatePartitionRole({
    required String id,
    String? name,
    STATE? state,
    Struct? properties,
  }) async =>
      (await _client.updatePartitionRole(UpdatePartitionRoleRequest(
        id: id,
        name: name,
        state: state,
        properties: properties,
      )))
          .data;

  Future<void> removePartitionRole(String id) async =>
      _client.removePartitionRole(RemovePartitionRoleRequest(id: id));

  // ── Pages ────────────────────────────────────────────────────────────────

  Future<List<PageObject>> listPages({
    String? partitionId,
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listPage(ListPageRequest(
          cursor: PageCursor(limit: pageSize),
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
    Struct? properties,
  }) async =>
      (await _client.createPage(CreatePageRequest(
        partitionId: partitionId,
        name: name,
        html: html,
        properties: properties,
      )))
          .data;

  Future<PageObject> updatePage({
    required String id,
    String? name,
    String? html,
    STATE? state,
    Struct? properties,
  }) async =>
      (await _client.updatePage(UpdatePageRequest(
        id: id,
        name: name,
        html: html,
        state: state,
        properties: properties,
      )))
          .data;

  Future<void> removePage(String id) async =>
      _client.removePage(RemovePageRequest(id: id));

  // ── Access ───────────────────────────────────────────────────────────────

  Future<List<AccessObject>> listAccess({
    String? partitionId,
    String? profileId,
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listAccess(ListAccessRequest(
          partitionId: partitionId,
          profileId: profileId,
          cursor: PageCursor(limit: pageSize),
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
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listAccessRole(ListAccessRoleRequest(
          accessId: accessId,
          cursor: PageCursor(limit: pageSize),
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

  // ── Service Accounts ─────────────────────────────────────────────────────

  Future<List<ServiceAccountObject>> listServiceAccounts({
    String? partitionId,
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listServiceAccount(ListServiceAccountRequest(
          partitionId: partitionId,
          cursor: PageCursor(limit: pageSize),
        )),
        (r) => (r as ListServiceAccountResponse).data,
      );

  Future<ServiceAccountObject> getServiceAccount(String id) async =>
      (await _client
              .getServiceAccount(GetServiceAccountRequest(id: id)))
          .data;

  Future<({ServiceAccountObject account, String clientSecret})>
      createServiceAccount({
    required String partitionId,
    required String profileId,
    required String name,
    String type = '',
    List<String> audiences = const [],
    List<String> roles = const [],
    Struct? properties,
  }) async {
    final response = await _client
        .createServiceAccount(CreateServiceAccountRequest(
      partitionId: partitionId,
      profileId: profileId,
      name: name,
      type: type,
      audiences: audiences,
      roles: roles,
      properties: properties,
    ));
    return (account: response.data, clientSecret: response.clientSecret);
  }

  Future<ServiceAccountObject> updateServiceAccount({
    required String id,
    STATE? state,
    List<String>? audiences,
    Struct? properties,
  }) async =>
      (await _client
              .updateServiceAccount(UpdateServiceAccountRequest(
        id: id,
        state: state,
        audiences: audiences,
        properties: properties,
      )))
          .data;

  Future<void> removeServiceAccount(String id) async =>
      _client.removeServiceAccount(
          RemoveServiceAccountRequest(id: id));

  // ── Clients (OAuth2) ─────────────────────────────────────────────────────

  Future<List<ClientObject>> listClients({
    String? partitionId,
    String? serviceAccountId,
    int pageSize = 50,
  }) =>
      _collectStream(
        _client.listClient(ListClientRequest(
          partitionId: partitionId,
          serviceAccountId: serviceAccountId,
          cursor: PageCursor(limit: pageSize),
        )),
        (r) => (r as ListClientResponse).data,
      );

  Future<ClientObject> getClient(String id) async =>
      (await _client.getClient(GetClientRequest(id: id))).data;

  Future<({ClientObject client, String clientSecret})> createClient({
    required String name,
    String type = '',
    List<String> grantTypes = const [],
    List<String> responseTypes = const [],
    List<String> redirectUris = const [],
    String scopes = '',
    List<String> audiences = const [],
    List<String> roles = const [],
    String? partitionId,
    String? serviceAccountId,
    Struct? properties,
  }) async {
    final response = await _client.createClient(CreateClientRequest(
      name: name,
      type: type,
      grantTypes: grantTypes,
      responseTypes: responseTypes,
      redirectUris: redirectUris,
      scopes: scopes,
      audiences: audiences,
      roles: roles,
      partitionId: partitionId,
      serviceAccountId: serviceAccountId,
      properties: properties,
    ));
    return (client: response.data, clientSecret: response.clientSecret);
  }

  Future<ClientObject> updateClient({
    required String id,
    String? name,
    List<String>? grantTypes,
    List<String>? responseTypes,
    List<String>? redirectUris,
    String? scopes,
    List<String>? audiences,
    List<String>? roles,
    STATE? state,
    Struct? properties,
  }) async =>
      (await _client.updateClient(UpdateClientRequest(
        id: id,
        name: name,
        grantTypes: grantTypes,
        responseTypes: responseTypes,
        redirectUris: redirectUris,
        scopes: scopes,
        audiences: audiences,
        roles: roles,
        state: state,
        properties: properties,
      )))
          .data;

  Future<void> removeClient(String id) async =>
      _client.removeClient(RemoveClientRequest(id: id));
}

// ─── Riverpod Provider ───────────────────────────────────────────────────────

final partitionRepositoryProvider =
    FutureProvider<PartitionRepository>((ref) async {
  final client = await ref.watch(partitionServiceClientProvider.future);
  return PartitionRepository(client);
});
