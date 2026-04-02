import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/partition_providers.dart';
import '../widgets/state_badge.dart';

/// Detail page for a single tenant, shown at
/// /services/tenancy/tenants/:tenantId.
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
      data: (tenant) => _TenantDetailContent(tenant: tenant),
    );
  }
}

class _TenantDetailContent extends ConsumerWidget {
  const _TenantDetailContent({required this.tenant});

  final TenantObject tenant;

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
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
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
                  tenantId: tenant.id,
                  partitions: asyncPartitions,
                ),
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

class _PartitionsTab extends StatelessWidget {
  const _PartitionsTab({
    required this.tenantId,
    required this.partitions,
  });

  final String tenantId;
  final AsyncValue<List<PartitionObject>> partitions;

  @override
  Widget build(BuildContext context) {
    return partitions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allPartitions) {
        final filtered =
            allPartitions.where((p) => p.tenantId == tenantId).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 48, color: AppColors.onSurfaceMuted),
                const SizedBox(height: 12),
                Text('No partitions for this tenant',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = filtered[index];
            return ListTile(
              leading: Icon(Icons.account_tree_outlined,
                  size: 20, color: AppColors.tertiary),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(p.id,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11)),
              trailing: StateBadge(p.state),
              onTap: () =>
                  context.go('/services/tenancy/partitions/${p.id}'),
            );
          },
        );
      },
    );
  }
}
