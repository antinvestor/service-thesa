import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/data/profile_repository.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';

/// Permissions tab content for the partition detail page.
///
/// Displays registered service namespaces, their permissions, role bindings,
/// and allows granting/revoking individual permissions to profiles.
class PermissionsTab extends ConsumerWidget {
  const PermissionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNamespaces = ref.watch(serviceNamespacesProvider);

    return asyncNamespaces.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load permissions',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(serviceNamespacesProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (namespaces) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${namespaces.length} service namespace${namespaces.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(serviceNamespacesProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showGrantDialog(context, ref, namespaces),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (namespaces.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No service namespaces registered'),
                    SizedBox(height: 8),
                    Text('Service namespaces appear when services register '
                        'their permissions.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: namespaces.length,
                itemBuilder: (context, index) {
                  final ns = namespaces[index];
                  return _NamespaceCard(namespace: ns);
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showGrantDialog(
    BuildContext context,
    WidgetRef ref,
    List<ServiceNamespace> namespaces,
  ) async {
    final result = await showDialog<_PermissionActionResult>(
      context: context,
      builder: (ctx) => _PermissionActionDialog(
        namespaces: namespaces,
        action: _PermissionAction.grant,
        ref: ref,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.grantPermission(
        namespace: result.namespace,
        permission: result.permission,
        profileId: result.profileId,
      );
      ref.invalidate(serviceNamespacesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Granted ${result.permission} to ${result.profileId}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Namespace Card ─────────────────────────────────────────────────────────

class _NamespaceCard extends ConsumerWidget {
  const _NamespaceCard({required this.namespace});

  final ServiceNamespace namespace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(Icons.extension_outlined,
            size: 20, color: AppColors.tertiary),
        title: Text(namespace.namespace,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${namespace.permissions.length} permission${namespace.permissions.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available permissions
                _SectionLabel('Available Permissions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: namespace.permissions.map((p) {
                    return Chip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      backgroundColor:
                          AppColors.tertiary.withValues(alpha: 0.08),
                      side: BorderSide(
                          color: AppColors.tertiary.withValues(alpha: 0.2)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),

                // Role bindings
                if (namespace.roleBindings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionLabel('Role Bindings'),
                  const SizedBox(height: 8),
                  for (final entry in namespace.roleBindings.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.success
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(entry.key,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: entry.value
                                  .map((p) => Text(p,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontFamily: 'monospace',
                                              fontSize: 11)))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // Action buttons
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showRevokeDialog(context, ref),
                      icon: Icon(Icons.remove_circle_outline,
                          size: 16, color: AppColors.error),
                      label: Text('Revoke',
                          style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showGrantForNamespace(context, ref),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Grant'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGrantForNamespace(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_PermissionActionResult>(
      context: context,
      builder: (ctx) => _PermissionActionDialog(
        namespaces: [namespace],
        action: _PermissionAction.grant,
        ref: ref,
        preselectedNamespace: namespace.namespace,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.grantPermission(
        namespace: result.namespace,
        permission: result.permission,
        profileId: result.profileId,
      );
      ref.invalidate(serviceNamespacesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Granted ${result.permission} to ${result.profileId}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showRevokeDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_PermissionActionResult>(
      context: context,
      builder: (ctx) => _PermissionActionDialog(
        namespaces: [namespace],
        action: _PermissionAction.revoke,
        ref: ref,
        preselectedNamespace: namespace.namespace,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final repo = await ref.read(partitionRepositoryProvider.future);
      await repo.revokePermission(
        namespace: result.namespace,
        permission: result.permission,
        profileId: result.profileId,
      );
      ref.invalidate(serviceNamespacesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Revoked ${result.permission} from ${result.profileId}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted));
  }
}

// ─── Permission Action Dialog ───────────────────────────────────────────────

enum _PermissionAction { grant, revoke }

class _PermissionActionResult {
  const _PermissionActionResult({
    required this.namespace,
    required this.permission,
    required this.profileId,
  });

  final String namespace;
  final String permission;
  final String profileId;
}

class _PermissionActionDialog extends StatefulWidget {
  const _PermissionActionDialog({
    required this.namespaces,
    required this.action,
    required this.ref,
    this.preselectedNamespace,
  });

  final List<ServiceNamespace> namespaces;
  final _PermissionAction action;
  final WidgetRef ref;
  final String? preselectedNamespace;

  @override
  State<_PermissionActionDialog> createState() =>
      _PermissionActionDialogState();
}

class _PermissionActionDialogState extends State<_PermissionActionDialog> {
  final _contactCtl = TextEditingController();
  final _profileIdCtl = TextEditingController();
  String? _profileName;
  bool _searching = false;
  String? _searchError;

  late String? _selectedNamespace;
  String? _selectedPermission;

  List<String> get _availablePermissions {
    if (_selectedNamespace == null) return [];
    final ns = widget.namespaces
        .where((n) => n.namespace == _selectedNamespace)
        .firstOrNull;
    return ns?.permissions ?? [];
  }

  @override
  void initState() {
    super.initState();
    _selectedNamespace = widget.preselectedNamespace ??
        (widget.namespaces.isNotEmpty ? widget.namespaces.first.namespace : null);
  }

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
      _searchError = null;
      _profileName = null;
    });

    try {
      final repo = await widget.ref.read(profileRepositoryProvider.future);
      final profile = await repo.getByContact(contact);
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
        _searchError = 'Profile not found for "$contact"';
        _searching = false;
      });
    }
  }

  bool get _isValid =>
      _selectedNamespace != null &&
      _selectedPermission != null &&
      _profileIdCtl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isGrant = widget.action == _PermissionAction.grant;
    final title = isGrant ? 'Grant Permission' : 'Revoke Permission';
    final actionLabel = isGrant ? 'Grant' : 'Revoke';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Namespace selector
              Text('Service Namespace',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedNamespace,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.extension_outlined, size: 20),
                ),
                items: widget.namespaces
                    .map((ns) => DropdownMenuItem(
                          value: ns.namespace,
                          child: Text(ns.namespace),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedNamespace = v;
                    _selectedPermission = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Permission selector
              Text('Permission',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPermission,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
                items: _availablePermissions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPermission = v),
              ),
              const SizedBox(height: 20),

              // Profile search
              const Divider(),
              const SizedBox(height: 12),
              Text('Search profile by contact (email or phone)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 8),
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Search'),
                  ),
                ],
              ),
              if (_searchError != null) ...[
                const SizedBox(height: 8),
                Text(_searchError!,
                    style:
                        TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              if (_profileName != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.tertiary.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.tertiary.withValues(alpha: 0.15),
                      child: Text(
                        _profileName!.isNotEmpty
                            ? _profileName!
                                .substring(0, 1)
                                .toUpperCase()
                            : '?',
                        style: TextStyle(color: AppColors.tertiary),
                      ),
                    ),
                    title: Text(_profileName!,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
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
                onChanged: (_) => setState(() {}),
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
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_PermissionActionResult(
                    namespace: _selectedNamespace!,
                    permission: _selectedPermission!,
                    profileId: _profileIdCtl.text.trim(),
                  ))
              : null,
          style: isGrant
              ? null
              : ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
