import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../data/partition_providers.dart';
import '../widgets/async_entity_list.dart';

class AccessRolesPage extends ConsumerWidget {
  const AccessRolesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<AccessRoleObject>(
      dataProvider: accessRolesProvider,
      title: 'Access Roles',
      breadcrumbs: ['Services', service.label, 'Access Roles'],
      searchHint: 'Search access roles...',
      addLabel: 'New Access Role',
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('ACCESS ID')),
        DataColumn(label: Text('ROLE NAME')),
      ],
      rowBuilder: (accessRole, selected, onSelect) {
        final roleName = accessRole.hasRole()
            ? accessRole.role.name
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
            DataCell(Text(accessRole.id,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(accessRole.accessId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(roleName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            )),
          ],
        );
      },
      detailBuilder: (accessRole) =>
          _AccessRoleDetail(accessRole: accessRole),
      onRefresh: () => ref.invalidate(accessRolesProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _AccessRoleDetail extends StatelessWidget {
  const _AccessRoleDetail({required this.accessRole});

  final AccessRoleObject accessRole;

  @override
  Widget build(BuildContext context) {
    final roleName = accessRole.hasRole()
        ? accessRole.role.name
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
                  Text('Access Role Assignment',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(accessRole.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Access ID', value: accessRole.accessId),
        _DetailRow(label: 'Role Name', value: roleName),
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
