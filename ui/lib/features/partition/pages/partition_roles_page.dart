import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/entity_list_page.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/async_entity_list.dart';
import '../widgets/state_badge.dart';

class PartitionRolesPage extends ConsumerWidget {
  const PartitionRolesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<PartitionRoleObject>(
      dataProvider: partitionRolesProvider,
      title: 'Partition Roles',
      breadcrumbs: ['Services', service.label, 'Partition Roles'],
      searchHint: 'Search roles...',
      addLabel: 'New Role',
      exportRow: (role) => [role.name, role.id, role.partitionId, role.state.name],
      columns: const [
        DataColumn(label: Text('NAME')),
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('PARTITION ID')),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (role, selected, onSelect) {
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
                Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(role.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            )),
            DataCell(Text(role.id,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(role.partitionId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(StateBadge(role.state)),
          ],
        );
      },
      detailBuilder: (role) => _RoleDetail(role: role),
      editFields: const [
        EditField(label: 'Role Name', key: 'name'),
        EditField(label: 'Partition ID', key: 'partitionId'),
        EditField(
          label: 'State',
          key: 'state',
          type: EditFieldType.dropdown,
          options: ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED'],
        ),
      ],
      editTitle: (role) => 'Edit ${role.name}',
      editValuesExtractor: (role) => {
        'name': role.name,
        'partitionId': role.partitionId,
        'state': role.state.name,
      },
      onSave: (role, values) async {
        try {
          final repo = await ref.read(partitionRepositoryProvider.future);
          if (role == null) {
            // Create new partition role
            final partitionId = values['partitionId'] ?? '';
            final name = values['name'] ?? '';
            if (partitionId.isEmpty || name.isEmpty) {
              debugPrint('Partition ID and Role Name are required');
              return;
            }
            await repo.createPartitionRole(
              partitionId: partitionId,
              name: name,
            );
          } else {
            // No update RPC available; remove and re-create to apply changes.
            await repo.removePartitionRole(role.id);
            await repo.createPartitionRole(
              partitionId: values['partitionId'] ?? role.partitionId,
              name: values['name'] ?? role.name,
            );
          }
          ref.invalidate(partitionRolesProvider);
        } catch (e) {
          debugPrint('Error saving partition role: $e');
        }
      },
      onRefresh: () => ref.invalidate(partitionRolesProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _RoleDetail extends StatelessWidget {
  const _RoleDetail({required this.role});

  final PartitionRoleObject role;

  @override
  Widget build(BuildContext context) {
    final createdAt = role.hasCreatedAt()
        ? DateFormat.yMd().format(role.createdAt.toDateTime())
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
              child: Icon(Icons.shield_outlined,
                  size: 24, color: AppColors.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(role.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Partition ID', value: role.partitionId),
        _DetailRow(label: 'State', value: role.state.name),
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
