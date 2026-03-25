import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/entity_list_page.dart';
import '../../partition/widgets/async_entity_list.dart';
import '../../partition/widgets/state_badge.dart';
import '../data/profile_providers.dart';

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
    return AsyncEntityList<ProfileObject>(
      dataProvider: profilesProvider,
      title: 'Profiles',
      breadcrumbs: ['Services', service.label, 'Profiles'],
      searchHint: 'Search profiles...',
      columns: const [
        DataColumn(label: Text('NAME')),
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('CONTACTS'), numeric: true),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (profile, selected, onSelect) {
        final name = _profileDisplayName(profile);
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
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
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
          options: ['ACTIVE', 'INACTIVE', 'DELETED'],
        ),
      ],
      editTitle: (profile) => 'Edit ${_profileDisplayName(profile)}',
      editValuesExtractor: (profile) => {
        'state': profile.state.name,
      },
      onSave: (profile, values) {
        debugPrint('Save profile: $values');
      },
      onRefresh: () => ref.invalidate(profilesProvider),
    );
  }
}

/// Extract a display name from a profile.
///
/// Tries the 'name' field in properties, then the first contact detail,
/// then falls back to a truncated ID.
String _profileDisplayName(ProfileObject profile) {
  // Try properties.fields['name']
  final nameField = profile.properties.fields['name'];
  if (nameField != null && nameField.hasStringValue()) {
    final name = nameField.stringValue;
    if (name.isNotEmpty) return name;
  }

  // Try first contact detail
  if (profile.contacts.isNotEmpty) {
    final detail = profile.contacts.first.detail;
    if (detail.isNotEmpty) return detail;
  }

  // Fallback to ID prefix
  if (profile.id.length >= 8) {
    return 'Profile ${profile.id.substring(0, 8)}';
  }
  return 'Profile ${profile.id}';
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.profile});

  final ProfileObject profile;

  @override
  Widget build(BuildContext context) {
    final name = _profileDisplayName(profile);
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
                    const Icon(Icons.verified, size: 14, color: AppColors.success),
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
