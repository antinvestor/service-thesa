import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../partition/widgets/state_badge.dart';
import '../data/profile_repository.dart';

class RelationshipsPage extends ConsumerStatefulWidget {
  const RelationshipsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  ConsumerState<RelationshipsPage> createState() => _RelationshipsPageState();
}

class _RelationshipsPageState extends ConsumerState<RelationshipsPage> {
  final _peerNameController = TextEditingController();
  final _peerIdController = TextEditingController();

  List<RelationshipObject>? _relationships;
  bool _loading = false;
  String? _error;
  int? _selectedIndex;

  @override
  void dispose() {
    _peerNameController.dispose();
    _peerIdController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final peerName = _peerNameController.text.trim();
    final peerId = _peerIdController.text.trim();

    if (peerName.isEmpty || peerId.isEmpty) {
      setState(() {
        _error = 'Both Peer Name and Peer ID are required.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = null;
    });

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final results = await repo.listRelationships(
        peerName: peerName,
        peerId: peerId,
      );
      setState(() {
        _relationships = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Relationships',
            breadcrumbs: [
              'Services',
              widget.service.label,
              'Relationships',
            ],
          ),
          const SizedBox(height: 20),
          // Search form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search Relationships',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Enter the peer object name and ID to list relationships.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _peerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Peer Name',
                          hintText: 'e.g. profile',
                          isDense: true,
                          prefixIcon:
                              Icon(Icons.label_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _peerIdController,
                        decoration: const InputDecoration(
                          labelText: 'Peer ID',
                          hintText: 'e.g. abc123...',
                          isDense: true,
                          prefixIcon: Icon(Icons.tag, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Results
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_relationships != null) ...[
            if (_relationships!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.group_work_outlined,
                        size: 48, color: AppColors.onSurfaceMuted),
                    const SizedBox(height: 12),
                    Text('No relationships found',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Try a different peer name or ID.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: _selectedIndex != null ? 3 : 1,
                    child: Container(
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
                            columns: const [
                              DataColumn(label: Text('TYPE')),
                              DataColumn(label: Text('PARENT')),
                              DataColumn(label: Text('CHILD')),
                              DataColumn(label: Text('PEER PROFILE')),
                            ],
                            rows: List.generate(_relationships!.length, (i) {
                              final rel = _relationships![i];
                              final typeLabel = rel.type.name;
                              final typeColor = switch (rel.type) {
                                RelationshipType.MEMBER =>
                                  AppColors.tertiary,
                                RelationshipType.AFFILIATED =>
                                  AppColors.success,
                                RelationshipType.BLACK_LISTED =>
                                  AppColors.error,
                                _ => AppColors.onSurfaceMuted,
                              };

                              final parentDisplay =
                                  '${rel.parentEntry.objectName}:${_truncateId(rel.parentEntry.objectId)}';
                              final childDisplay =
                                  '${rel.childEntry.objectName}:${_truncateId(rel.childEntry.objectId)}';
                              final peerDisplay =
                                  rel.hasPeerProfile()
                                      ? _truncateId(rel.peerProfile.id)
                                      : '-';

                              return DataRow(
                                selected: _selectedIndex == i,
                                onSelectChanged: (_) => setState(() {
                                  _selectedIndex =
                                      _selectedIndex == i ? null : i;
                                }),
                                color:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.tertiary
                                        .withValues(alpha: 0.05);
                                  }
                                  return null;
                                }),
                                cells: [
                                  DataCell(
                                      ColorBadge(typeLabel, typeColor)),
                                  DataCell(Text(parentDisplay,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12))),
                                  DataCell(Text(childDisplay,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12))),
                                  DataCell(Text(peerDisplay,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12))),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Detail panel
                  if (_selectedIndex != null) ...[
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 380,
                      child: _RelationshipDetail(
                        relationship: _relationships![_selectedIndex!],
                        onClose: () =>
                            setState(() => _selectedIndex = null),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length >= 8) return id.substring(0, 8);
    return id;
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _RelationshipDetail extends StatelessWidget {
  const _RelationshipDetail({
    required this.relationship,
    required this.onClose,
  });

  final RelationshipObject relationship;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (relationship.type) {
      RelationshipType.MEMBER => AppColors.tertiary,
      RelationshipType.AFFILIATED => AppColors.success,
      RelationshipType.BLACK_LISTED => AppColors.error,
      _ => AppColors.onSurfaceMuted,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: typeColor.withValues(alpha: 0.15),
                      child: Icon(Icons.group_work_outlined,
                          color: typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(relationship.type.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(relationship.id,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.onSurfaceMuted,
                                      fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow(label: 'ID', value: relationship.id),
                _DetailRow(
                    label: 'Type', value: relationship.type.name),
                _DetailRow(
                  label: 'Parent',
                  value:
                      '${relationship.parentEntry.objectName}:${relationship.parentEntry.objectId}',
                ),
                _DetailRow(
                  label: 'Child',
                  value:
                      '${relationship.childEntry.objectName}:${relationship.childEntry.objectId}',
                ),
                if (relationship.hasPeerProfile())
                  _DetailRow(
                    label: 'Peer Profile',
                    value: relationship.peerProfile.id,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            width: 110,
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
