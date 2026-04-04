import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';
import '../widgets/partition_tree.dart';

class PartitionsPage extends ConsumerWidget {
  const PartitionsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  Future<void> _showCreatePartitionDialog(
    BuildContext context,
    WidgetRef ref,
    List<PartitionObject> partitions,
  ) async {
    final tenants = await ref.read(tenantsProvider.future);
    if (!context.mounted) return;

    final result = await showDialog<_CreatePartitionResult>(
      context: context,
      builder: (context) => _CreatePartitionDialog(
        tenants: tenants,
        partitions: partitions,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.createPartition(
        tenantId: result.tenantId,
        name: result.name,
        parentId: result.parentId,
        description: result.description,
      );
      ref.invalidate(partitionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partition created')),
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
    final asyncPartitions = ref.watch(partitionsProvider);

    return asyncPartitions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load partitions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(partitionsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (partitions) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Partitions',
              breadcrumbs: ['Services', service.label, 'Partitions'],
              actions: [
                ElevatedButton.icon(
                  onPressed: () =>
                      _showCreatePartitionDialog(context, ref, partitions),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Partition'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search partitions...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filter'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(partitionsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PartitionTreeView(partitions: partitions),
          ],
        ),
      ),
    );
  }
}

// ── Dialog result ───────────────────────────────────────────────────────────

class _CreatePartitionResult {
  const _CreatePartitionResult({
    required this.tenantId,
    required this.name,
    this.parentId,
    this.description = '',
  });

  final String tenantId;
  final String name;
  final String? parentId;
  final String description;
}

// ── Create Partition Dialog ─────────────────────────────────────────────────

class _CreatePartitionDialog extends StatefulWidget {
  const _CreatePartitionDialog({
    required this.tenants,
    required this.partitions,
  });

  final List<TenantObject> tenants;
  final List<PartitionObject> partitions;

  @override
  State<_CreatePartitionDialog> createState() => _CreatePartitionDialogState();
}

class _CreatePartitionDialogState extends State<_CreatePartitionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedTenantId;
  String? _selectedParentId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Partition'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedTenantId,
                  decoration: const InputDecoration(
                    labelText: 'Tenant',
                    hintText: 'Select a tenant...',
                  ),
                  items: widget.tenants
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTenantId = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Tenant is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Partition Name',
                    hintText: 'Enter partition name...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                Autocomplete<PartitionObject>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return widget.partitions;
                    }
                    final query = textEditingValue.text.toLowerCase();
                    return widget.partitions.where(
                        (p) => p.name.toLowerCase().contains(query));
                  },
                  displayStringForOption: (p) => p.name,
                  onSelected: (p) =>
                      setState(() => _selectedParentId = p.id),
                  fieldViewBuilder: (context, textController, focusNode,
                      onFieldSubmitted) {
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Parent Partition (optional)',
                        hintText: 'Type to search...',
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  textController.clear();
                                  setState(() => _selectedParentId = null);
                                },
                              )
                            : const Icon(Icons.search, size: 18),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter description...',
                    alignLabelWithHint: true,
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
            Navigator.of(context).pop(_CreatePartitionResult(
              tenantId: _selectedTenantId!,
              name: _nameController.text.trim(),
              parentId: _selectedParentId,
              description: _descriptionController.text.trim(),
            ));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
