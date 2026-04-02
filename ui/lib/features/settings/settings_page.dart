import 'dart:async';

import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/edit_dialog.dart';
import '../../core/widgets/page_header.dart';
import 'data/settings_providers.dart';
import 'data/settings_repository.dart';

/// Hierarchical settings browser with module grouping, search, inline editing.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _selectedModule;
  String _searchQuery = '';
  Timer? _debounce;
  String? _expandedId;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = query.trim());
    });
  }

  Future<void> _createSetting() async {
    final values = await showEditDialog(
      context: context,
      title: 'New Setting',
      saveLabel: 'Create',
      fields: [
        const DialogField(key: 'name', label: 'Name', hint: 'e.g. max_retries'),
        const DialogField(
          key: 'value',
          label: 'Value',
          hint: 'String or JSON',
          type: DialogFieldType.textarea,
          maxLines: 3,
        ),
        DialogField(
          key: 'module',
          label: 'Module',
          hint: 'e.g. payment',
          initialValue:
              _selectedModule != null && _selectedModule != '(default)'
                  ? _selectedModule!
                  : '',
        ),
        const DialogField(
            key: 'object', label: 'Object Type', hint: 'e.g. tenant'),
        const DialogField(key: 'objectId', label: 'Object ID'),
        const DialogField(key: 'lang', label: 'Language', hint: 'e.g. en'),
      ],
    );
    if (values == null || !mounted) return;

    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.set(
        name: values['name'] ?? '',
        value: values['value'] ?? '',
        module: values['module'] ?? '',
        object: values['object'] ?? '',
        objectId: values['objectId'] ?? '',
        lang: values['lang'] ?? '',
      );
      ref.invalidate(allSettingsProvider);
      if (_selectedModule != null) {
        final apiModule =
            _selectedModule == '(default)' ? '' : _selectedModule!;
        ref.invalidate(settingsByModuleProvider(apiModule));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setting "${values['name']}" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAll = ref.watch(allSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: PageHeader(
            title: 'Settings',
            breadcrumbs: const ['Dashboard', 'Settings'],
            actions: [
              ElevatedButton.icon(
                onPressed: _createSetting,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Setting'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search settings by name or value...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: asyncAll.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load settings',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.onSurfaceMuted)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(allSettingsProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (allSettings) =>
                _buildBody(context, allSettings),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<SettingObject> allSettings) {
    // Group by module
    final moduleMap = <String, List<SettingObject>>{};
    for (final s in allSettings) {
      final m = s.hasKey() && s.key.module.isNotEmpty
          ? s.key.module
          : '(default)';
      moduleMap.putIfAbsent(m, () => []).add(s);
    }
    final modules = moduleMap.keys.toList()..sort();

    // Filter by search or selected module
    final isSearching = _searchQuery.isNotEmpty;
    final displaySettings = isSearching
        ? allSettings.where((s) {
            final name = s.hasKey() ? s.key.name : '';
            final val = s.value;
            final q = _searchQuery.toLowerCase();
            return name.toLowerCase().contains(q) ||
                val.toLowerCase().contains(q);
          }).toList()
        : (_selectedModule != null
            ? (moduleMap[_selectedModule] ?? [])
            : allSettings);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Module list
        if (!isSearching)
          SizedBox(
            width: 220,
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('MODULES',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.onSurfaceMuted)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final mod = modules[index];
                        final isSelected = mod == _selectedModule;
                        final count = moduleMap[mod]?.length ?? 0;
                        return Material(
                          color: isSelected
                              ? AppColors.tertiary
                                  .withValues(alpha: 0.08)
                              : Colors.transparent,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.tune,
                                size: 16,
                                color: isSelected
                                    ? AppColors.tertiary
                                    : AppColors.onSurfaceMuted),
                            title: Text(mod,
                                style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                            trailing: Text('$count',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color:
                                            AppColors.onSurfaceMuted)),
                            onTap: () =>
                                setState(() => _selectedModule = mod),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Right: Settings list
        Expanded(
          child: displaySettings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      Text(isSearching
                          ? 'No results for "$_searchQuery"'
                          : 'Select a module or create a setting'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: displaySettings.length,
                  itemBuilder: (context, index) {
                    final s = displaySettings[index];
                    return _SettingRow(
                      setting: s,
                      isExpanded: _expandedId == s.id,
                      onToggle: () => setState(() {
                        _expandedId =
                            _expandedId == s.id ? null : s.id;
                      }),
                      onSave: (newValue) => _saveSetting(s, newValue),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _saveSetting(SettingObject setting, String newValue) async {
    final key = setting.hasKey() ? setting.key : Setting();
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.set(
        name: key.name,
        value: newValue,
        module: key.module,
        object: key.object,
        objectId: key.objectId,
        lang: key.lang,
      );
      ref.invalidate(allSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Setting saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Setting Row with inline edit ─────────────────────────────────────────────

class _SettingRow extends StatefulWidget {
  const _SettingRow({
    required this.setting,
    required this.isExpanded,
    required this.onToggle,
    required this.onSave,
  });

  final SettingObject setting;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(String newValue) onSave;

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value);
  }

  @override
  void didUpdateWidget(_SettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.value != widget.setting.value && !_editing) {
      _controller.text = widget.setting.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text);
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isJson(String value) {
    final v = value.trim();
    return (v.startsWith('{') && v.endsWith('}')) ||
        (v.startsWith('[') && v.endsWith(']'));
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.setting.hasKey() ? widget.setting.key : Setting();
    final name = key.name.isNotEmpty ? key.name : widget.setting.id;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (key.module.isNotEmpty || key.object.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [
                                if (key.module.isNotEmpty) key.module,
                                if (key.object.isNotEmpty) key.object,
                                if (key.lang.isNotEmpty) key.lang,
                              ].join(' · '),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: AppColors.onSurfaceMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_editing)
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.setting.value.isEmpty
                                  ? '—'
                                  : widget.setting.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontFamily:
                                        _isJson(widget.setting.value)
                                            ? 'monospace'
                                            : null,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.copy_outlined, size: 14),
                            tooltip: 'Copy',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.setting.value));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied')),
                              );
                            },
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.edit_outlined, size: 14),
                            tooltip: 'Edit',
                            onPressed: () =>
                                setState(() => _editing = true),
                          ),
                        ],
                      ),
                    ),
                  if (_editing)
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              maxLines: _isJson(widget.setting.value)
                                  ? 3
                                  : 1,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily:
                                    _isJson(widget.setting.value)
                                        ? 'monospace'
                                        : null,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              onSubmitted: (_) => _save(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_saving)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          else ...[
                            IconButton(
                              icon: Icon(Icons.check,
                                  size: 16, color: AppColors.success),
                              onPressed: _save,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _controller.text = widget.setting.value;
                                setState(() => _editing = false);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 8),
                  _meta(context, 'ID', widget.setting.id),
                  if (widget.setting.updated.isNotEmpty)
                    _meta(context, 'Updated', widget.setting.updated),
                  if (key.objectId.isNotEmpty)
                    _meta(context, 'Object ID', key.objectId),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
