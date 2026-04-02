import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'page_header.dart';
import 'responsive_layout.dart';

/// Configuration for a form field in the edit panel.
class EditField {
  const EditField({
    required this.label,
    required this.key,
    this.type = EditFieldType.text,
    this.hint,
    this.options = const [],
    this.maxLines = 1,
    this.readOnly = false,
  });

  final String label;
  final String key;
  final EditFieldType type;
  final String? hint;
  final List<String> options; // For dropdown type
  final int maxLines;
  final bool readOnly;
}

enum EditFieldType { text, number, dropdown, textarea }

/// Audit trail entry for the edit panel.
class AuditEntry {
  const AuditEntry({required this.description, required this.time});
  final String description;
  final String time;
}

/// A reusable entity list page pattern: searchable table + detail panel + edit slide-over.
///
/// Matches the Stitch design:
/// - Search bar + filter toolbar
/// - Data table with row selection → detail panel (desktop)
/// - Glassmorphism slide-over for editing/creating
class EntityListPage<T> extends StatefulWidget {
  const EntityListPage({
    super.key,
    required this.title,
    required this.breadcrumbs,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.searchHint = 'Search...',
    this.detailBuilder,
    this.actions,
    this.onSearch,
    this.onAdd,
    this.addLabel,
    this.onRowNavigate,
    // Edit panel configuration
    this.editFields,
    this.editTitle,
    this.editValuesExtractor,
    this.onSave,
    this.auditTrailBuilder,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<DataColumn> columns;
  final List<T> items;
  final DataRow Function(T item, bool selected, VoidCallback onSelect) rowBuilder;
  final String searchHint;
  final Widget Function(T item)? detailBuilder;
  final List<Widget>? actions;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onAdd;
  final String? addLabel;

  /// When provided, row taps navigate to a detail page instead of
  /// showing the side panel. Called with the tapped item.
  final void Function(T item)? onRowNavigate;

  /// Fields to show in the edit panel. If null, no edit functionality.
  final List<EditField>? editFields;

  /// Title for the edit panel (e.g., "Edit TXN-904-221").
  final String Function(T item)? editTitle;

  /// Extract current values from an item for pre-filling the edit form.
  final Map<String, String> Function(T item)? editValuesExtractor;

  /// Called when save is pressed with the field values map.
  final void Function(T? item, Map<String, String> values)? onSave;

  /// Build audit trail entries for an item.
  final List<AuditEntry> Function(T item)? auditTrailBuilder;

  @override
  State<EntityListPage<T>> createState() => _EntityListPageState<T>();
}

class _EntityListPageState<T> extends State<EntityListPage<T>> {
  int? _selectedIndex;
  int? _editingIndex;
  bool _creating = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEdit(int index) {
    setState(() {
      _editingIndex = index;
      _creating = false;
    });
  }

  void _openCreate() {
    setState(() {
      _editingIndex = null;
      _creating = true;
    });
  }

  void _closeEdit() {
    setState(() {
      _editingIndex = null;
      _creating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reset stale indices when items list changes
    if (_selectedIndex != null && _selectedIndex! >= widget.items.length) {
      _selectedIndex = null;
    }
    if (_editingIndex != null && _editingIndex! >= widget.items.length) {
      _editingIndex = null;
    }

    final screenSize = screenSizeOf(context);
    final showDetailPanel = screenSize == ScreenSize.desktop &&
        widget.detailBuilder != null &&
        widget.onRowNavigate == null &&
        _selectedIndex != null;

    final showEditOverlay =
        widget.editFields != null && (_editingIndex != null || _creating);

    return Stack(
      children: [
        // Main content
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: showDetailPanel ? 3 : 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: widget.title,
                      breadcrumbs: widget.breadcrumbs,
                      actions: [
                        if (widget.onAdd != null || widget.editFields != null)
                          ElevatedButton.icon(
                            onPressed: widget.editFields != null
                                ? _openCreate
                                : widget.onAdd,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(widget.addLabel ?? 'Add'),
                          ),
                        ...?widget.actions,
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Search + filters
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: widget.onSearch,
                            decoration: InputDecoration(
                              hintText: widget.searchHint,
                              prefixIcon:
                                  const Icon(Icons.search, size: 20),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Data table
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: widget.columns,
                            rows: List.generate(widget.items.length, (i) {
                              return widget.rowBuilder(
                                widget.items[i],
                                _selectedIndex == i,
                                () {
                                  if (widget.onRowNavigate != null) {
                                    widget.onRowNavigate!(widget.items[i]);
                                  } else {
                                    setState(() {
                                      _selectedIndex =
                                          _selectedIndex == i ? null : i;
                                    });
                                  }
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Detail panel (desktop only)
            if (showDetailPanel)
              SizedBox(
                width: 380,
                child: Container(
                  margin: const EdgeInsets.only(
                      top: 24, right: 24, bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.editFields != null)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20),
                                onPressed: () =>
                                    _openEdit(_selectedIndex!),
                                tooltip: 'Edit',
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  setState(() => _selectedIndex = null),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: widget.detailBuilder!(
                              widget.items[_selectedIndex!]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Edit slide-over overlay
        if (showEditOverlay) _buildEditOverlay(context),
      ],
    );
  }

  Widget _buildEditOverlay(BuildContext context) {
    final item =
        _editingIndex != null ? widget.items[_editingIndex!] : null;
    final title = item != null && widget.editTitle != null
        ? widget.editTitle!(item)
        : _creating
            ? 'New ${widget.title}'
            : 'Edit';
    final initialValues = item != null && widget.editValuesExtractor != null
        ? widget.editValuesExtractor!(item)
        : <String, String>{};
    final audits = item != null && widget.auditTrailBuilder != null
        ? widget.auditTrailBuilder!(item)
        : <AuditEntry>[];

    return _EditSlideOver(
      title: title,
      fields: widget.editFields!,
      initialValues: initialValues,
      auditTrail: audits,
      onSave: (values) {
        widget.onSave?.call(item, values);
        _closeEdit();
      },
      onCancel: _closeEdit,
    );
  }
}

// ─── Edit Slide-Over Panel ───────────────────────────────────────────────────

class _EditSlideOver extends StatefulWidget {
  const _EditSlideOver({
    required this.title,
    required this.fields,
    required this.initialValues,
    required this.auditTrail,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final List<EditField> fields;
  final Map<String, String> initialValues;
  final List<AuditEntry> auditTrail;
  final ValueChanged<Map<String, String>> onSave;
  final VoidCallback onCancel;

  @override
  State<_EditSlideOver> createState() => _EditSlideOverState();
}

class _EditSlideOverState extends State<_EditSlideOver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controllers = {};
    _dropdownValues = {};
    for (final field in widget.fields) {
      final value = widget.initialValues[field.key] ?? '';
      if (field.type == EditFieldType.dropdown) {
        _dropdownValues[field.key] = value;
      } else {
        _controllers[field.key] = TextEditingController(text: value);
      }
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collectValues() {
    final values = <String, String>{};
    for (final field in widget.fields) {
      if (field.type == EditFieldType.dropdown) {
        values[field.key] = _dropdownValues[field.key] ?? '';
      } else {
        values[field.key] = _controllers[field.key]?.text ?? '';
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed background
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              color: AppColors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Slide-over panel
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 440,
          child: SlideTransition(
            position: _slideAnimation,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    border: Border(
                      left: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.06),
                        blurRadius: 40,
                        offset: const Offset(-20, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 12, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: widget.onCancel,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Form fields
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final field in widget.fields) ...[
                                _buildField(context, field),
                                const SizedBox(height: 16),
                              ],
                              // Audit trail
                              if (widget.auditTrail.isNotEmpty) ...[
                                const Divider(height: 32),
                                Text('Audit Trail',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                for (final entry in widget.auditTrail)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.circle,
                                            size: 6,
                                            color:
                                                AppColors.onSurfaceMuted),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(entry.description,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ),
                                        Text(entry.time,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                    color: AppColors
                                                        .onSurfaceMuted)),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Action buttons
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    widget.onSave(_collectValues()),
                                child: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, EditField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        switch (field.type) {
          EditFieldType.dropdown => DropdownButtonFormField<String>(
              initialValue: _dropdownValues[field.key]?.isNotEmpty == true &&
                      field.options.contains(_dropdownValues[field.key])
                  ? _dropdownValues[field.key]
                  : null,
              decoration: InputDecoration(
                hintText: field.hint ?? 'Select...',
                isDense: true,
              ),
              items: field.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: field.readOnly
                  ? null
                  : (v) => setState(
                      () => _dropdownValues[field.key] = v ?? ''),
            ),
          EditFieldType.textarea => TextField(
              controller: _controllers[field.key],
              maxLines: field.maxLines > 1 ? field.maxLines : 4,
              readOnly: field.readOnly,
              decoration: InputDecoration(
                hintText: field.hint,
                isDense: true,
              ),
            ),
          _ => TextField(
              controller: _controllers[field.key],
              readOnly: field.readOnly,
              keyboardType: field.type == EditFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: field.hint,
                isDense: true,
              ),
            ),
        },
      ],
    );
  }
}
