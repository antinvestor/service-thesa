import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'partition_repository.dart';

/// Tenants list provider.
final tenantsProvider =
    FutureProvider<List<TenantObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listTenants();
});

/// Single tenant detail.
final tenantDetailProvider =
    FutureProvider.family<TenantObject, String>((ref, tenantId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.getTenant(tenantId);
});

/// Partitions list provider.
final partitionsProvider =
    FutureProvider<List<PartitionObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPartitions();
});

/// Single partition detail.
final partitionDetailProvider =
    FutureProvider.family<PartitionObject, String>((ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.getPartition(partitionId);
});

/// Partition roles list provider (all roles).
final partitionRolesProvider =
    FutureProvider<List<PartitionRoleObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPartitionRoles();
});

/// Partition roles scoped to a specific partition.
final partitionRolesForPartitionProvider =
    FutureProvider.family<List<PartitionRoleObject>, String>(
        (ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPartitionRoles(partitionId: partitionId);
});

/// Pages list provider (all pages).
final pagesProvider =
    FutureProvider<List<PageObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPages();
});

/// Pages scoped to a specific partition.
final pagesForPartitionProvider =
    FutureProvider.family<List<PageObject>, String>(
        (ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPages(partitionId: partitionId);
});

/// Access list provider (all access grants).
final accessListProvider =
    FutureProvider<List<AccessObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccess();
});

/// Access grants scoped to a specific partition.
final accessForPartitionProvider =
    FutureProvider.family<List<AccessObject>, String>(
        (ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccess(partitionId: partitionId);
});

/// Access roles list provider (all).
final accessRolesProvider =
    FutureProvider<List<AccessRoleObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccessRoles();
});

/// Access roles scoped to a specific access grant.
final accessRolesForAccessProvider =
    FutureProvider.family<List<AccessRoleObject>, String>(
        (ref, accessId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccessRoles(accessId: accessId);
});

/// Service accounts scoped to a partition.
final serviceAccountsForPartitionProvider =
    FutureProvider.family<List<ServiceAccountObject>, String>(
        (ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listServiceAccounts(partitionId: partitionId);
});

/// Clients scoped to a partition.
final clientsForPartitionProvider =
    FutureProvider.family<List<ClientObject>, String>(
        (ref, partitionId) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listClients(partitionId: partitionId);
});

/// Registered service namespaces and their permissions.
final serviceNamespacesProvider =
    FutureProvider<List<ServiceNamespaceObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listServiceNamespaces();
});
