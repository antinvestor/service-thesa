import 'dart:async';

import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';

class SettingsModulesPage extends ConsumerStatefulWidget {
  const SettingsModulesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  ConsumerState<SettingsModulesPage> createState() =>
      _SettingsModulesPageState();
}

class _SettingsModulesPageState extends ConsumerState<SettingsModulesPage> {
  String? _selectedModule;
  String _searchQuery = '';
  Timer? _debounce;

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
          initialValue: _selectedModule != null &&
                  _selectedModule != '(default)'
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
      ref.invalidate(allSettingsProvider);
      ref.invalidate(settingsModulesProvider);
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

  @override
  Widget build(BuildContext context) {
    final asyncModules = ref.watch(settingsModulesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: PageHeader(
            title: 'Modules',
            breadcrumbs: ['Services', widget.service.label, 'Modules'],
            actions: [
              ElevatedButton.icon(
                onPressed: _createSetting,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Setting'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: asyncModules.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load modules',
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
                        ref.invalidate(settingsModulesProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (modules) {
              if (modules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.widgets_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      const Text('No modules found'),
                      const SizedBox(height: 4),
                      Text('Create a setting to get started',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                );
              }
              return _ModulesContent(
                modules: modules,
                selectedModule: _selectedModule,
                searchQuery: _searchQuery,
                onModuleSelected: (m) =>
                    setState(() => _selectedModule = m),
                onSearchChanged: _onSearchChanged,
                onSave: _saveSettingValue,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettingValue(
      SettingObject setting, String newValue) async {
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
      ref.invalidate(settingsModulesProvider);
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

// ── Modules Content (left panel + right detail) ─────────────────────────────

class _ModulesContent extends StatelessWidget {
  const _ModulesContent({
    required this.modules,
    required this.selectedModule,
    required this.searchQuery,
    required this.onModuleSelected,
    required this.onSearchChanged,
    required this.onSave,
  });

  final List<SettingsModuleInfo> modules;
  final String? selectedModule;
  final String searchQuery;
  final ValueChanged<String?> onModuleSelected;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(SettingObject, String) onSave;

  @override
  Widget build(BuildContext context) {
    final isDesktop = screenSizeOf(context) == ScreenSize.desktop;
    final selected =
        modules.where((m) => m.name == selectedModule).firstOrNull;
    final totalSettings =
        modules.fold<int>(0, (sum, m) => sum + m.settingCount);

    if (!isDesktop) {
      // On mobile/tablet, show module list or settings based on selection
      if (selected != null) {
        return Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => onModuleSelected(null),
                  ),
                  Text(selected.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${selected.settingCount} settings',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.onSurfaceMuted)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _ModuleSettingsList(
                module: selected,
                searchQuery: searchQuery,
                onSearchChanged: onSearchChanged,
                onSave: onSave,
              ),
            ),
          ],
        );
      }
      return _ModuleCardGrid(
        modules: modules,
        totalSettings: totalSettings,
        onModuleSelected: onModuleSelected,
      );
    }

    // Desktop: side-by-side
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Module list
        SizedBox(
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Text('MODULES',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.onSurfaceMuted)),
                      const Spacer(),
                      Text('$totalSettings total',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: modules.length,
                    itemBuilder: (context, index) {
                      final mod = modules[index];
                      final isSelected = mod.name == selectedModule;
                      return _ModuleListTile(
                        module: mod,
                        isSelected: isSelected,
                        onTap: () => onModuleSelected(mod.name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Settings for selected module
        Expanded(
          child: selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.widgets_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      Text('Select a module',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                )
              : _ModuleSettingsList(
                  module: selected,
                  searchQuery: searchQuery,
                  onSearchChanged: onSearchChanged,
                  onSave: onSave,
                ),
        ),
      ],
    );
  }
}

// ── Module List Tile ────────────────────────────────────────────────────────

class _ModuleListTile extends StatelessWidget {
  const _ModuleListTile({
    required this.module,
    required this.isSelected,
    required this.onTap,
  });

  final SettingsModuleInfo module;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _moduleIcon(String name) {
    return switch (name.toLowerCase()) {
      'payment' => Icons.payment,
      'notification' => Icons.notifications_outlined,
      'tenancy' => Icons.apartment,
      'profile' => Icons.person_outline,
      'ledger' => Icons.account_balance,
      'auth' || 'authentication' => Icons.lock_outline,
      'billing' => Icons.receipt_long,
      '(default)' => Icons.settings,
      _ => Icons.tune,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.tertiary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSelected
                          ? AppColors.tertiary
                          : AppColors.onSurfaceMuted)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _moduleIcon(module.name),
                  size: 18,
                  color: isSelected
                      ? AppColors.tertiary
                      : AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.name,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400)),
                    if (module.objectTypes.isNotEmpty ||
                        module.languages.isNotEmpty)
                      Text(
                        [
                          if (module.objectTypes.isNotEmpty)
                            '${module.objectTypes.length} types',
                          if (module.languages.isNotEmpty)
                            '${module.languages.length} langs',
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.onSurfaceMuted),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${module.settingCount}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Module Card Grid (tablet/mobile) ────────────────────────────────────────

class _ModuleCardGrid extends StatelessWidget {
  const _ModuleCardGrid({
    required this.modules,
    required this.totalSettings,
    required this.onModuleSelected,
  });

  final List<SettingsModuleInfo> modules;
  final int totalSettings;
  final ValueChanged<String?> onModuleSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: modules
            .map((mod) => _ModuleCard(
                  module: mod,
                  onTap: () => onModuleSelected(mod.name),
                ))
            .toList(),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final SettingsModuleInfo module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                      child: Icon(Icons.widgets_outlined,
                          size: 20, color: AppColors.tertiary),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: AppColors.onSurfaceMuted),
                  ],
                ),
                const SizedBox(height: 16),
                Text(module.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${module.settingCount} settings',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
                if (module.objectTypes.isNotEmpty ||
                    module.languages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final obj in module.objectTypes)
                        _SmallChip(label: obj, color: AppColors.success),
                      for (final lang in module.languages)
                        _SmallChip(label: lang, color: Colors.orange),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});

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
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

// ── Module Settings List ────────────────────────────────────────────────────

class _ModuleSettingsList extends StatefulWidget {
  const _ModuleSettingsList({
    required this.module,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSave,
  });

  final SettingsModuleInfo module;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(SettingObject, String) onSave;

  @override
  State<_ModuleSettingsList> createState() => _ModuleSettingsListState();
}

class _ModuleSettingsListState extends State<_ModuleSettingsList> {
  String? _expandedId;

  List<SettingObject> get _filteredSettings {
    if (widget.searchQuery.isEmpty) return widget.module.settings;
    final q = widget.searchQuery.toLowerCase();
    return widget.module.settings.where((s) {
      final name = s.hasKey() ? s.key.name : '';
      final value = s.value;
      return name.toLowerCase().contains(q) ||
          value.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _filteredSettings;

    return Column(
      children: [
        // Module header + search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.module.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.module.settingCount} settings',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                  if (widget.module.objectTypes.isNotEmpty ||
                      widget.module.languages.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final obj in widget.module.objectTypes)
                          _SmallChip(label: obj, color: AppColors.success),
                        for (final lang in widget.module.languages)
                          _SmallChip(label: lang, color: Colors.orange),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
                  hintText:
                      'Search in ${widget.module.name}...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Settings list
        Expanded(
          child: settings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 40, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 8),
                      Text(
                        widget.searchQuery.isNotEmpty
                            ? 'No results for "${widget.searchQuery}"'
                            : 'No settings in this module',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.onSurfaceMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: settings.length,
                  itemBuilder: (context, index) {
                    final s = settings[index];
                    return _ModuleSettingTile(
                      setting: s,
                      isExpanded: _expandedId == s.id,
                      onToggle: () => setState(() {
                        _expandedId =
                            _expandedId == s.id ? null : s.id;
                      }),
                      onSave: (newValue) => widget.onSave(s, newValue),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Module Setting Tile ─────────────────────────────────────────────────────

class _ModuleSettingTile extends StatefulWidget {
  const _ModuleSettingTile({
    required this.setting,
    required this.isExpanded,
    required this.onToggle,
    required this.onSave,
  });

  final SettingObject setting;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(String) onSave;

  @override
  State<_ModuleSettingTile> createState() => _ModuleSettingTileState();
}

class _ModuleSettingTileState extends State<_ModuleSettingTile> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value);
  }

  @override
  void didUpdateWidget(_ModuleSettingTile old) {
    super.didUpdateWidget(old);
    if (old.setting.value != widget.setting.value && !_editing) {
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

  bool _isJson(String v) {
    final t = v.trim();
    return (t.startsWith('{') && t.endsWith('}')) ||
        (t.startsWith('[') && t.endsWith(']'));
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.setting.hasKey() ? widget.setting.key : Setting();
    final name = key.name.isNotEmpty ? key.name : widget.setting.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
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
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                        if (key.object.isNotEmpty || key.lang.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              spacing: 6,
                              children: [
                                if (key.object.isNotEmpty)
                                  _SmallChip(
                                      label: key.object,
                                      color: AppColors.success),
                                if (key.lang.isNotEmpty)
                                  _SmallChip(
                                      label: key.lang,
                                      color: Colors.orange),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_editing)
                    Expanded(
                      flex: 4,
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
                            icon: const Icon(Icons.copy_outlined,
                                size: 14),
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
                      flex: 4,
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
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 8),
                  _MetaItem(label: 'ID', value: widget.setting.id),
                  if (widget.setting.updated.isNotEmpty)
                    _MetaItem(
                        label: 'Updated', value: widget.setting.updated),
                  if (key.objectId.isNotEmpty)
                    _MetaItem(label: 'Object ID', value: key.objectId),
                  if (_isJson(widget.setting.value)) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
