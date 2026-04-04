import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tenant_context.dart';
import '../theme/app_colors.dart';
import '../../features/partition/data/partition_providers.dart';

/// A compact tenant/partition context picker for the app header.
///
/// Shows the current working context (tenant + partition) and allows
/// switching. "All Tenants" mode shows data from the root context.
class TenantPicker extends ConsumerWidget {
  const TenantPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jwtContext = ref.watch(jwtTenantContextProvider);
    final activeOverride = ref.watch(activeTenantProvider);
    final asyncTenants = ref.watch(tenantsProvider);
    final asyncPartitions = ref.watch(partitionsProvider);

    final effectiveCtx = ref.watch(effectiveTenantProvider);

    return jwtContext.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (jwt) {
        // Resolve display names
        String tenantName = 'All Tenants';
        String partitionName = '';

        if (effectiveCtx.tenantId.isNotEmpty) {
          final tenants = asyncTenants.whenOrNull(data: (d) => d) ?? [];
          final tenant = tenants
              .where((t) => t.id == effectiveCtx.tenantId)
              .firstOrNull;
          tenantName = tenant?.name ?? effectiveCtx.tenantId;

          if (effectiveCtx.partitionId.isNotEmpty) {
            final partitions = asyncPartitions.whenOrNull(data: (d) => d) ?? [];
            final partition = partitions
                .where((p) => p.id == effectiveCtx.partitionId)
                .firstOrNull;
            partitionName = partition?.name ?? '';
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showPicker(context, ref, jwt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              color: activeOverride != null
                  ? AppColors.tertiary.withValues(alpha: 0.05)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined,
                    size: 16, color: AppColors.tertiary),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenantName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    if (partitionName.isNotEmpty)
                      Text(partitionName,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceMuted)),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more,
                    size: 16, color: AppColors.onSurfaceMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPicker(
      BuildContext context, WidgetRef ref, TenantContext jwt) {
    final tenants = ref.read(tenantsProvider).whenOrNull(data: (d) => d) ?? [];
    final partitions = ref.read(partitionsProvider).whenOrNull(data: (d) => d) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => _TenantPickerDialog(
        jwt: jwt,
        tenants: tenants,
        partitions: partitions,
        onSelect: (tenantId, partitionId) {
          if (tenantId == null) {
            // "All" mode - use JWT default
            ref.read(activeTenantProvider.notifier).clear();
          } else {
            ref.read(activeTenantProvider.notifier).set(
              jwt.copyWith(
                tenantId: tenantId,
                partitionId: partitionId ?? jwt.partitionId,
              ),
            );
          }
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _TenantPickerDialog extends StatefulWidget {
  const _TenantPickerDialog({
    required this.jwt,
    required this.tenants,
    required this.partitions,
    required this.onSelect,
  });

  final TenantContext jwt;
  final List<TenantObject> tenants;
  final List<PartitionObject> partitions;
  final void Function(String? tenantId, String? partitionId) onSelect;

  @override
  State<_TenantPickerDialog> createState() => _TenantPickerDialogState();
}

class _TenantPickerDialogState extends State<_TenantPickerDialog> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTenants = _query.isEmpty
        ? widget.tenants
        : widget.tenants
            .where(
                (t) => t.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return AlertDialog(
      title: const Text('Switch Tenant Context'),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                hintText: 'Search tenants...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),

            // JWT default info
            Card(
              color: AppColors.tertiary.withValues(alpha: 0.05),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.token, size: 18, color: AppColors.tertiary),
                title: const Text('JWT Default',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Tenant: ${widget.jwt.tenantId}\n'
                  'Roles: ${widget.jwt.roles.join(", ")}',
                  style:
                      const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // "All Tenants" option
            ListTile(
              dense: true,
              leading: Icon(Icons.public, size: 20, color: AppColors.tertiary),
              title: const Text('All Tenants (Root)',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('View data from your default JWT context',
                  style: TextStyle(fontSize: 11)),
              onTap: () => widget.onSelect(null, null),
            ),
            const Divider(height: 1),

            // Tenant list
            Expanded(
              child: ListView.builder(
                itemCount: filteredTenants.length,
                itemBuilder: (context, index) {
                  final tenant = filteredTenants[index];
                  final tenantPartitions = widget.partitions
                      .where((p) => p.tenantId == tenant.id)
                      .toList();

                  return ExpansionTile(
                    dense: true,
                    leading: Icon(Icons.business_outlined,
                        size: 18, color: AppColors.tertiary),
                    title: Text(tenant.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(tenant.id,
                        style: const TextStyle(
                            fontSize: 10, fontFamily: 'monospace')),
                    children: [
                      // Tenant-level selection (no specific partition)
                      ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.only(left: 48, right: 16),
                        title: Text('${tenant.name} (all partitions)',
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => widget.onSelect(tenant.id, null),
                      ),
                      // Per-partition selection
                      for (final partition in tenantPartitions)
                        ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 48, right: 16),
                          leading: Icon(Icons.account_tree_outlined,
                              size: 16, color: AppColors.onSurfaceMuted),
                          title: Text(partition.name,
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text(partition.id,
                              style: const TextStyle(
                                  fontSize: 10, fontFamily: 'monospace')),
                          onTap: () =>
                              widget.onSelect(tenant.id, partition.id),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
