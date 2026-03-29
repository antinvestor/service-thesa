import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'partition_repository.dart';

/// Tenants list provider.
final tenantsProvider =
    FutureProvider.autoDispose<List<TenantObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listTenants();
});

/// Partitions list provider.
final partitionsProvider =
    FutureProvider.autoDispose<List<PartitionObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPartitions();
});

/// Partition roles list provider.
final partitionRolesProvider =
    FutureProvider.autoDispose<List<PartitionRoleObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPartitionRoles();
});

/// Pages list provider.
/// TODO: Implement when ListPage RPC is available in the API.
final pagesProvider =
    FutureProvider.autoDispose<List<PageObject>>((ref) async {
  return <PageObject>[];
});

/// Access list provider.
/// TODO: Implement when ListAccess RPC is available in the API.
final accessListProvider =
    FutureProvider.autoDispose<List<AccessObject>>((ref) async {
  return <AccessObject>[];
});

/// Access roles list provider.
final accessRolesProvider =
    FutureProvider.autoDispose<List<AccessRoleObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccessRoles();
});
