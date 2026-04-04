import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/create_partition_wizard.dart';
import '../widgets/state_badge.dart';

/// Detail page for a single tenant at /services/tenancy/tenants/:tenantId.
///
/// Tabs: Overview | Partitions
class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTenant = ref.watch(tenantDetailProvider(tenantId));

    return asyncTenant.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load tenant',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (tenant) =>
          _TenantDetailContent(tenant: tenant, tenantId: tenantId),
    );
  }
}

class _TenantDetailContent extends ConsumerWidget {
  const _TenantDetailContent({
    required this.tenant,
    required this.tenantId,
  });

  final TenantObject tenant;
  final String tenantId;

  Future<void> _editTenant(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_EditTenantResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditTenantDialog(tenant: tenant),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.updateTenant(
        id: tenantId,
        name: result.name,
        description: result.description,
        environment: result.environment,
        state: result.state,
        properties: result.toPropertiesStruct(),
      );
      ref.invalidate(tenantDetailProvider(tenantId));
      ref.invalidate(tenantsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant updated')),
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
    final asyncPartitions = ref.watch(partitionsProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: tenant.name,
              breadcrumbs: [
                'Services',
                'Tenancy Service',
                'Tenants',
                tenant.name,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/services/tenancy/tenants'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editTenant(context, ref),
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
                StateBadge(tenant.state),
                const SizedBox(width: 12),
                Text('ID: ${tenant.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (tenant.hasCreatedAt()) ...[
                  const SizedBox(width: 16),
                  Text(
                      'Created: ${DateFormat.yMMMd().format(tenant.createdAt.toDateTime())}',
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
              Tab(text: 'Partitions'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(tenant: tenant),
                _PartitionsTab(
                    tenantId: tenant.id, partitions: asyncPartitions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.tenant});

  final TenantObject tenant;

  String _envLabel() => switch (tenant.environment) {
        TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION => 'Production',
        TenantEnvironment.TENANT_ENVIRONMENT_STAGING => 'Staging',
        _ => 'Unspecified',
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tenant Details card
          _buildCard(
            context,
            title: 'Tenant Details',
            icon: Icons.business_outlined,
            child: Column(
              children: [
                _TenantDetailRow(label: 'Name', value: tenant.name),
                _TenantDetailRow(
                  label: 'Description',
                  value: tenant.description.isNotEmpty
                      ? tenant.description
                      : '—',
                ),
                _TenantDetailRow(
                  label: 'Environment',
                  value: _envLabel(),
                  icon: tenant.environment ==
                          TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION
                      ? Icons.cloud_done_outlined
                      : Icons.science_outlined,
                ),
                _TenantDetailRow(label: 'State', value: tenant.state.name),
                if (tenant.hasCreatedAt())
                  _TenantDetailRow(
                    label: 'Created',
                    value: DateFormat.yMMMd()
                        .format(tenant.createdAt.toDateTime()),
                  ),
              ],
            ),
          ),

          // Properties card (if any)
          if (tenant.hasProperties() &&
              tenant.properties.fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              context,
              title: 'Properties',
              icon: Icons.data_object,
              child: Column(
                children: [
                  for (final entry in tenant.properties.fields.entries)
                    _TenantDetailRow(
                      label: entry.key,
                      value: _formatValue(entry.value),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatValue(Value v) {
    if (v.hasStringValue()) return v.stringValue;
    if (v.hasBoolValue()) return v.boolValue ? 'true' : 'false';
    if (v.hasNumberValue()) return v.numberValue.toString();
    if (v.hasStructValue()) {
      return v.structValue.fields.entries
          .map((e) => '${e.key}: ${_formatValue(e.value)}')
          .join(', ');
    }
    return '—';
  }

  Widget _buildCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Widget child}) {
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
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TenantDetailRow extends StatelessWidget {
  const _TenantDetailRow({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 4),
          ],
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

// ─── Edit Tenant Dialog ──────────────────────────────────────────────────────

class _EditTenantResult {
  const _EditTenantResult({
    required this.name,
    required this.description,
    required this.environment,
    this.state,
    this.properties,
  });

  final String name;
  final String description;
  final TenantEnvironment environment;
  final STATE? state;
  final Map<String, String>? properties;

  Struct? toPropertiesStruct() {
    if (properties == null || properties!.isEmpty) return null;
    final fields = <String, Value>{};
    for (final entry in properties!.entries) {
      if (entry.value.isNotEmpty) {
        fields[entry.key] = Value(stringValue: entry.value);
      }
    }
    if (fields.isEmpty) return null;
    return Struct(fields: fields);
  }
}

class _EditTenantDialog extends StatefulWidget {
  const _EditTenantDialog({required this.tenant});
  final TenantObject tenant;

  @override
  State<_EditTenantDialog> createState() => _EditTenantDialogState();
}

class _EditTenantDialogState extends State<_EditTenantDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late String _env;
  late String _state;
  final _propControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.tenant.name);
    _descCtl = TextEditingController(text: widget.tenant.description);
    _env = switch (widget.tenant.environment) {
      TenantEnvironment.TENANT_ENVIRONMENT_STAGING => 'Staging',
      _ => 'Production',
    };
    _state = widget.tenant.state.name;

    // Initialize property controllers from existing properties
    if (widget.tenant.hasProperties()) {
      for (final entry in widget.tenant.properties.fields.entries) {
        _propControllers[entry.key] = TextEditingController(
            text: _valueToString(entry.value));
      }
    }
  }

  String _valueToString(Value v) {
    if (v.hasStringValue()) return v.stringValue;
    if (v.hasBoolValue()) return v.boolValue.toString();
    if (v.hasNumberValue()) return v.numberValue.toString();
    if (v.hasStructValue()) {
      return v.structValue.fields.entries
          .map((e) => '${e.key}: ${_valueToString(e.value)}')
          .join(', ');
    }
    return '';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    for (final c in _propControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addProperty() {
    final key = 'property_${_propControllers.length + 1}';
    setState(() {
      _propControllers[key] = TextEditingController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.tenant.name}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Basic Information',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Tenant Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _env,
                decoration: const InputDecoration(labelText: 'Environment'),
                items: ['Production', 'Staging']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _env = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _state,
                decoration: const InputDecoration(labelText: 'State'),
                items: ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _state = v);
                },
              ),

              if (_propControllers.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text('Properties',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (final entry in _propControllers.entries) ...[
                  TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: entry.key,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close, size: 16,
                            color: AppColors.error),
                        onPressed: () {
                          setState(() {
                            _propControllers.remove(entry.key);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],

              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addProperty,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Property'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final env = _env == 'Staging'
                ? TenantEnvironment.TENANT_ENVIRONMENT_STAGING
                : TenantEnvironment.TENANT_ENVIRONMENT_PRODUCTION;
            final props = <String, String>{};
            for (final entry in _propControllers.entries) {
              props[entry.key] = entry.value.text.trim();
            }
            Navigator.of(context).pop(_EditTenantResult(
              name: _nameCtl.text.trim(),
              description: _descCtl.text.trim(),
              environment: env,
              state: STATE.values
                  .where((s) => s.name == _state)
                  .firstOrNull,
              properties: props.isNotEmpty ? props : null,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PartitionsTab extends ConsumerWidget {
  const _PartitionsTab({
    required this.tenantId,
    required this.partitions,
  });

  final String tenantId;
  final AsyncValue<List<PartitionObject>> partitions;

  Future<void> _createPartition(
      BuildContext context, WidgetRef ref, List<PartitionObject> existing) async {
    final result = await showCreatePartitionWizard(
      context: context,
      tenantId: tenantId,
      existingPartitions: existing,
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      final partition = await repo.createPartition(
        tenantId: result.tenantId,
        name: result.name,
        parentId: result.parentId,
        description: result.description,
        domain: result.domain,
        properties: result.toPropertiesStruct(),
      );
      // Auto-create default roles
      for (final roleName in ['owner', 'admin', 'member']) {
        try {
          await repo.createPartitionRole(
            partitionId: partition.id,
            name: roleName,
          );
        } catch (_) {}
      }
      ref.invalidate(partitionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partition created with default roles')),
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
    return partitions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allPartitions) {
        final filtered =
            allPartitions.where((p) => p.tenantId == tenantId).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _createPartition(context, ref, filtered),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Partition'),
                  ),
                ],
              ),
            ),
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      Text('No partitions for this tenant',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return ListTile(
                      leading: Icon(Icons.account_tree_outlined,
                          size: 20, color: AppColors.tertiary),
                      title: Text(p.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(p.id,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11)),
                      trailing: StateBadge(p.state),
                      onTap: () => context
                          .go('/services/tenancy/partitions/${p.id}'),
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
