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

class ServiceAccountsPage extends ConsumerWidget {
  const ServiceAccountsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<ServiceAccountObject>(
      dataProvider: serviceAccountsProvider,
      title: 'Service Accounts',
      breadcrumbs: ['Services', service.label, 'Service Accounts'],
      searchHint: 'Search service accounts...',
      addLabel: 'New Service Account',
      columns: const [
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('PARTITION ID')),
        DataColumn(label: Text('CLIENT ID')),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (account, selected, onSelect) {
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
                Icon(Icons.manage_accounts_outlined,
                    size: 16, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(account.type,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            )),
            DataCell(Text(account.id,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(account.partitionId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(account.clientId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(StateBadge(account.state)),
          ],
        );
      },
      detailBuilder: (account) =>
          _ServiceAccountDetail(account: account),
      editFields: const [
        EditField(label: 'Type', key: 'type'),
        EditField(
          label: 'State',
          key: 'state',
          type: EditFieldType.dropdown,
          options: ['ACTIVE', 'INACTIVE'],
        ),
      ],
      editTitle: (account) => 'Edit Service Account ${account.id}',
      editValuesExtractor: (account) => {
        'type': account.type,
        'state': account.state.name,
      },
      onSave: (account, values) {
        debugPrint('Save service account: $values');
      },
      onRefresh: () => ref.invalidate(serviceAccountsProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _ServiceAccountDetail extends StatelessWidget {
  const _ServiceAccountDetail({required this.account});

  final ServiceAccountObject account;

  @override
  Widget build(BuildContext context) {
    final createdAt = account.hasCreatedAt()
        ? DateFormat.yMd().format(account.createdAt.toDateTime())
        : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.manage_accounts_outlined,
                  size: 24, color: AppColors.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Account',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(account.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Type', value: account.type),
        _DetailRow(label: 'Tenant ID', value: account.tenantId),
        _DetailRow(label: 'Partition ID', value: account.partitionId),
        _DetailRow(label: 'Profile ID', value: account.profileId),
        _DetailRow(label: 'Client ID', value: account.clientId),
        _DetailRow(label: 'State', value: account.state.name),
        _DetailRow(label: 'Created', value: createdAt),
        const SizedBox(height: 16),
        if (account.audiences.isNotEmpty) ...[
          Text('Audiences',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: account.audiences
                .map((a) => Chip(
                      label: Text(a,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
