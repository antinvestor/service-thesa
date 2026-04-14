import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/search_provider.dart';
import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/entity_list_page.dart';
import '../../partition/widgets/state_badge.dart';
import '../data/profile_providers.dart';
import '../data/profile_repository.dart';
import '../widgets/profile_badge.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(globalSearchQueryProvider);
    final asyncData = ref.watch(profilesProvider(query));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load profiles',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(profilesProvider(query)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) => EntityListPage<ProfileObject>(
        title: 'Profiles',
        breadcrumbs: ['Services', service.label, 'Profiles'],
        items: items,
        addLabel: 'New Profile',
        onAdd: () => _createProfile(context, ref, query),
        exportRow: (profile) => [
          profileDisplayName(profile),
          profile.type.name,
          '${profile.contacts.length}',
          profile.state.name,
        ],
        columns: const [
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('TYPE')),
          DataColumn(label: Text('CONTACTS'), numeric: true),
          DataColumn(label: Text('STATE')),
        ],
        rowBuilder: (profile, selected, onSelect) {
          final name = profileDisplayName(profile);
          final typeLabel = profile.type.name;
          final typeColor = switch (profile.type) {
            ProfileType.PERSON => AppColors.tertiary,
            ProfileType.INSTITUTION => AppColors.success,
            ProfileType.BOT => AppColors.warning,
            _ => AppColors.onSurfaceMuted,
          };

          return DataRow(
            selected: selected,
            onSelectChanged: (_) => onSelect(),
            color: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.tertiary.withValues(alpha: 0.05);
              }
              return null;
            }),
            cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: typeColor.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(name),
                ],
              )),
              DataCell(ColorBadge(typeLabel, typeColor)),
              DataCell(Text('${profile.contacts.length}')),
              DataCell(StateBadge(profile.state)),
            ],
          );
        },
        detailBuilder: (profile) => _ProfileDetail(profile: profile),
        editFields: const [
          EditField(
            label: 'State',
            key: 'state',
            type: EditFieldType.dropdown,
            options: ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED'],
          ),
        ],
        editTitle: (profile) => 'Edit ${profileDisplayName(profile)}',
        editValuesExtractor: (profile) => {
          'state': profile.state.name,
        },
        onSave: (profile, values) {
          debugPrint('Save profile: $values');
        },
        onRowNavigate: (profile) =>
            context.go('/services/profile/profiles/${profile.id}'),
      ),
    );
  }

  Future<void> _createProfile(
      BuildContext context, WidgetRef ref, String query) async {
    final values = await showEditDialog(
      context: context,
      title: 'New Profile',
      saveLabel: 'Create',
      fields: const [
        DialogField(
          key: 'type',
          label: 'Profile Type',
          type: DialogFieldType.dropdown,
          options: ['PERSON', 'INSTITUTION', 'BOT'],
          initialValue: 'PERSON',
        ),
        DialogField(
          key: 'contact',
          label: 'Contact (email or phone)',
          hint: 'e.g. user@example.com or +254712345678',
        ),
        DialogField(key: 'name', label: 'Name (optional)'),
      ],
    );
    if (values == null || !context.mounted) return;
    try {
      final typeStr = values['type'] ?? 'PERSON';
      final type = ProfileType.values
              .where((t) => t.name == typeStr)
              .firstOrNull ??
          ProfileType.PERSON;
      final name = values['name'] ?? '';
      Struct? properties;
      if (name.isNotEmpty) {
        properties = Struct(fields: {
          'name': Value(stringValue: name),
        });
      }
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.create(
        type: type,
        contact: values['contact'] ?? '',
        properties: properties,
      );
      ref.invalidate(profilesProvider(query));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.profile});

  final ProfileObject profile;

  @override
  Widget build(BuildContext context) {
    final name = profileDisplayName(profile);
    final typeColor = switch (profile.type) {
      ProfileType.PERSON => AppColors.tertiary,
      ProfileType.INSTITUTION => AppColors.success,
      ProfileType.BOT => AppColors.warning,
      _ => AppColors.onSurfaceMuted,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: typeColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(profile.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Type', value: profile.type.name),
        _DetailRow(label: 'State', value: profile.state.name),
        const SizedBox(height: 16),
        // Contacts
        if (profile.contacts.isNotEmpty) ...[
          Text('Contacts',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          for (final contact in profile.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    contact.type == ContactType.EMAIL
                        ? Icons.email_outlined
                        : Icons.phone_outlined,
                    size: 16,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(contact.detail,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  if (contact.verified)
                    const Icon(Icons.verified,
                        size: 14, color: AppColors.success),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
        // Addresses
        if (profile.addresses.isNotEmpty) ...[
          Text('Addresses',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          for (final address in profile.addresses)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatAddress(address),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _formatAddress(AddressObject address) {
    final parts = <String>[
      if (address.name.isNotEmpty) address.name,
      if (address.street.isNotEmpty) address.street,
      if (address.area.isNotEmpty) address.area,
      if (address.city.isNotEmpty) address.city,
      if (address.country.isNotEmpty) address.country,
      if (address.postcode.isNotEmpty) address.postcode,
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'N/A';
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
