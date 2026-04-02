import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/entity_list_page.dart';

/// Wraps [EntityListPage] with async data loading via a FutureProvider.
/// Shows loading spinner and error state automatically.
class AsyncEntityList<T> extends ConsumerWidget {
  const AsyncEntityList({
    super.key,
    required this.dataProvider,
    required this.title,
    required this.breadcrumbs,
    required this.columns,
    required this.rowBuilder,
    this.searchHint = 'Search...',
    this.detailBuilder,
    this.addLabel,
    this.onAdd,
    this.editFields,
    this.editTitle,
    this.editValuesExtractor,
    this.onSave,
    this.auditTrailBuilder,
    this.actions,
    this.onRefresh,
    this.onRowNavigate,
  });

  final FutureProvider<List<T>> dataProvider;
  final String title;
  final List<String> breadcrumbs;
  final List<DataColumn> columns;
  final DataRow Function(T item, bool selected, VoidCallback onSelect)
      rowBuilder;
  final String searchHint;
  final Widget Function(T item)? detailBuilder;
  final String? addLabel;
  final VoidCallback? onAdd;
  final List<EditField>? editFields;
  final String Function(T item)? editTitle;
  final Map<String, String> Function(T item)? editValuesExtractor;
  final void Function(T? item, Map<String, String> values)? onSave;
  final List<AuditEntry> Function(T item)? auditTrailBuilder;
  final List<Widget>? actions;
  final VoidCallback? onRefresh;
  final void Function(T item)? onRowNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dataProvider);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load $title',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            if (onRefresh != null)
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
      data: (items) => EntityListPage<T>(
        title: title,
        breadcrumbs: breadcrumbs,
        columns: columns,
        items: items,
        rowBuilder: rowBuilder,
        searchHint: searchHint,
        detailBuilder: detailBuilder,
        addLabel: addLabel,
        onAdd: onAdd,
        editFields: editFields,
        editTitle: editTitle,
        editValuesExtractor: editValuesExtractor,
        onSave: onSave,
        auditTrailBuilder: auditTrailBuilder,
        actions: actions,
        onRowNavigate: onRowNavigate,
      ),
    );
  }
}
