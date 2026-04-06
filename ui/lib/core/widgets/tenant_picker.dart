import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tenant_context.dart';
import '../theme/app_colors.dart';
import '../../features/partition/data/partition_providers.dart';

/// Displays the active tenant/partition context in the app header.
///
/// This is a read-only indicator. Context switching is done from the
/// partition detail page via the "Set as Active" action, giving users
/// full visibility into the partition they are switching to.
///
/// When an override is active (i.e. the user switched away from their
/// JWT default), a reset button allows returning to the default context.
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
        String tenantName = effectiveCtx.tenantId;
        String partitionName = '';

        if (effectiveCtx.tenantId.isNotEmpty) {
          final tenants = asyncTenants.whenOrNull(data: (d) => d) ?? [];
          final tenant = tenants
              .where((t) => t.id == effectiveCtx.tenantId)
              .firstOrNull;
          tenantName = tenant?.name ?? effectiveCtx.tenantId;

          if (effectiveCtx.partitionId.isNotEmpty) {
            final partitions =
                asyncPartitions.whenOrNull(data: (d) => d) ?? [];
            final partition = partitions
                .where((p) => p.id == effectiveCtx.partitionId)
                .firstOrNull;
            partitionName = partition?.name ?? '';
          }
        }

        final hasOverride = activeOverride != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasOverride ? AppColors.tertiary : AppColors.border,
            ),
            color: hasOverride
                ? AppColors.tertiary.withValues(alpha: 0.05)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined,
                  size: 16, color: AppColors.tertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenant: $tenantName',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    if (partitionName.isNotEmpty)
                      Text('Partition: $partitionName',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    Text(effectiveCtx.partitionId,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: AppColors.onSurfaceMuted)),
                  ],
                ),
              ),
              if (hasOverride) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Reset to default context',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(activeTenantProvider.notifier).clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Returned to default context')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close,
                          size: 14, color: AppColors.tertiary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
