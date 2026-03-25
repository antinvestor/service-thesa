import 'package:antinvestor_api_partition/antinvestor_api_partition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/entity_list_page.dart';
import '../data/partition_providers.dart';
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
        DataColumn(label: Text('ENVIRONMENT')),
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
            DataCell(EnvironmentBadge(tenant.environment.name)),
            DataCell(StateBadge(tenant.state)),
            DataCell(Text(createdAt)),
          ],
        );
      },
      detailBuilder: (tenant) => _TenantDetail(tenant: tenant),
      editFields: const [
        EditField(label: 'Tenant Name', key: 'name'),
        EditField(
          label: 'Description',
          key: 'description',
          type: EditFieldType.textarea,
          maxLines: 3,
        ),
        EditField(
          label: 'Environment',
          key: 'environment',
          type: EditFieldType.dropdown,
          options: ['PRODUCTION', 'STAGING'],
        ),
        EditField(
          label: 'State',
          key: 'state',
          type: EditFieldType.dropdown,
          options: ['ACTIVE', 'INACTIVE'],
        ),
      ],
      editTitle: (tenant) => 'Edit ${tenant.name}',
      editValuesExtractor: (tenant) => {
        'name': tenant.name,
        'description': tenant.description,
        'environment': tenant.environment.name
            .replaceAll('TENANT_ENVIRONMENT_', ''),
        'state': tenant.state.name,
      },
      onSave: (tenant, values) {
        debugPrint('Save tenant: $values');
      },
      onRefresh: () => ref.invalidate(tenantsProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

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
        _DetailRow(label: 'Environment', value: tenant.environment.name
            .replaceAll('TENANT_ENVIRONMENT_', '')),
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
