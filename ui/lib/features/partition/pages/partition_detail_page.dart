import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/partition_providers.dart';
import '../widgets/state_badge.dart';

/// Detail page for a single partition, shown at
/// /services/tenancy/partitions/:partitionId.
///
/// Tabs: Overview | Roles | Pages
class PartitionDetailPage extends ConsumerWidget {
  const PartitionDetailPage({super.key, required this.partitionId});

  final String partitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPartition = ref.watch(partitionDetailProvider(partitionId));

    return asyncPartition.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load partition',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(partitionDetailProvider(partitionId)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (partition) => _PartitionDetailContent(
        partition: partition,
        partitionId: partitionId,
      ),
    );
  }
}

class _PartitionDetailContent extends ConsumerWidget {
  const _PartitionDetailContent({
    required this.partition,
    required this.partitionId,
  });

  final PartitionObject partition;
  final String partitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: partition.name,
              breadcrumbs: [
                'Services',
                'Tenancy Service',
                'Partitions',
                partition.name,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/services/tenancy/partitions'),
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
                StateBadge(partition.state),
                const SizedBox(width: 12),
                Text('ID: ${partition.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (partition.hasCreatedAt()) ...[
                  const SizedBox(width: 16),
                  Text(
                      'Created: ${DateFormat.yMMMd().format(partition.createdAt.toDateTime())}',
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
              Tab(text: 'Roles'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(partition: partition),
                _RolesTab(partitionId: partitionId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.partition});

  final PartitionObject partition;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'Partition Details',
            rows: [
              ('Name', partition.name),
              ('Description', partition.description),
              ('Tenant ID', partition.tenantId),
              if (partition.hasParentId()) ('Parent ID', partition.parentId),
              ('State', partition.state.name),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Roles Tab ────────────────────────────────────────────────────────────────

class _RolesTab extends ConsumerWidget {
  const _RolesTab({required this.partitionId});

  final String partitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles =
        ref.watch(partitionRolesForPartitionProvider(partitionId));

    return asyncRoles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load roles',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (roles) {
        if (roles.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    size: 48, color: AppColors.onSurfaceMuted),
                const SizedBox(height: 12),
                Text('No roles defined for this partition',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: roles.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final role = roles[index];
            return ListTile(
              leading: Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.tertiary),
              title: Text(role.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(role.id,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11)),
              trailing: StateBadge(role.state),
            );
          },
        );
      },
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            for (final (label, value) in rows)
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
    );
  }
}
