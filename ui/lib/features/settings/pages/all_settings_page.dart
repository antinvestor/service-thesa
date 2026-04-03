import 'dart:async';

import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';

class AllSettingsPage extends ConsumerStatefulWidget {
  const AllSettingsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  ConsumerState<AllSettingsPage> createState() => _AllSettingsPageState();
}

class _AllSettingsPageState extends ConsumerState<AllSettingsPage> {
  String _searchQuery = '';
  Timer? _debounce;
  String? _filterModule;
  String? _filterObject;
  String? _filterLang;
  String? _expandedId;
  bool _showFilters = false;

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

  void _clearFilters() {
    setState(() {
      _filterModule = null;
      _filterObject = null;
      _filterLang = null;
    });
  }

  bool get _hasActiveFilters =>
      _filterModule != null || _filterObject != null || _filterLang != null;

  Future<void> _createSetting() async {
    final stats = ref.read(settingsStatsProvider).value;

    final values = await showEditDialog(
      context: context,
      title: 'New Setting',
      saveLabel: 'Create',
      fields: [
        const DialogField(
          key: 'name',
          label: 'Name',
          hint: 'e.g. max_retries',
          required: true,
        ),
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
          initialValue: _filterModule ?? '',
        ),
        const DialogField(
          key: 'object',
          label: 'Object Type',
          hint: 'e.g. tenant',
        ),
        const DialogField(key: 'objectId', label: 'Object ID'),
        DialogField(
          key: 'lang',
          label: 'Language',
          hint: stats != null && stats.languages.isNotEmpty
              ? 'e.g. ${stats.languages.first}'
              : 'e.g. en',
        ),
      ],
    );
    if (values == null || !mounted) return;

    final name = values['name'] ?? '';
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.set(
        name: name,
        value: values['value'] ?? '',
        module: values['module'] ?? '',
        object: values['object'] ?? '',
        objectId: values['objectId'] ?? '',
        lang: values['lang'] ?? '',
      );
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setting "$name" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _invalidateAll() {
    ref.invalidate(allSettingsProvider);
    ref.invalidate(settingsStatsProvider);
    ref.invalidate(settingsModulesProvider);
  }

  List<SettingObject> _applyFilters(List<SettingObject> settings) {
    var result = settings;

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final name = s.hasKey() ? s.key.name : '';
        final value = s.value;
        final module = s.hasKey() ? s.key.module : '';
        return name.toLowerCase().contains(q) ||
            value.toLowerCase().contains(q) ||
            module.toLowerCase().contains(q);
      }).toList();
    }

    // Module filter
    if (_filterModule != null) {
      result = result.where((s) {
        final m = s.hasKey() ? s.key.module : '';
        if (_filterModule == '(default)') return m.isEmpty;
        return m == _filterModule;
      }).toList();
    }

    // Object type filter
    if (_filterObject != null) {
      result = result.where((s) {
        return s.hasKey() && s.key.object == _filterObject;
      }).toList();
    }

    // Language filter
    if (_filterLang != null) {
      result = result.where((s) {
        return s.hasKey() && s.key.lang == _filterLang;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final asyncAll = ref.watch(allSettingsProvider);
    final asyncStats = ref.watch(settingsStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: PageHeader(
            title: 'All Settings',
            breadcrumbs: ['Services', widget.service.label, 'All Settings'],
            actions: [
              ElevatedButton.icon(
                onPressed: _createSetting,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Setting'),
              ),
            ],
          ),
        ),
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search by name, value, or module...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Badge(
                isLabelVisible: _hasActiveFilters,
                smallSize: 8,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showFilters = !_showFilters),
                  icon: Icon(
                    _showFilters
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    size: 18,
                  ),
                  label: const Text('Filter'),
                ),
              ),
            ],
          ),
        ),
        // Filter chips
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: asyncStats.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) => _FilterBar(
                modules: stats.modules,
                objectTypes: stats.objectTypes,
                languages: stats.languages,
                selectedModule: _filterModule,
                selectedObject: _filterObject,
                selectedLang: _filterLang,
                onModuleChanged: (v) =>
                    setState(() => _filterModule = v),
                onObjectChanged: (v) =>
                    setState(() => _filterObject = v),
                onLangChanged: (v) =>
                    setState(() => _filterLang = v),
                onClear: _clearFilters,
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Settings table
        Expanded(
          child: asyncAll.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
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
            data: (allSettings) {
              final filtered = _applyFilters(allSettings);
              return _SettingsTable(
                settings: filtered,
                totalCount: allSettings.length,
                expandedId: _expandedId,
                onToggleExpand: (id) => setState(() {
                  _expandedId = _expandedId == id ? null : id;
                }),
                onSave: _saveSetting,
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
      _invalidateAll();
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

// ── Filter Bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.modules,
    required this.objectTypes,
    required this.languages,
    required this.selectedModule,
    required this.selectedObject,
    required this.selectedLang,
    required this.onModuleChanged,
    required this.onObjectChanged,
    required this.onLangChanged,
    required this.onClear,
  });

  final List<String> modules;
  final List<String> objectTypes;
  final List<String> languages;
  final String? selectedModule;
  final String? selectedObject;
  final String? selectedLang;
  final ValueChanged<String?> onModuleChanged;
  final ValueChanged<String?> onObjectChanged;
  final ValueChanged<String?> onLangChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        selectedModule != null || selectedObject != null || selectedLang != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterDropdown(
            label: 'Module',
            value: selectedModule,
            items: modules,
            onChanged: onModuleChanged,
          ),
          _FilterDropdown(
            label: 'Object',
            value: selectedObject,
            items: objectTypes,
            onChanged: onObjectChanged,
          ),
          _FilterDropdown(
            label: 'Language',
            value: selectedLang,
            items: languages,
            onChanged: onLangChanged,
          ),
          if (hasFilters)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('All',
                style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          ...items.map(
            (item) => DropdownMenuItem(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Settings Table ──────────────────────────────────────────────────────────

class _SettingsTable extends StatelessWidget {
  const _SettingsTable({
    required this.settings,
    required this.totalCount,
    required this.expandedId,
    required this.onToggleExpand,
    required this.onSave,
  });

  final List<SettingObject> settings;
  final int totalCount;
  final String? expandedId;
  final ValueChanged<String> onToggleExpand;
  final Future<void> Function(SettingObject, String) onSave;

  @override
  Widget build(BuildContext context) {
    if (settings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 12),
            const Text('No settings found'),
            if (totalCount > 0) ...[
              const SizedBox(height: 4),
              Text('$totalCount total settings — try adjusting filters',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onSurfaceMuted)),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Count badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            settings.length == totalCount
                ? '$totalCount settings'
                : '${settings.length} of $totalCount settings',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: settings.length,
            itemBuilder: (context, index) {
              final s = settings[index];
              return _SettingRow(
                setting: s,
                isExpanded: expandedId == s.id,
                onToggle: () => onToggleExpand(s.id),
                onSave: (newValue) => onSave(s, newValue),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Setting Row ─────────────────────────────────────────────────────────────

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
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: widget.isExpanded
              ? AppColors.tertiary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Name + tags
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (key.module.isNotEmpty)
                              _Tag(label: key.module, color: AppColors.tertiary),
                            if (key.object.isNotEmpty)
                              _Tag(
                                  label: key.object,
                                  color: AppColors.success),
                            if (key.lang.isNotEmpty)
                              _Tag(
                                  label: key.lang,
                                  color: Colors.orange),
                            if (key.objectId.isNotEmpty)
                              _Tag(
                                  label: key.objectId,
                                  color: AppColors.secondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Value + actions
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
                              maxLines: 2,
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
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined,
                                size: 14),
                            tooltip: 'Copy value',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.setting.value));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 14),
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
                              maxLines:
                                  _isJson(widget.setting.value) ? 3 : 1,
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
                              tooltip: 'Save',
                              onPressed: _save,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: 'Cancel',
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
          // Expanded metadata
          if (widget.isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 8),
                  const SizedBox(height: 8),
                  _MetaRow(label: 'ID', value: widget.setting.id),
                  if (widget.setting.updated.isNotEmpty)
                    _MetaRow(label: 'Updated', value: widget.setting.updated),
                  if (key.module.isNotEmpty)
                    _MetaRow(label: 'Module', value: key.module),
                  if (key.object.isNotEmpty)
                    _MetaRow(label: 'Object', value: key.object),
                  if (key.objectId.isNotEmpty)
                    _MetaRow(label: 'Object ID', value: key.objectId),
                  if (key.lang.isNotEmpty)
                    _MetaRow(label: 'Language', value: key.lang),
                  if (widget.setting.value.isNotEmpty &&
                      _isJson(widget.setting.value)) ...[
                    const SizedBox(height: 8),
                    Text('Value',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.onSurfaceMuted)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        widget.setting.value,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
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

// ── Shared small widgets ────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ),
          Expanded(
            child: SelectableText(value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
