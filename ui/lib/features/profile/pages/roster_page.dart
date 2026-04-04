import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../data/profile_repository.dart';

/// Roster page - search a profile's roster (contact book) entries.
class RosterPage extends ConsumerStatefulWidget {
  const RosterPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  ConsumerState<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends ConsumerState<RosterPage> {
  final _profileIdCtl = TextEditingController();
  final _queryCtl = TextEditingController();
  List<RosterObject>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _profileIdCtl.dispose();
    _queryCtl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final profileId = _profileIdCtl.text.trim();
    if (profileId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final results = await repo.searchRoster(
        profileId: profileId,
        query: _queryCtl.text.trim(),
      );
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _removeEntry(RosterObject entry) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Roster Entry',
      message:
          'Remove "${entry.contact.detail}" from roster?',
    );
    if (!confirmed || !mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.removeRoster(entry.id);
      await _search(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roster entry removed')),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Roster',
            breadcrumbs: [
              'Services',
              widget.service.label,
              'Roster',
            ],
          ),
          const SizedBox(height: 20),

          // Search bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search Roster',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _profileIdCtl,
                          decoration: const InputDecoration(
                            labelText: 'Profile ID',
                            hintText: 'Enter profile ID...',
                            prefixIcon: Icon(Icons.person_outlined, size: 20),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _queryCtl,
                          decoration: const InputDecoration(
                            labelText: 'Search Query (optional)',
                            hintText: 'Filter by name or contact...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: _loading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error
          if (_error != null)
            Card(
              color: AppColors.error.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 20, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ),
            ),

          // Results
          if (_results != null) ...[
            Text('${_results!.length} roster entries found',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 8),
            if (_results!.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      Text('No roster entries found',
                          style: TextStyle(color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _results!.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _RosterEntryTile(
                        entry: _results![i],
                        onRemove: () => _removeEntry(_results![i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RosterEntryTile extends StatelessWidget {
  const _RosterEntryTile({required this.entry, required this.onRemove});

  final RosterObject entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final contact = entry.contact;
    final isEmail = contact.type == ContactType.EMAIL;

    return ListTile(
      leading: Icon(
        isEmail ? Icons.email_outlined : Icons.phone_outlined,
        size: 20,
        color: AppColors.tertiary,
      ),
      title: Text(contact.detail,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${contact.type.name} · Profile: ${entry.profileId}',
        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.verified)
            Icon(Icons.verified, size: 16, color: AppColors.success)
          else
            Icon(Icons.pending_outlined,
                size: 16, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
