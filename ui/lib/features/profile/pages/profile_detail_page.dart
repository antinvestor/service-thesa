import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/profile_repository.dart';
import '../../partition/widgets/state_badge.dart';

/// Single profile detail provider.
final profileDetailProvider =
    FutureProvider.family<ProfileObject, String>((ref, profileId) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.getById(profileId);
});

/// Detail page for a single profile, shown at
/// /services/profile/profiles/:profileId.
///
/// Tabs: Overview | Contacts | Relationships
class ProfileDetailPage extends ConsumerWidget {
  const ProfileDetailPage({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileDetailProvider(profileId));

    return asyncProfile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load profile',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (profile) => _ProfileDetailContent(profile: profile),
    );
  }
}

class _ProfileDetailContent extends StatelessWidget {
  const _ProfileDetailContent({required this.profile});

  final ProfileObject profile;

  String get _displayName {
    if (profile.hasProperties() &&
        profile.properties.fields.containsKey('name')) {
      return profile.properties.fields['name']!.stringValue;
    }
    return profile.id;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: _displayName,
              breadcrumbs: [
                'Services',
                'Profile Service',
                'Profiles',
                _displayName,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/services/profile/profiles'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                StateBadge(profile.state),
                const SizedBox(width: 12),
                Text('ID: ${profile.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                const SizedBox(width: 12),
                Text('Type: ${profile.type.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Contacts'),
              Tab(text: 'Relationships'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(profile: profile),
                _ContactsTab(profile: profile),
                _RelationshipsTab(profileId: profile.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile});

  final ProfileObject profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _row(context, 'ID', profile.id),
              _row(context, 'Type', profile.type.name),
              _row(context, 'State', profile.state.name),
              _row(context, 'Contacts',
                  '${profile.contacts.length} contact(s)'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

// ─── Contacts Tab ─────────────────────────────────────────────────────────────

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({required this.profile});

  final ProfileObject profile;

  @override
  Widget build(BuildContext context) {
    final contacts = profile.contacts;
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_phone_outlined,
                size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 12),
            Text('No contacts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return ListTile(
          leading: Icon(
            contact.type.name.contains('EMAIL')
                ? Icons.email_outlined
                : Icons.phone_outlined,
            size: 20,
            color: AppColors.tertiary,
          ),
          title: Text(contact.detail,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(contact.type.name,
              style: TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceMuted)),
          trailing: contact.verified
              ? Icon(Icons.verified, size: 18, color: AppColors.success)
              : Icon(Icons.pending_outlined,
                  size: 18, color: AppColors.onSurfaceMuted),
        );
      },
    );
  }
}

// ─── Relationships Tab ────────────────────────────────────────────────────────

class _RelationshipsTab extends ConsumerWidget {
  const _RelationshipsTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Relationships require a query — show a prompt to search
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_work_outlined,
              size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text('Relationships for this profile',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 8),
          Text('Use the search to find relationships',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }
}
