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
import '../widgets/state_badge.dart';

/// Detail page for a single partition at
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

  Future<void> _editPartition(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'Edit ${partition.name}',
      fields: [
        DialogField(
            key: 'name', label: 'Partition Name', initialValue: partition.name),
        DialogField(
          key: 'description',
          label: 'Description',
          initialValue: partition.description,
          type: DialogFieldType.textarea,
          maxLines: 3,
        ),
        DialogField(
          key: 'state',
          label: 'State',
          initialValue: partition.state.name,
          type: DialogFieldType.dropdown,
          options: ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED'],
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.updatePartition(
        id: partitionId,
        name: values['name'],
        description: values['description'],
        state: STATE.values
            .where((s) => s.name == values['state'])
            .firstOrNull,
      );
      ref.invalidate(partitionDetailProvider(partitionId));
      ref.invalidate(partitionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partition updated')),
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editPartition(context, ref),
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
                const _PlaceholderTab(
                  icon: Icons.engineering_outlined,
                  title: 'Service Accounts',
                  subtitle:
                      'Service account management will be available in a future API update.',
                ),
                const _PlaceholderTab(
                  icon: Icons.key_outlined,
                  title: 'OAuth2 Clients',
                  subtitle:
                      'Client management will be available in a future API update.',
                ),
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

  Future<void> _createRole(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'New Role',
      saveLabel: 'Create',
      fields: [
        const DialogField(key: 'name', label: 'Role Name'),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createPartitionRole(
        partitionId: partitionId,
        name: values['name'] ?? '',
      );
      ref.invalidate(partitionRolesForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteRole(
      BuildContext context, WidgetRef ref, PartitionRoleObject role) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Role',
      message: 'Remove role "${role.name}"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removePartitionRole(role.id);
      ref.invalidate(partitionRolesForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

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
      data: (roles) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _createRole(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Role'),
                ),
              ],
            ),
          ),
          if (roles.isEmpty)
            Expanded(
              child: _PlaceholderTab(
                icon: Icons.shield_outlined,
                title: 'No roles defined',
                subtitle: 'Create roles to control access to this partition.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: roles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StateBadge(role.state),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () => _deleteRole(context, ref, role),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Access Tab ───────────────────────────────────────────────────────────────

class _AccessTab extends ConsumerWidget {
  const _AccessTab({required this.partitionId});

  final String partitionId;

  Future<void> _createAccess(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'Grant Access',
      saveLabel: 'Grant',
      fields: [
        const DialogField(
          key: 'profileId',
          label: 'Profile ID',
          hint: 'Enter the profile ID to grant access',
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createAccess(
        partitionId: partitionId,
        profileId: values['profileId'] ?? '',
      );
      ref.invalidate(accessListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access granted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeAccess(
      BuildContext context, WidgetRef ref, AccessObject access) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Access',
      message: 'Remove access for profile ${access.profileId}?',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeAccess(access.id);
      ref.invalidate(accessListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

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
        final access = allAccess.where((a) {
          if (a.hasPartition()) return a.partition.id == partitionId;
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _createAccess(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Grant Access'),
                  ),
                ],
              ),
            ),
            if (access.isEmpty)
              const Expanded(
                child: _PlaceholderTab(
                  icon: Icons.security_outlined,
                  title: 'No access grants',
                  subtitle:
                      'Grant access to allow profiles to use this partition.',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: access.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
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
                              fontSize: 11,
                              color: AppColors.onSurfaceMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StateBadge(a.state),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: AppColors.error),
                            tooltip: 'Remove access',
                            onPressed: () => _removeAccess(context, ref, a),
                          ),
                        ],
                      ),
                      children: [
                        _AccessRolesSection(
                          accessId: a.id,
                          partitionId: partitionId,
                        ),
                      ],
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

/// Inline section showing access roles with add/remove.
class _AccessRolesSection extends ConsumerWidget {
  const _AccessRolesSection({
    required this.accessId,
    required this.partitionId,
  });

  final String accessId;
  final String partitionId;

  Future<void> _addRole(BuildContext context, WidgetRef ref,
      List<PartitionRoleObject> availableRoles) async {
    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No partition roles available. Create roles first.')),
      );
      return;
    }

    final values = await showEditDialog(
      context: context,
      title: 'Assign Role',
      saveLabel: 'Assign',
      fields: [
        DialogField(
          key: 'roleId',
          label: 'Partition Role',
          type: DialogFieldType.dropdown,
          options: availableRoles.map((r) => '${r.name} (${r.id})').toList(),
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    final selectedText = values['roleId'] ?? '';
    final selectedRole = availableRoles.where((r) =>
        '${r.name} (${r.id})' == selectedText).firstOrNull;
    if (selectedRole == null) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createAccessRole(
        accessId: accessId,
        partitionRoleId: selectedRole.id,
      );
      ref.invalidate(accessRolesForAccessProvider(accessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role assigned')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeRole(
      BuildContext context, WidgetRef ref, AccessRoleObject role) async {
    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeAccessRole(role.id);
      ref.invalidate(accessRolesForAccessProvider(accessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles = ref.watch(accessRolesForAccessProvider(accessId));
    final asyncPartitionRoles =
        ref.watch(partitionRolesForPartitionProvider(partitionId));

    return asyncRoles.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error',
            style: TextStyle(color: AppColors.error, fontSize: 12)),
      ),
      data: (roles) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Assigned Roles',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final available =
                        asyncPartitionRoles.value ?? [];
                    _addRole(context, ref, available);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Assign Role'),
                ),
              ],
            ),
            if (roles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No roles assigned',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13)),
              )
            else
              for (final role in roles)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.badge_outlined,
                      size: 16, color: AppColors.tertiary),
                  title: Text(
                    role.hasRole() ? role.role.name : role.id,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 16, color: AppColors.error),
                    tooltip: 'Remove role',
                    onPressed: () => _removeRole(context, ref, role),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }
}

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
        ], // children
      ), // Column
    ); // Center / return
  }
}
