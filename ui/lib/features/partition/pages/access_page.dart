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

class AccessPage extends ConsumerWidget {
  const AccessPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<AccessObject>(
      dataProvider: accessListProvider,
      title: 'Access',
      breadcrumbs: ['Services', service.label, 'Access'],
      searchHint: 'Search access grants...',
      addLabel: 'New Access',
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('PROFILE ID')),
        DataColumn(label: Text('PARTITION')),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (access, selected, onSelect) {
        final partitionName = access.hasPartition()
            ? access.partition.name
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
            DataCell(Text(access.id,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(access.profileId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(partitionName)),
            DataCell(StateBadge(access.state)),
          ],
        );
      },
      detailBuilder: (access) => _AccessDetail(access: access),
      editFields: const [
        EditField(label: 'Partition ID', key: 'partitionId'),
        EditField(label: 'Profile ID', key: 'profileId'),
      ],
      editTitle: (access) => 'Edit Access ${access.id}',
      editValuesExtractor: (access) => {
        'partitionId': access.hasPartition() ? access.partition.id : '',
        'profileId': access.profileId,
      },
      onSave: (access, values) {
        debugPrint('Save access: $values');
      },
      onRefresh: () => ref.invalidate(accessListProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _AccessDetail extends StatelessWidget {
  const _AccessDetail({required this.access});

  final AccessObject access;

  @override
  Widget build(BuildContext context) {
    final createdAt = access.hasCreatedAt()
        ? DateFormat.yMd().format(access.createdAt.toDateTime())
        : 'N/A';

    final partitionName = access.hasPartition()
        ? access.partition.name
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
              child: Icon(Icons.vpn_key_outlined,
                  size: 24, color: AppColors.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Access Grant',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(access.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Profile ID', value: access.profileId),
        _DetailRow(label: 'Partition', value: partitionName),
        _DetailRow(label: 'State', value: access.state.name),
        _DetailRow(label: 'Created', value: createdAt),
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
