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
/// Tabs: Overview | Roles | Access | Service Accounts | Clients
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
      length: 5,
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
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Roles'),
              Tab(text: 'Access'),
              Tab(text: 'Service Accounts'),
              Tab(text: 'Clients'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(partition: partition),
                _RolesTab(partitionId: partitionId),
                _AccessTab(partitionId: partitionId),
                const _ServiceAccountsTab(),
                const _ClientsTab(),
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
      child: _InfoCard(
        title: 'Partition Details',
        rows: [
          ('Name', partition.name),
          ('Description', partition.description),
          ('Tenant ID', partition.tenantId),
          if (partition.hasParentId()) ('Parent ID', partition.parentId),
          ('State', partition.state.name),
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
      error: (error, _) => _ErrorState(
        message: 'Failed to load roles',
        detail: error.toString(),
        onRetry: () =>
            ref.invalidate(partitionRolesForPartitionProvider(partitionId)),
      ),
      data: (roles) {
        if (roles.isEmpty) {
          return _EmptyState(
            icon: Icons.shield_outlined,
            message: 'No roles defined for this partition',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: roles.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
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

// ─── Access Tab ───────────────────────────────────────────────────────────────

class _AccessTab extends ConsumerWidget {
  const _AccessTab({required this.partitionId});

  final String partitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccess = ref.watch(accessListProvider);

    return asyncAccess.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Failed to load access grants',
        detail: error.toString(),
        onRetry: () => ref.invalidate(accessListProvider),
      ),
      data: (allAccess) {
        // Filter to this partition where possible
        final access = allAccess.where((a) {
          if (a.hasPartition()) return a.partition.id == partitionId;
          return true;
        }).toList();

        if (access.isEmpty) {
          return _EmptyState(
            icon: Icons.security_outlined,
            message: 'No access grants for this partition',
            action: 'Grant access to allow profiles to use this partition.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: access.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final a = access[index];
            return ExpansionTile(
              leading: Icon(Icons.vpn_key_outlined,
                  size: 20, color: AppColors.tertiary),
              title: Text(a.profileId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      fontSize: 13)),
              subtitle: Text('Access ID: ${a.id}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceMuted)),
              trailing: StateBadge(a.state),
              children: [
                _AccessRolesSection(accessId: a.id),
              ],
            );
          },
        );
      },
    );
  }
}

/// Inline section showing access roles for a given access grant.
class _AccessRolesSection extends ConsumerWidget {
  const _AccessRolesSection({required this.accessId});

  final String accessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles = ref.watch(accessRolesForAccessProvider(accessId));

    return asyncRoles.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading roles: $error',
            style: TextStyle(color: AppColors.error, fontSize: 12)),
      ),
      data: (roles) {
        if (roles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No roles assigned',
                style: TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 13)),
          );
        }
        return Column(
          children: [
            for (final role in roles)
              ListTile(
                dense: true,
                leading: Icon(Icons.badge_outlined,
                    size: 16, color: AppColors.tertiary),
                title: Text(
                  role.hasRole() ? role.role.name : role.id,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(role.id,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 10)),
              ),
          ],
        );
      },
    );
  }
}

// ─── Service Accounts Tab ─────────────────────────────────────────────────────

class _ServiceAccountsTab extends StatelessWidget {
  const _ServiceAccountsTab();

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.engineering_outlined,
      message: 'Service Accounts',
      action:
          'Service account management will be available in a future API update.',
    );
  }
}

// ─── Clients Tab ──────────────────────────────────────────────────────────────

class _ClientsTab extends StatelessWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.key_outlined,
      message: 'OAuth2 Clients',
      action: 'Client management will be available in a future API update.',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted)),
          if (action != null) ...[
            const SizedBox(height: 8),
            Text(action!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted)),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 36, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(detail,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
