import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/data/profile_repository.dart';
import '../data/partition_providers.dart';
import '../data/partition_repository.dart';

/// Permissions tab content for the partition detail page.
///
/// Shows registered service namespaces and their role bindings. The "Manage
/// Permissions" button opens a full-screen dialog where the admin picks a
/// profile and then toggles individual permissions across all namespaces.
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
                  '${namespaces.length} service namespace${namespaces.length == 1 ? '' : 's'} registered',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onSurfaceMuted),
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
                      onPressed: () => _openPermissionManager(
                          context, ref, namespaces),
                      icon: const Icon(Icons.security, size: 18),
                      label: const Text('Manage Permissions'),
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
                    Text(
                        'Namespaces appear when services start and register '
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
                itemBuilder: (context, index) =>
                    _NamespaceCard(namespace: namespaces[index]),
              ),
            ),
        ],
      ),
    );
  }

  void _openPermissionManager(
    BuildContext context,
    WidgetRef ref,
    List<ServiceNamespaceObject> namespaces,
  ) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PermissionManagerPage(namespaces: namespaces, ref: ref),
    ));
  }
}

// ─── Namespace Card (read-only overview) ────────────────────────────────────

class _NamespaceCard extends StatelessWidget {
  const _NamespaceCard({required this.namespace});
  final ServiceNamespaceObject namespace;

  String get _displayName {
    final name = namespace.namespace.replaceFirst('service_', '');
    return name.isNotEmpty
        ? '${name[0].toUpperCase()}${name.substring(1)}'
        : namespace.namespace;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        leading: Icon(Icons.extension_outlined,
            size: 20, color: AppColors.tertiary),
        title: Text(_displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${namespace.permissions.length} permissions',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('Permissions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: namespace.permissions
                      .map((p) => Chip(
                            label:
                                Text(p, style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                AppColors.tertiary.withValues(alpha: 0.08),
                            side: BorderSide(
                                color: AppColors.tertiary
                                    .withValues(alpha: 0.2)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
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
                              children: entry.value.permissions
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
              ],
            ),
          ),
        ],
      ),
    );
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

// ─── Permission Manager (full-screen multi-select) ──────────────────────────

class _PermissionManagerPage extends StatefulWidget {
  const _PermissionManagerPage({
    required this.namespaces,
    required this.ref,
  });

  final List<ServiceNamespaceObject> namespaces;
  final WidgetRef ref;

  @override
  State<_PermissionManagerPage> createState() =>
      _PermissionManagerPageState();
}

class _PermissionManagerPageState extends State<_PermissionManagerPage> {
  final _contactCtl = TextEditingController();
  final _profileIdCtl = TextEditingController();
  String? _profileName;
  bool _searching = false;
  String? _searchError;
  bool _profileResolved = false;

  /// namespace → set of selected permissions
  final Map<String, Set<String>> _selected = {};
  bool _saving = false;

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
      _profileResolved = false;
    });

    try {
      final repo =
          await widget.ref.read(profileRepositoryProvider.future);
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
        _profileResolved = true;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Profile not found for "$contact"';
        _searching = false;
      });
    }
  }

  void _resolveManualProfile() {
    if (_profileIdCtl.text.trim().isNotEmpty) {
      setState(() {
        _profileResolved = true;
        _profileName = null;
      });
    }
  }

  bool _isSelected(String namespace, String permission) =>
      _selected[namespace]?.contains(permission) ?? false;

  void _toggle(String namespace, String permission) {
    setState(() {
      final set = _selected.putIfAbsent(namespace, () => {});
      if (set.contains(permission)) {
        set.remove(permission);
      } else {
        set.add(permission);
      }
    });
  }

  void _selectAll(String namespace, List<String> permissions) {
    setState(() {
      _selected[namespace] = Set.from(permissions);
    });
  }

  void _deselectAll(String namespace) {
    setState(() {
      _selected[namespace]?.clear();
    });
  }

  int get _totalSelected =>
      _selected.values.fold(0, (sum, s) => sum + s.length);

  Future<void> _applyChanges() async {
    final profileId = _profileIdCtl.text.trim();
    if (profileId.isEmpty || _totalSelected == 0) return;

    setState(() => _saving = true);

    try {
      final repo =
          await widget.ref.read(partitionRepositoryProvider.future);

      for (final entry in _selected.entries) {
        for (final perm in entry.value) {
          await repo.grantPermission(
            namespace: entry.key,
            permission: perm,
            profileId: profileId,
          );
        }
      }

      widget.ref.invalidate(serviceNamespacesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Granted $_totalSelected permissions to $profileId')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _revokeSelected() async {
    final profileId = _profileIdCtl.text.trim();
    if (profileId.isEmpty || _totalSelected == 0) return;

    setState(() => _saving = true);

    try {
      final repo =
          await widget.ref.read(partitionRepositoryProvider.future);

      for (final entry in _selected.entries) {
        for (final perm in entry.value) {
          await repo.revokePermission(
            namespace: entry.key,
            permission: perm,
            profileId: profileId,
          );
        }
      }

      widget.ref.invalidate(serviceNamespacesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Revoked $_totalSelected permissions from $profileId')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Permissions'),
        actions: [
          if (_totalSelected > 0 && _profileResolved) ...[
            TextButton.icon(
              onPressed: _saving ? null : _revokeSelected,
              icon: Icon(Icons.remove_circle_outline,
                  size: 18, color: AppColors.error),
              label: Text('Revoke (${_totalSelected})',
                  style: TextStyle(color: AppColors.error)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _applyChanges,
              icon: const Icon(Icons.check, size: 18),
              label: Text('Grant (${_totalSelected})'),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileSection(),
                if (_profileResolved) ...[
                  const Divider(height: 1),
                  Expanded(child: _buildPermissionsGrid()),
                ],
              ],
            ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Profile',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contactCtl,
                  decoration: const InputDecoration(
                    labelText: 'Search by contact (email or phone)',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
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
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _profileIdCtl,
                  decoration: const InputDecoration(
                    labelText: 'Or enter Profile ID directly',
                    prefixIcon: Icon(Icons.person_outlined, size: 20),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _profileResolved = false),
                  onSubmitted: (_) => _resolveManualProfile(),
                ),
              ),
              const SizedBox(width: 8),
              if (!_profileResolved && _profileIdCtl.text.trim().isNotEmpty)
                OutlinedButton(
                  onPressed: _resolveManualProfile,
                  child: const Text('Use'),
                ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 8),
            Text(_searchError!,
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          if (_profileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppColors.tertiary.withValues(alpha: 0.15),
                  child: Text(
                    _profileName!.isNotEmpty
                        ? _profileName![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: AppColors.tertiary, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_profileName!,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Text(_profileIdCtl.text,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionsGrid() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.namespaces.length,
      itemBuilder: (context, index) {
        final ns = widget.namespaces[index];
        final nsName = ns.namespace;
        final displayName = nsName.replaceFirst('service_', '');
        final title = displayName.isNotEmpty
            ? '${displayName[0].toUpperCase()}${displayName.substring(1)}'
            : nsName;
        final selectedCount = _selected[nsName]?.length ?? 0;
        final allSelected = selectedCount == ns.permissions.length &&
            ns.permissions.isNotEmpty;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.extension_outlined,
                        size: 18, color: AppColors.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    TextButton(
                      onPressed: () => allSelected
                          ? _deselectAll(nsName)
                          : _selectAll(nsName, ns.permissions.toList()),
                      child:
                          Text(allSelected ? 'Deselect All' : 'Select All'),
                    ),
                    if (selectedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$selectedCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ns.permissions.map((perm) {
                    final selected = _isSelected(nsName, perm);
                    return FilterChip(
                      label: Text(perm,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : null,
                          )),
                      selected: selected,
                      onSelected: (_) => _toggle(nsName, perm),
                      selectedColor: AppColors.tertiary,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.tertiary
                            : AppColors.border,
                      ),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
