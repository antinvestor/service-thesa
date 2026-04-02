import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import 'state_badge.dart';

/// A tree node wrapping a PartitionObject with its children.
class PartitionNode {
  PartitionNode(this.partition, {this.children = const [], this.depth = 0});

  final PartitionObject partition;
  final List<PartitionNode> children;
  final int depth;
}

/// Builds a forest of [PartitionNode] from a flat list of partitions.
/// Root partitions have empty parentId.
List<PartitionNode> buildPartitionTree(List<PartitionObject> partitions) {
  final byId = <String, PartitionObject>{};
  final childrenMap = <String, List<PartitionObject>>{};

  for (final p in partitions) {
    byId[p.id] = p;
    final parent = p.parentId.isEmpty ? '' : p.parentId;
    childrenMap.putIfAbsent(parent, () => []).add(p);
  }

  List<PartitionNode> buildChildren(String parentId, int depth) {
    final children = childrenMap[parentId] ?? [];
    return children
        .map((p) => PartitionNode(
              p,
              children: buildChildren(p.id, depth + 1),
              depth: depth,
            ))
        .toList();
  }

  return buildChildren('', 0);
}

/// Flattens visible tree nodes based on expansion state.
List<PartitionNode> flattenTree(
  List<PartitionNode> roots,
  Set<String> expandedIds,
) {
  final result = <PartitionNode>[];
  void walk(List<PartitionNode> nodes) {
    for (final node in nodes) {
      result.add(node);
      if (expandedIds.contains(node.partition.id) &&
          node.children.isNotEmpty) {
        walk(node.children);
      }
    }
  }
  walk(roots);
  return result;
}

/// A hierarchical tree table for partitions matching the Stitch
/// "Partition Management (Nested Nav)" design.
///
/// Shows parent-child relationships with:
/// - Indentation based on depth
/// - Expand/collapse chevrons for nodes with children
/// - Folder/subdirectory icons to indicate nesting level
/// - Right-side detail panel on selection
class PartitionTreeView extends StatefulWidget {
  const PartitionTreeView({
    super.key,
    required this.partitions,
    this.onEdit,
  });

  final List<PartitionObject> partitions;
  final void Function(PartitionObject)? onEdit;

  @override
  State<PartitionTreeView> createState() => _PartitionTreeViewState();
}

class _PartitionTreeViewState extends State<PartitionTreeView> {
  final Set<String> _expanded = {};
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Auto-expand root nodes
    final roots = buildPartitionTree(widget.partitions);
    for (final root in roots) {
      _expanded.add(root.partition.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roots = buildPartitionTree(widget.partitions);
    final visible = flattenTree(roots, _expanded);
    final selected = _selectedId != null
        ? widget.partitions.where((p) => p.id == _selectedId).firstOrNull
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tree table
        Expanded(
          flex: selected != null ? 3 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const Divider(height: 1),
                ...visible.map((node) => _buildRow(context, node, roots)),
              ],
            ),
          ),
        ),
        // Detail panel
        if (selected != null) ...[
          const SizedBox(width: 20),
          SizedBox(
            width: 380,
            child: _PartitionDetailPanel(
              partition: selected,
              onClose: () => setState(() => _selectedId = null),
              onEdit: widget.onEdit != null
                  ? () => widget.onEdit!(selected)
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 14,
          color: AppColors.onSurfaceMuted,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('NAME & HIERARCHY', style: style)),
          Expanded(flex: 2, child: Text('PARTITION ID', style: style)),
          Expanded(flex: 2, child: Text('PARENT', style: style)),
          Expanded(flex: 1, child: Text('STATE', style: style)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    PartitionNode node,
    List<PartitionNode> roots,
  ) {
    final p = node.partition;
    final isSelected = p.id == _selectedId;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expanded.contains(p.id);

    return Material(
      color: isSelected
          ? AppColors.tertiary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/services/tenancy/partitions/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Name & hierarchy with indentation
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    // Indentation
                    SizedBox(width: node.depth * 24.0),
                    // Expand/collapse or spacer
                    if (hasChildren)
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => setState(() {
                          if (isExpanded) {
                            _expanded.remove(p.id);
                          } else {
                            _expanded.add(p.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 22),
                    const SizedBox(width: 4),
                    // Folder icon
                    Icon(
                      node.depth == 0
                          ? (isExpanded
                              ? Icons.folder_open_outlined
                              : Icons.folder_outlined)
                          : Icons.subdirectory_arrow_right,
                      size: 18,
                      color: node.depth == 0
                          ? AppColors.tertiary
                          : AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              node.depth == 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Partition ID
              Expanded(
                flex: 2,
                child: Text(
                  p.id,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              // Parent
              Expanded(
                flex: 2,
                child: Text(
                  p.parentId.isNotEmpty ? p.parentId : '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: p.parentId.isEmpty
                        ? AppColors.onSurfaceMuted
                        : null,
                  ),
                ),
              ),
              // State
              Expanded(
                flex: 1,
                child: StateBadge(p.state),
              ),
              // Actions
              SizedBox(
                width: 48,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onPressed: () {},
                  iconSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _PartitionDetailPanel extends StatelessWidget {
  const _PartitionDetailPanel({
    required this.partition,
    required this.onClose,
    this.onEdit,
  });

  final PartitionObject partition;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Partition Details',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailField('Name', partition.name),
                _DetailField('Partition ID', partition.id),
                _DetailField('Tenant ID', partition.tenantId),
                if (partition.parentId.isNotEmpty)
                  _DetailField('Parent ID', partition.parentId),
                if (partition.description.isNotEmpty)
                  _DetailField('Description', partition.description),
                _DetailField('State', partition.state.name),
                if (partition.hasCreatedAt())
                  _DetailField(
                    'Created',
                    DateFormat.yMMMd()
                        .add_Hm()
                        .format(partition.createdAt.toDateTime()),
                  ),
                const SizedBox(height: 16),
                // Quick actions
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync Assets'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Audit Logs'),
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
}

class _DetailField extends StatelessWidget {
  const _DetailField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ),
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
