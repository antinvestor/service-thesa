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

/// Pages list provider.
/// TODO: Implement when ListPage RPC is available in the API.
final pagesProvider =
    FutureProvider<List<PageObject>>((ref) async {
  return <PageObject>[];
});

/// Access list provider.
/// TODO: Implement when ListAccess RPC is available in the API.
final accessListProvider =
    FutureProvider<List<AccessObject>>((ref) async {
  return <AccessObject>[];
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
