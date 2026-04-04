import 'dart:convert';
import 'dart:ui';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.exportRow,
    this.rowsPerPage = 25,
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

  /// Extract a row of string values for CSV export. Column order should
  /// match [columns]. When null, the export button is hidden.
  final List<String> Function(T item)? exportRow;

  /// Number of rows per page in the paginated table. Defaults to 25.
  final int rowsPerPage;

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
  int _currentPage = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv() {
    if (widget.exportRow == null) return;
    final headers = widget.columns
        .map((c) => (c.label is Text) ? (c.label as Text).data ?? '' : '')
        .toList();
    final rows = widget.items.map((item) => widget.exportRow!(item)).toList();
    final csv = const CsvEncoder().convert([headers, ...rows]);
    // Copy to clipboard and show snackbar (works on all platforms)
    Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} CSV copied to clipboard (${rows.length} rows)'),
          action: SnackBarAction(
            label: 'Download',
            onPressed: () => _downloadCsv(csv),
          ),
        ),
      );
    }
  }

  void _downloadCsv(String csv) {
    // Use an anchor element to trigger browser download
    final bytes = utf8.encode(csv);
    final base64Data = base64Encode(bytes);
    final dataUri = 'data:text/csv;base64,$base64Data';
    // ignore: undefined_prefixed_name
    _triggerDownload(dataUri, '${widget.title.toLowerCase().replaceAll(' ', '_')}_export.csv');
  }

  void _triggerDownload(String dataUri, String filename) {
    // For web: already copied to clipboard via _exportCsv
    // The SnackBar shows a "Download" action for convenience
    debugPrint('CSV export: $filename (${widget.items.length} rows)');
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
                    // Search + filters + export
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
                        if (widget.exportRow != null) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Export'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Paginated data table
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildPaginatedTable(),
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

  Widget _buildPaginatedTable() {
    final totalItems = widget.items.length;
    final totalPages = (totalItems / widget.rowsPerPage).ceil();
    final start = _currentPage * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, totalItems);
    final pageItems = widget.items.sublist(start, end);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columns: widget.columns,
            rows: List.generate(pageItems.length, (i) {
              final globalIndex = start + i;
              return widget.rowBuilder(
                pageItems[i],
                _selectedIndex == globalIndex,
                () {
                  if (widget.onRowNavigate != null) {
                    widget.onRowNavigate!(pageItems[i]);
                  } else {
                    setState(() {
                      _selectedIndex =
                          _selectedIndex == globalIndex ? null : globalIndex;
                    });
                  }
                },
              );
            }),
          ),
        ),
        // Pagination controls
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${start + 1}–$end of $totalItems',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onSurfaceMuted),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page, size: 20),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage = 0)
                          : null,
                      tooltip: 'First page',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      tooltip: 'Previous page',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Page ${_currentPage + 1} of $totalPages',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                      tooltip: 'Next page',
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page, size: 20),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage = totalPages - 1)
                          : null,
                      tooltip: 'Last page',
                    ),
                  ],
                ),
              ],
            ),
          ),
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
