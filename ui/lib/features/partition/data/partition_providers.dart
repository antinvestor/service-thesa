import 'package:antinvestor_api_partition/antinvestor_api_partition.dart';
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
final pagesProvider =
    FutureProvider.autoDispose<List<PageObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listPages();
});

/// Access list provider.
final accessListProvider =
    FutureProvider.autoDispose<List<AccessObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccess();
});

/// Access roles list provider.
final accessRolesProvider =
    FutureProvider.autoDispose<List<AccessRoleObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listAccessRoles();
});

/// Service accounts list provider.
final serviceAccountsProvider =
    FutureProvider.autoDispose<List<ServiceAccountObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listServiceAccounts();
});

/// OAuth2 clients list provider.
final clientsProvider =
    FutureProvider.autoDispose<List<ClientObject>>((ref) async {
  final repo = await ref.watch(partitionRepositoryProvider.future);
  return repo.listClients();
});
