import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [TenancyServiceClient] with error handling
/// and stream-to-list conversion for all partition service entities.
class PartitionRepository {
  PartitionRepository(this._client);

  final TenancyServiceClient _client;

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
    Struct? properties,
  }) async =>
      (await _client.createTenant(CreateTenantRequest(
        name: name,
        description: description,
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
  }) async =>
      (await _client.createServiceAccount(CreateServiceAccountRequest(
        partitionId: partitionId,
        name: name,
        type: type,
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
    String type = 'public',
    String scopes = 'openid',
  }) async =>
      (await _client.createClient(CreateClientRequest(
        name: name,
        type: type,
        scopes: scopes,
      )))
          .data;

  Future<void> removeClient(String id) async =>
      _client.removeClient(RemoveClientRequest(id: id));
}

// ─── Riverpod Provider ───────────────────────────────────────────────────────

final partitionRepositoryProvider =
    FutureProvider<PartitionRepository>((ref) async {
  final client = await ref.watch(tenancyServiceClientProvider.future);
  return PartitionRepository(client);
});
