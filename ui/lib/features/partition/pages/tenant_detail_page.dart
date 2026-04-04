import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/create_partition_wizard.dart';
import '../widgets/state_badge.dart';

/// Detail page for a single tenant at /services/tenancy/tenants/:tenantId.
///
/// Tabs: Overview | Partitions
class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTenant = ref.watch(tenantDetailProvider(tenantId));

    return asyncTenant.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load tenant',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (tenant) =>
          _TenantDetailContent(tenant: tenant, tenantId: tenantId),
    );
  }
}

class _TenantDetailContent extends ConsumerWidget {
  const _TenantDetailContent({
    required this.tenant,
    required this.tenantId,
  });

  final TenantObject tenant;
  final String tenantId;

  Future<void> _editTenant(BuildContext context, WidgetRef ref) async {
    final envName = switch (tenant.environment) {
      TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION => 'Production',
      TenantEnvironment.TENANT_ENVIRONMENT_STAGING => 'Staging',
      _ => 'Production',
    };
    final values = await showEditDialog(
      context: context,
      title: 'Edit ${tenant.name}',
      fields: [
        DialogField(
            key: 'name', label: 'Tenant Name', initialValue: tenant.name),
        DialogField(
          key: 'description',
          label: 'Description',
          initialValue: tenant.description,
          type: DialogFieldType.textarea,
          maxLines: 3,
        ),
        DialogField(
          key: 'environment',
          label: 'Environment',
          initialValue: envName,
          type: DialogFieldType.dropdown,
          options: const ['Production', 'Staging'],
        ),
        DialogField(
          key: 'state',
          label: 'State',
          initialValue: tenant.state.name,
          type: DialogFieldType.dropdown,
          options: const ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED'],
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final envStr = values['environment'] ?? 'Production';
      final environment = envStr == 'Staging'
          ? TenantEnvironment.TENANT_ENVIRONMENT_STAGING
          : TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION;
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.updateTenant(
        id: tenantId,
        name: values['name'],
        description: values['description'],
        environment: environment,
        state: STATE.values
            .where((s) => s.name == values['state'])
            .firstOrNull,
      );
      ref.invalidate(tenantDetailProvider(tenantId));
      ref.invalidate(tenantsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPartitions = ref.watch(partitionsProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: tenant.name,
              breadcrumbs: [
                'Services',
                'Tenancy Service',
                'Tenants',
                tenant.name,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/services/tenancy/tenants'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editTenant(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                StateBadge(tenant.state),
                const SizedBox(width: 12),
                Text('ID: ${tenant.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (tenant.hasCreatedAt()) ...[
                  const SizedBox(width: 16),
                  Text(
                      'Created: ${DateFormat.yMMMd().format(tenant.createdAt.toDateTime())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Partitions'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(tenant: tenant),
                _PartitionsTab(
                    tenantId: tenant.id, partitions: asyncPartitions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.tenant});

  final TenantObject tenant;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              for (final (label, value) in [
                ('Name', tenant.name),
                ('Description', tenant.description),
                ('Environment', switch (tenant.environment) {
                  TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION => 'Production',
                  TenantEnvironment.TENANT_ENVIRONMENT_STAGING => 'Staging',
                  _ => 'Unspecified',
                }),
                ('State', tenant.state.name),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.onSurfaceMuted)),
                      ),
                      Expanded(
                        child: Text(value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartitionsTab extends ConsumerWidget {
  const _PartitionsTab({
    required this.tenantId,
    required this.partitions,
  });

  final String tenantId;
  final AsyncValue<List<PartitionObject>> partitions;

  Future<void> _createPartition(
      BuildContext context, WidgetRef ref, List<PartitionObject> existing) async {
    final result = await showCreatePartitionWizard(
      context: context,
      tenantId: tenantId,
      existingPartitions: existing,
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createPartition(
        tenantId: result.tenantId,
        name: result.name,
        parentId: result.parentId,
        description: result.description,
        domain: result.domain,
        properties: result.toPropertiesStruct(),
      );
      ref.invalidate(partitionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partition created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return partitions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allPartitions) {
        final filtered =
            allPartitions.where((p) => p.tenantId == tenantId).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _createPartition(context, ref, filtered),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Partition'),
                  ),
                ],
              ),
            ),
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      Text('No partitions for this tenant',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return ListTile(
                      leading: Icon(Icons.account_tree_outlined,
                          size: 20, color: AppColors.tertiary),
                      title: Text(p.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(p.id,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11)),
                      trailing: StateBadge(p.state),
                      onTap: () => context
                          .go('/services/tenancy/partitions/${p.id}'),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
