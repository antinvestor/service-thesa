import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/async_entity_list.dart';
import '../widgets/state_badge.dart';

class TenantsPage extends ConsumerWidget {
  const TenantsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<TenantObject>(
      dataProvider: tenantsProvider,
      title: 'Tenants',
      breadcrumbs: ['Services', service.label, 'Tenants'],
      searchHint: 'Search tenants...',
      addLabel: 'New Tenant',
      columns: const [
        DataColumn(label: Text('TENANT NAME')),
        DataColumn(label: Text('IDENTIFIER')),
        DataColumn(label: Text('STATE')),
        DataColumn(label: Text('CREATED')),
      ],
      rowBuilder: (tenant, selected, onSelect) {
        final createdAt = tenant.hasCreatedAt()
            ? DateFormat.yMd().format(tenant.createdAt.toDateTime())
            : '';

        return DataRow(
          selected: selected,
          onSelectChanged: (_) => onSelect(),
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.tertiary.withValues(alpha: 0.05);
            }
            return null;
          }),
          cells: [
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    tenant.name.isNotEmpty ? tenant.name.substring(0, 1) : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Text(tenant.name),
              ],
            )),
            DataCell(Text(tenant.id,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(StateBadge(tenant.state)),
            DataCell(Text(createdAt)),
          ],
        );
      },
      onAdd: () async {
        final values = await showEditDialog(
          context: context,
          title: 'New Tenant',
          saveLabel: 'Create',
          fields: const [
            DialogField(key: 'name', label: 'Tenant Name'),
            DialogField(
              key: 'description',
              label: 'Description',
              type: DialogFieldType.textarea,
              maxLines: 2,
            ),
          ],
        );
        if (values == null || !context.mounted) return;
        try {
          final repo = await ref.read(partitionRepositoryProvider.future);
          await repo.createTenant(
            name: values['name'] ?? '',
            description: values['description'] ?? '',
          );
          ref.invalidate(tenantsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tenant created')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
      onRefresh: () => ref.invalidate(tenantsProvider),
      onRowNavigate: (tenant) =>
          context.go('/services/tenancy/tenants/${tenant.id}'),
    );
  }
}

class _TenantDetail extends StatelessWidget {
  const _TenantDetail({required this.tenant});

  final TenantObject tenant;

  @override
  Widget build(BuildContext context) {
    final createdAt = tenant.hasCreatedAt()
        ? DateFormat.yMd().format(tenant.createdAt.toDateTime())
        : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(
                  tenant.name.isNotEmpty ? tenant.name.substring(0, 1) : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(tenant.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'State', value: tenant.state.name),
        _DetailRow(label: 'Created', value: createdAt),
        const SizedBox(height: 16),
        if (tenant.description.isNotEmpty) ...[
          Text('Description',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(tenant.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
    );
  }
}
