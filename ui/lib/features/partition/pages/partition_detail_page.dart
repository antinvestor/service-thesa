import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/tenant_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/widgets/profile_badge.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/state_badge.dart';

/// Detail page for a single partition at
/// /services/tenancy/partitions/:partitionId.
///
/// Tabs: Overview | Roles | Access | Service Accounts | Clients
class PartitionDetailPage extends ConsumerWidget {
  const PartitionDetailPage({super.key, required this.partitionId});

  final String partitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPartition = ref.watch(partitionDetailProvider(partitionId));

    return asyncPartition.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load partition',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(partitionDetailProvider(partitionId)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (partition) => _PartitionDetailContent(
        partition: partition,
        partitionId: partitionId,
      ),
    );
  }
}

class _PartitionDetailContent extends ConsumerWidget {
  const _PartitionDetailContent({
    required this.partition,
    required this.partitionId,
  });

  final PartitionObject partition;
  final String partitionId;

  /// Extract a property value from the partition's properties Struct.
  String _prop(String key) {
    if (!partition.hasProperties()) return '';
    final fields = partition.properties.fields;
    if (!fields.containsKey(key)) return '';
    final v = fields[key]!;
    if (v.hasStringValue()) return v.stringValue;
    if (v.hasBoolValue()) return v.boolValue.toString();
    return '';
  }

  String _nestedProp(String parent, String child) {
    if (!partition.hasProperties()) return '';
    final fields = partition.properties.fields;
    if (!fields.containsKey(parent)) return '';
    final v = fields[parent]!;
    if (!v.hasStructValue()) return '';
    final nested = v.structValue.fields;
    if (!nested.containsKey(child)) return '';
    final cv = nested[child]!;
    if (cv.hasStringValue()) return cv.stringValue;
    return '';
  }

  bool _boolProp(String key, {bool defaultValue = true}) {
    if (!partition.hasProperties()) return defaultValue;
    final fields = partition.properties.fields;
    if (!fields.containsKey(key)) return defaultValue;
    final v = fields[key]!;
    if (v.hasBoolValue()) return v.boolValue;
    if (v.hasStringValue()) return v.stringValue == 'true';
    return defaultValue;
  }

  Future<void> _editPartition(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_EditPartitionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditPartitionDialog(
        partition: partition,
        allowAutoAccess: _boolProp('allow_auto_access'),
        defaultRole: _prop('default_role'),
        supportEmail: _nestedProp('support_contacts', 'email'),
        supportPhone: _nestedProp('support_contacts', 'msisdn'),
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.updatePartition(
        id: partitionId,
        name: result.name,
        description: result.description,
        domain: result.domain,
        state: result.state,
        properties: result.toPropertiesStruct(),
      );
      ref.invalidate(partitionDetailProvider(partitionId));
      ref.invalidate(partitionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partition updated')),
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

  void _setAsActiveContext(WidgetRef ref) {
    final jwt = ref.read(jwtTenantContextProvider);
    final jwtCtx = jwt.whenOrNull(data: (c) => c) ??
        const TenantContext(tenantId: '', partitionId: '');
    ref.read(activeTenantProvider.notifier).set(
      jwtCtx.copyWith(
        tenantId: partition.tenantId,
        partitionId: partition.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveCtx = ref.watch(effectiveTenantProvider);
    final isActiveContext = effectiveCtx.partitionId == partitionId;

    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active context banner
          if (isActiveContext)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: AppColors.success.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Active Context',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(
                      'You are working within this partition',
                      style: TextStyle(
                          color: AppColors.success, fontSize: 12)),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: partition.name,
              breadcrumbs: [
                'Services',
                'Tenancy Service',
                'Partitions',
                partition.name,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/services/tenancy/partitions'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editPartition(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                if (!isActiveContext)
                  ElevatedButton.icon(
                    onPressed: () {
                      _setAsActiveContext(ref);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Switched context to ${partition.name}')),
                      );
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Set as Active'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StateBadge(partition.state),
                SelectableText('ID: ${partition.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (partition.hasCreatedAt())
                  Text(
                      'Created: ${DateFormat.yMMMd().format(partition.createdAt.toDateTime())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Roles'),
              Tab(text: 'Access'),
              Tab(text: 'Service Accounts'),
              Tab(text: 'Clients'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(partition: partition),
                _RolesTab(partitionId: partitionId),
                _AccessTab(partitionId: partitionId),
                _ServiceAccountsTab(partitionId: partitionId),
                _ClientsTab(partitionId: partitionId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.partition});

  final PartitionObject partition;

  String _prop(String key) {
    if (!partition.hasProperties()) return '';
    final fields = partition.properties.fields;
    if (!fields.containsKey(key)) return '';
    final v = fields[key]!;
    if (v.hasStringValue()) return v.stringValue;
    if (v.hasBoolValue()) return v.boolValue.toString();
    return '';
  }

  String _nestedProp(String parent, String child) {
    if (!partition.hasProperties()) return '';
    final fields = partition.properties.fields;
    if (!fields.containsKey(parent)) return '';
    final v = fields[parent]!;
    if (!v.hasStructValue()) return '';
    final nested = v.structValue.fields;
    if (!nested.containsKey(child)) return '';
    final cv = nested[child]!;
    if (cv.hasStringValue()) return cv.stringValue;
    return '';
  }

  bool _boolProp(String key, {bool defaultValue = true}) {
    if (!partition.hasProperties()) return defaultValue;
    final fields = partition.properties.fields;
    if (!fields.containsKey(key)) return defaultValue;
    final v = fields[key]!;
    if (v.hasBoolValue()) return v.boolValue;
    if (v.hasStringValue()) return v.stringValue == 'true';
    return defaultValue;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTenant = ref.watch(tenantDetailProvider(partition.tenantId));
    final asyncPartitions = ref.watch(partitionsProvider);

    final allowAutoAccess = _boolProp('allow_auto_access');
    final defaultRole = _prop('default_role');
    final supportEmail = _nestedProp('support_contacts', 'email');
    final supportPhone = _nestedProp('support_contacts', 'msisdn');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Details + Configuration side by side ──
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final cards = [
              // Partition details
              _buildCard(
                context,
                title: 'Partition Details',
                icon: Icons.info_outline,
                child: Column(
                  children: [
                    _DetailRow(label: 'Name', value: partition.name),
                    _DetailRow(
                        label: 'Description',
                        value: partition.description.isNotEmpty
                            ? partition.description
                            : '—'),
                    if (partition.domain.isNotEmpty)
                      _DetailRow(
                        label: 'Domain',
                        value: partition.domain,
                        icon: Icons.language,
                      ),
                    _DetailRow(label: 'State', value: partition.state.name),
                    if (partition.hasCreatedAt())
                      _DetailRow(
                        label: 'Created',
                        value: DateFormat.yMMMd()
                            .format(partition.createdAt.toDateTime()),
                      ),
                  ],
                ),
              ),
              // Configuration card
              _buildCard(
                context,
                title: 'Configuration',
                icon: Icons.settings_outlined,
                child: Column(
                  children: [
                    _BoolRow(
                      label: 'Auto Access',
                      value: allowAutoAccess,
                      description: allowAutoAccess
                          ? 'Users get access automatically on login'
                          : 'Users must be granted access explicitly',
                    ),
                    _DetailRow(
                      label: 'Default Role',
                      value: defaultRole.isNotEmpty ? defaultRole : '—',
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),
              ),
            ];
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              );
            }
            return Column(children: [
              cards[0],
              const SizedBox(height: 16),
              cards[1],
            ]);
          }),
          const SizedBox(height: 16),

          // ── Support Contacts card ──
          if (supportEmail.isNotEmpty || supportPhone.isNotEmpty)
            _buildCard(
              context,
              title: 'Support Contacts',
              icon: Icons.support_agent_outlined,
              child: Column(
                children: [
                  if (supportEmail.isNotEmpty)
                    _DetailRow(
                      label: 'Email',
                      value: supportEmail,
                      icon: Icons.email_outlined,
                    ),
                  if (supportPhone.isNotEmpty)
                    _DetailRow(
                      label: 'Phone',
                      value: supportPhone,
                      icon: Icons.phone_outlined,
                    ),
                ],
              ),
            ),
          if (supportEmail.isNotEmpty || supportPhone.isNotEmpty)
            const SizedBox(height: 16),

          // ── Tenant link ──
          _buildCard(
            context,
            title: 'Tenant',
            icon: Icons.business_outlined,
            child: asyncTenant.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (_, __) => _DetailRow(
                  label: 'Tenant ID', value: partition.tenantId),
              data: (tenant) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.business_outlined, color: AppColors.tertiary),
                title: Text(tenant.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(tenant.id,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () =>
                    context.go('/services/tenancy/tenants/${tenant.id}'),
              ),
            ),
          ),

          // ── Parent partition link ──
          if (partition.hasParentId()) ...[
            const SizedBox(height: 16),
            _buildCard(
              context,
              title: 'Parent Partition',
              icon: Icons.account_tree_outlined,
              child: asyncPartitions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                      child: SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (_, __) => _DetailRow(
                    label: 'Parent ID', value: partition.parentId),
                data: (partitions) {
                  final parent = partitions
                      .where((p) => p.id == partition.parentId)
                      .firstOrNull;
                  if (parent == null) {
                    return _DetailRow(
                        label: 'Parent ID', value: partition.parentId);
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.account_tree_outlined,
                        color: AppColors.tertiary),
                    title: Text(parent.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(parent.id,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context
                        .go('/services/tenancy/partitions/${parent.id}'),
                  );
                },
              ),
            ),
          ],

          // ── Related partitions ──
          const SizedBox(height: 16),
          asyncPartitions.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (allPartitions) {
              final children = allPartitions
                  .where((p) => p.parentId == partition.id)
                  .toList();
              final siblings = allPartitions
                  .where((p) =>
                      p.tenantId == partition.tenantId &&
                      p.id != partition.id &&
                      p.parentId != partition.id)
                  .toList();
              if (children.isEmpty && siblings.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildCard(
                context,
                title: 'Related Partitions',
                icon: Icons.account_tree_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (children.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Child Partitions',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceMuted)),
                      ),
                      for (final child in children)
                        _PartitionLink(partition: child),
                      if (siblings.isNotEmpty) const Divider(height: 20),
                    ],
                    if (siblings.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Other Partitions',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceMuted)),
                      ),
                      for (final sib in siblings)
                        _PartitionLink(partition: sib),
                    ],
                  ],
                ),
              );
            },
          ),

          // ── Raw Properties (for advanced users) ──
          if (partition.hasProperties() &&
              partition.properties.fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              context,
              title: 'All Properties',
              icon: Icons.data_object,
              child: Column(
                children: [
                  for (final entry in partition.properties.fields.entries)
                    _DetailRow(
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.icon});

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
            width: 110,
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

class _BoolRow extends StatelessWidget {
  const _BoolRow(
      {required this.label, required this.value, this.description});

  final String label;
  final bool value;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: value ? AppColors.success : AppColors.onSurfaceMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value ? 'Enabled' : 'Disabled',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (description != null)
                  Text(description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11, color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartitionLink extends StatelessWidget {
  const _PartitionLink({required this.partition});
  final PartitionObject partition;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.account_tree_outlined,
          size: 18, color: AppColors.tertiary),
      title: Text(partition.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(partition.id,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      trailing: StateBadge(partition.state),
      onTap: () =>
          context.go('/services/tenancy/partitions/${partition.id}'),
    );
  }
}

// ─── Edit Partition Dialog ───────────────────────────────────────────────────

class _EditPartitionResult {
  const _EditPartitionResult({
    required this.name,
    required this.description,
    this.domain,
    this.state,
    required this.allowAutoAccess,
    this.defaultRole = '',
    this.supportEmail = '',
    this.supportPhone = '',
  });

  final String name;
  final String description;
  final String? domain;
  final STATE? state;
  final bool allowAutoAccess;
  final String defaultRole;
  final String supportEmail;
  final String supportPhone;

  Struct? toPropertiesStruct() {
    final fields = <String, Value>{};
    fields['allow_auto_access'] = Value(boolValue: allowAutoAccess);
    if (defaultRole.isNotEmpty) {
      fields['default_role'] = Value(stringValue: defaultRole);
    }
    final contactFields = <String, Value>{};
    if (supportEmail.isNotEmpty) {
      contactFields['email'] = Value(stringValue: supportEmail);
    }
    if (supportPhone.isNotEmpty) {
      contactFields['msisdn'] = Value(stringValue: supportPhone);
    }
    if (contactFields.isNotEmpty) {
      fields['support_contacts'] =
          Value(structValue: Struct(fields: contactFields));
    }
    if (fields.isEmpty) return null;
    return Struct(fields: fields);
  }
}

class _EditPartitionDialog extends StatefulWidget {
  const _EditPartitionDialog({
    required this.partition,
    required this.allowAutoAccess,
    required this.defaultRole,
    required this.supportEmail,
    required this.supportPhone,
  });

  final PartitionObject partition;
  final bool allowAutoAccess;
  final String defaultRole;
  final String supportEmail;
  final String supportPhone;

  @override
  State<_EditPartitionDialog> createState() => _EditPartitionDialogState();
}

class _EditPartitionDialogState extends State<_EditPartitionDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _domainCtl;
  late final TextEditingController _roleCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;
  late String _state;
  late bool _autoAccess;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.partition.name);
    _descCtl = TextEditingController(text: widget.partition.description);
    _domainCtl = TextEditingController(text: widget.partition.domain);
    _roleCtl = TextEditingController(text: widget.defaultRole);
    _emailCtl = TextEditingController(text: widget.supportEmail);
    _phoneCtl = TextEditingController(text: widget.supportPhone);
    _state = widget.partition.state.name;
    _autoAccess = widget.allowAutoAccess;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _domainCtl.dispose();
    _roleCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.partition.name}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basic ──
              Text('Basic Information',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Partition Name'),
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
              TextField(
                controller: _domainCtl,
                decoration: const InputDecoration(
                  labelText: 'Custom Domain',
                  hintText: 'e.g. app.example.com',
                  prefixIcon: Icon(Icons.language, size: 20),
                ),
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

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // ── Configuration ──
              Text('Configuration',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Allow Auto Access'),
                subtitle: const Text(
                  'Grant access to users automatically on login',
                  style: TextStyle(fontSize: 12),
                ),
                value: _autoAccess,
                onChanged: (v) => setState(() => _autoAccess = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _roleCtl,
                decoration: const InputDecoration(
                  labelText: 'Default Role',
                  hintText: 'e.g. user, member',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // ── Support ──
              Text('Support Contacts',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtl,
                decoration: const InputDecoration(
                  labelText: 'Support Email',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtl,
                decoration: const InputDecoration(
                  labelText: 'Support Phone',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
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
            Navigator.of(context).pop(_EditPartitionResult(
              name: _nameCtl.text.trim(),
              description: _descCtl.text.trim(),
              domain: _domainCtl.text.trim().isNotEmpty
                  ? _domainCtl.text.trim()
                  : null,
              state: STATE.values
                  .where((s) => s.name == _state)
                  .firstOrNull,
              allowAutoAccess: _autoAccess,
              defaultRole: _roleCtl.text.trim(),
              supportEmail: _emailCtl.text.trim(),
              supportPhone: _phoneCtl.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Roles Tab ────────────────────────────────────────────────────────────────

class _RolesTab extends ConsumerWidget {
  const _RolesTab({required this.partitionId});

  final String partitionId;

  Future<void> _createRole(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'New Role',
      saveLabel: 'Create',
      fields: [
        const DialogField(key: 'name', label: 'Role Name'),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createPartitionRole(
        partitionId: partitionId,
        name: values['name'] ?? '',
      );
      ref.invalidate(partitionRolesForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteRole(
      BuildContext context, WidgetRef ref, PartitionRoleObject role) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Role',
      message: 'Remove role "${role.name}"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removePartitionRole(role.id);
      ref.invalidate(partitionRolesForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles =
        ref.watch(partitionRolesForPartitionProvider(partitionId));

    return asyncRoles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Failed to load roles',
        detail: error.toString(),
        onRetry: () =>
            ref.invalidate(partitionRolesForPartitionProvider(partitionId)),
      ),
      data: (roles) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _createRole(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Role'),
                ),
              ],
            ),
          ),
          if (roles.isEmpty)
            Expanded(
              child: _PlaceholderTab(
                icon: Icons.shield_outlined,
                title: 'No roles defined',
                subtitle: 'Create roles to control access to this partition.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: roles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  return ListTile(
                    leading: Icon(Icons.shield_outlined,
                        size: 20, color: AppColors.tertiary),
                    title: Text(role.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(role.id,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StateBadge(role.state),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () => _deleteRole(context, ref, role),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Access Tab ───────────────────────────────────────────────────────────────

class _AccessTab extends ConsumerWidget {
  const _AccessTab({required this.partitionId});

  final String partitionId;

  Future<void> _createAccess(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _GrantAccessDialog(ref: ref),
    );
    if (result == null || result.isEmpty || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createAccess(
        partitionId: partitionId,
        profileId: result,
      );
      ref.invalidate(accessForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access granted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeAccess(
      BuildContext context, WidgetRef ref, AccessObject access) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Access',
      message: 'Remove access for profile ${access.profileId}?',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeAccess(access.id);
      ref.invalidate(accessForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccess = ref.watch(accessForPartitionProvider(partitionId));

    return asyncAccess.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Failed to load access grants',
        detail: error.toString(),
        onRetry: () =>
            ref.invalidate(accessForPartitionProvider(partitionId)),
      ),
      data: (access) {

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _createAccess(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Grant Access'),
                  ),
                ],
              ),
            ),
            if (access.isEmpty)
              const Expanded(
                child: _PlaceholderTab(
                  icon: Icons.security_outlined,
                  title: 'No access grants',
                  subtitle:
                      'Grant access to allow profiles to use this partition.',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: access.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = access[index];
                    return ExpansionTile(
                      leading: null,
                      title: ProfileBadge(profileId: a.profileId),
                      subtitle: Text('Access: ${a.id}',
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.onSurfaceMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StateBadge(a.state),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: AppColors.error),
                            tooltip: 'Remove access',
                            onPressed: () => _removeAccess(context, ref, a),
                          ),
                        ],
                      ),
                      children: [
                        _AccessRolesSection(
                          accessId: a.id,
                          partitionId: partitionId,
                        ),
                      ],
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

/// Inline section showing access roles with add/remove.
class _AccessRolesSection extends ConsumerWidget {
  const _AccessRolesSection({
    required this.accessId,
    required this.partitionId,
  });

  final String accessId;
  final String partitionId;

  Future<void> _addRole(BuildContext context, WidgetRef ref,
      List<PartitionRoleObject> availableRoles) async {
    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No partition roles available. Create roles first.')),
      );
      return;
    }

    final values = await showEditDialog(
      context: context,
      title: 'Assign Role',
      saveLabel: 'Assign',
      fields: [
        DialogField(
          key: 'roleId',
          label: 'Partition Role',
          type: DialogFieldType.dropdown,
          options: availableRoles.map((r) => '${r.name} (${r.id})').toList(),
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    final selectedText = values['roleId'] ?? '';
    final selectedRole = availableRoles.where((r) =>
        '${r.name} (${r.id})' == selectedText).firstOrNull;
    if (selectedRole == null) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createAccessRole(
        accessId: accessId,
        partitionRoleId: selectedRole.id,
      );
      ref.invalidate(accessRolesForAccessProvider(accessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role assigned')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeRole(
      BuildContext context, WidgetRef ref, AccessRoleObject role) async {
    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeAccessRole(role.id);
      ref.invalidate(accessRolesForAccessProvider(accessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles = ref.watch(accessRolesForAccessProvider(accessId));
    final asyncPartitionRoles =
        ref.watch(partitionRolesForPartitionProvider(partitionId));

    return asyncRoles.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error',
            style: TextStyle(color: AppColors.error, fontSize: 12)),
      ),
      data: (roles) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Assigned Roles',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final available =
                        asyncPartitionRoles.value ?? [];
                    _addRole(context, ref, available);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Assign Role'),
                ),
              ],
            ),
            if (roles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No roles assigned',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13)),
              )
            else
              for (final role in roles)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.badge_outlined,
                      size: 16, color: AppColors.tertiary),
                  title: Text(
                    role.hasRole() ? role.role.name : role.id,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 16, color: AppColors.error),
                    tooltip: 'Remove role',
                    onPressed: () => _removeRole(context, ref, role),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

// ─── Service Accounts Tab ─────────────────────────────────────────────────────

class _ServiceAccountsTab extends ConsumerWidget {
  const _ServiceAccountsTab({required this.partitionId});

  final String partitionId;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'New Service Account',
      saveLabel: 'Create',
      fields: const [
        DialogField(key: 'name', label: 'Name', hint: 'e.g. my-service'),
        DialogField(
          key: 'type',
          label: 'Type',
          type: DialogFieldType.dropdown,
          options: ['internal', 'external'],
          initialValue: 'internal',
        ),
        DialogField(
          key: 'audiences',
          label: 'Audiences (comma-separated)',
          hint: 'e.g. service_profile,service_notification',
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final audienceStr = values['audiences'] ?? '';
      final audiences = audienceStr.isNotEmpty
          ? audienceStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : null;
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createServiceAccount(
        partitionId: partitionId,
        name: values['name'] ?? '',
        type: values['type'] ?? 'internal',
        audiences: audiences,
      );
      ref.invalidate(serviceAccountsForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Service account created')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, ServiceAccountObject sa) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Service Account',
      message: 'Remove "${sa.profileId}"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeServiceAccount(sa.id);
      ref.invalidate(serviceAccountsForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Service account removed')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSAs = ref.watch(serviceAccountsForPartitionProvider(partitionId));

    return asyncSAs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Failed to load service accounts',
        detail: error.toString(),
        onRetry: () =>
            ref.invalidate(serviceAccountsForPartitionProvider(partitionId)),
      ),
      data: (accounts) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Service Account'),
                ),
              ],
            ),
          ),
          if (accounts.isEmpty)
            const Expanded(
              child: _PlaceholderTab(
                icon: Icons.engineering_outlined,
                title: 'No service accounts',
                subtitle: 'Create service accounts for machine-to-machine access.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sa = accounts[index];
                  return ExpansionTile(
                    leading: Icon(Icons.engineering_outlined,
                        size: 20, color: AppColors.tertiary),
                    title: sa.profileId.isNotEmpty
                        ? ProfileBadge(
                            profileId: sa.profileId, compact: true)
                        : Text(sa.id,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Type: ${sa.type}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StateBadge(sa.state),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () => _remove(context, ref, sa),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SADetailRow('ID', sa.id),
                            if (sa.profileId.isNotEmpty)
                              _SADetailRow('Profile ID', sa.profileId),
                            if (sa.clientId.isNotEmpty)
                              _SADetailRow('Client ID', sa.clientId),
                            _SADetailRow('Type', sa.type),
                            if (sa.audiences.isNotEmpty)
                              _SADetailRow('Audiences', sa.audiences.join(', ')),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Clients Tab ──────────────────────────────────────────────────────────────

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab({required this.partitionId});

  final String partitionId;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreateClientResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateClientDialog(),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createClient(
        name: result.name,
        partitionId: partitionId,
        type: result.type,
        scopes: result.scopes,
        grantTypes: splitCommaSeparated(result.grantTypes),
        responseTypes: splitCommaSeparated(result.responseTypes),
        redirectUris: splitCommaSeparated(result.redirectUris),
        audiences: splitCommaSeparated(result.audiences),
      );
      ref.invalidate(clientsForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Client created')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, ClientObject client) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Client',
      message: 'Remove client "${client.name}"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.removeClient(client.id);
      ref.invalidate(clientsForPartitionProvider(partitionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Client removed')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClients = ref.watch(clientsForPartitionProvider(partitionId));

    return asyncClients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Failed to load clients',
        detail: error.toString(),
        onRetry: () =>
            ref.invalidate(clientsForPartitionProvider(partitionId)),
      ),
      data: (clients) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Client'),
                ),
              ],
            ),
          ),
          if (clients.isEmpty)
            const Expanded(
              child: _PlaceholderTab(
                icon: Icons.key_outlined,
                title: 'No OAuth2 clients',
                subtitle: 'Create clients for application authentication.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return ExpansionTile(
                    leading: Icon(Icons.key_outlined,
                        size: 20, color: AppColors.tertiary),
                    title: Text(client.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Type: ${client.type} · Scopes: ${client.scopes}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StateBadge(client.state),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () => _remove(context, ref, client),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SADetailRow('Client ID', client.clientId),
                            _SADetailRow('Type', client.type),
                            _SADetailRow('Scopes', client.scopes),
                            if (client.grantTypes.isNotEmpty)
                              _SADetailRow('Grant Types', client.grantTypes.join(', ')),
                            if (client.responseTypes.isNotEmpty)
                              _SADetailRow('Response Types', client.responseTypes.join(', ')),
                            if (client.redirectUris.isNotEmpty)
                              _SADetailRow('Redirect URIs', client.redirectUris.join('\n')),
                            if (client.audiences.isNotEmpty)
                              _SADetailRow('Audiences', client.audiences.join(', ')),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

// ─── Grant Access Dialog ─────────────────────────────────────────────────────

class _GrantAccessDialog extends StatefulWidget {
  const _GrantAccessDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_GrantAccessDialog> createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<_GrantAccessDialog> {
  final _contactCtl = TextEditingController();
  final _profileIdCtl = TextEditingController();
  String? _profileName;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _contactCtl.dispose();
    _profileIdCtl.dispose();
    super.dispose();
  }

  Future<void> _searchProfile() async {
    final contact = _contactCtl.text.trim();
    if (contact.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _profileName = null;
    });

    try {
      final repo = await widget.ref.read(profileRepositoryProvider.future);
      final profile = await repo.getByContact(contact);
      // Extract display name
      final nameField = profile.properties.fields['name'];
      final name = (nameField != null && nameField.hasStringValue())
          ? nameField.stringValue
          : profile.contacts.isNotEmpty
              ? profile.contacts.first.detail
              : profile.id;
      setState(() {
        _profileIdCtl.text = profile.id;
        _profileName = name;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Profile not found for "$contact"';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grant Access'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search by contact (email or phone)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contactCtl,
                    decoration: const InputDecoration(
                      labelText: 'Contact',
                      hintText: 'e.g. user@example.com or +256...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onSubmitted: (_) => _searchProfile(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _searchProfile,
                  child: _searching
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Search'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            if (_profileName != null) ...[
              const SizedBox(height: 12),
              Card(
                color: AppColors.tertiary.withValues(alpha: 0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.tertiary.withValues(alpha: 0.15),
                    child: Text(
                      _profileName!.isNotEmpty
                          ? _profileName!.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(color: AppColors.tertiary),
                    ),
                  ),
                  title: Text(_profileName!,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_profileIdCtl.text,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Or enter Profile ID directly',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 8),
            TextField(
              controller: _profileIdCtl,
              decoration: const InputDecoration(
                labelText: 'Profile ID',
                hintText: 'Paste profile ID...',
                prefixIcon: Icon(Icons.person_outlined, size: 20),
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
        ElevatedButton(
          onPressed: _profileIdCtl.text.trim().isNotEmpty
              ? () => Navigator.of(context).pop(_profileIdCtl.text.trim())
              : null,
          child: const Text('Grant Access'),
        ),
      ],
    );
  }
}

// ─── Shared Detail Row ───────────────────────────────────────────────────────

// ─── Create Client Dialog with Validation ────────────────────────────────────

class _CreateClientResult {
  const _CreateClientResult({
    required this.name,
    required this.type,
    required this.scopes,
    this.grantTypes,
    this.responseTypes,
    this.redirectUris,
    this.audiences,
  });

  final String name;
  final String type;
  final String scopes;
  final String? grantTypes;
  final String? responseTypes;
  final String? redirectUris;
  final String? audiences;
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _scopesCtl = TextEditingController(text: 'openid');
  final _grantTypesCtl = TextEditingController();
  final _responseTypesCtl = TextEditingController();
  final _redirectUrisCtl = TextEditingController();
  final _audiencesCtl = TextEditingController();
  String _type = 'public';

  @override
  void dispose() {
    _nameCtl.dispose();
    _scopesCtl.dispose();
    _grantTypesCtl.dispose();
    _responseTypesCtl.dispose();
    _redirectUrisCtl.dispose();
    _audiencesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New OAuth2 Client'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Client Name *',
                    hintText: 'e.g. My Web App',
                  ),
                  validator: validateClientName,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['public', 'confidential', 'internal']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _scopesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Scopes *',
                    hintText: 'e.g. openid offline_access profile',
                    helperText: 'Space-separated',
                  ),
                  validator: validateScopes,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _grantTypesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Grant Types',
                    hintText: 'e.g. authorization_code,refresh_token',
                    helperText:
                        'Valid: authorization_code, client_credentials, refresh_token, implicit',
                  ),
                  validator: validateGrantTypes,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _responseTypesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Response Types',
                    hintText: 'e.g. code,token',
                    helperText: 'Valid: code, token, id_token',
                  ),
                  validator: validateResponseTypes,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _redirectUrisCtl,
                  decoration: const InputDecoration(
                    labelText: 'Redirect URIs',
                    hintText:
                        'e.g. https://app.example.com/callback,myapp://auth',
                    helperText:
                        'Comma-separated. Must have scheme (https:// or custom://)',
                  ),
                  maxLines: 2,
                  validator: validateRedirectUris,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _audiencesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Audiences',
                    hintText: 'e.g. service_profile,service_notification',
                    helperText: 'Comma-separated service names',
                  ),
                ),
              ],
            ),
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
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_CreateClientResult(
              name: _nameCtl.text.trim(),
              type: _type,
              scopes: _scopesCtl.text.trim(),
              grantTypes: _grantTypesCtl.text.trim().isNotEmpty
                  ? _grantTypesCtl.text.trim()
                  : null,
              responseTypes: _responseTypesCtl.text.trim().isNotEmpty
                  ? _responseTypesCtl.text.trim()
                  : null,
              redirectUris: _redirectUrisCtl.text.trim().isNotEmpty
                  ? _redirectUrisCtl.text.trim()
                  : null,
              audiences: _audiencesCtl.text.trim().isNotEmpty
                  ? _audiencesCtl.text.trim()
                  : null,
            ));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _SADetailRow extends StatelessWidget {
  const _SADetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
            child: SelectableText(value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 36, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(detail,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ], // children
      ), // Column
    ); // Center / return
  }
}
