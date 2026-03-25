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

class ClientsPage extends ConsumerWidget {
  const ClientsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<ClientObject>(
      dataProvider: clientsProvider,
      title: 'Clients',
      breadcrumbs: ['Services', service.label, 'Clients'],
      searchHint: 'Search clients...',
      addLabel: 'New Client',
      columns: const [
        DataColumn(label: Text('NAME')),
        DataColumn(label: Text('CLIENT ID')),
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('SCOPES')),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (client, selected, onSelect) {
        final scopes = client.scopes;

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
                    client.name.isNotEmpty
                        ? client.name.substring(0, 1)
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Text(client.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            )),
            DataCell(Text(client.clientId,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(client.type)),
            DataCell(Text(
              scopes.length > 40 ? '${scopes.substring(0, 40)}...' : scopes,
              style: const TextStyle(fontSize: 12),
            )),
            DataCell(StateBadge(client.state)),
          ],
        );
      },
      detailBuilder: (client) => _ClientDetail(client: client),
      editFields: const [
        EditField(label: 'Client Name', key: 'name'),
        EditField(label: 'Type', key: 'type'),
        EditField(label: 'Scopes (comma-separated)', key: 'scopes'),
        EditField(label: 'Redirect URIs (comma-separated)', key: 'redirectUris'),
        EditField(
          label: 'State',
          key: 'state',
          type: EditFieldType.dropdown,
          options: ['ACTIVE', 'INACTIVE'],
        ),
      ],
      editTitle: (client) => 'Edit ${client.name}',
      editValuesExtractor: (client) => {
        'name': client.name,
        'type': client.type,
        'scopes': client.scopes,
        'redirectUris': client.redirectUris.join(', '),
        'state': client.state.name,
      },
      onSave: (client, values) {
        debugPrint('Save client: $values');
      },
      onRefresh: () => ref.invalidate(clientsProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _ClientDetail extends StatelessWidget {
  const _ClientDetail({required this.client});

  final ClientObject client;

  @override
  Widget build(BuildContext context) {
    final createdAt = client.hasCreatedAt()
        ? DateFormat.yMd().format(client.createdAt.toDateTime())
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
                  client.name.isNotEmpty ? client.name.substring(0, 1) : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(client.clientId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Type', value: client.type),
        _DetailRow(label: 'State', value: client.state.name),
        _DetailRow(label: 'Created', value: createdAt),
        const SizedBox(height: 16),
        _buildListSection(context, 'Grant Types', client.grantTypes),
        _buildListSection(context, 'Response Types', client.responseTypes),
        _buildListSection(context, 'Redirect URIs', client.redirectUris),
        _buildListSection(context, 'Scopes',
            client.scopes.isNotEmpty ? client.scopes.split(' ') : []),
        _buildListSection(context, 'Audiences', client.audiences),
        _buildListSection(context, 'Roles', client.roles),
      ],
    );
  }

  Widget _buildListSection(
      BuildContext context, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((item) => Chip(
                      label: Text(item,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
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
            width: 90,
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
