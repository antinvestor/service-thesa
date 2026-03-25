import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../partition/widgets/async_entity_list.dart';
import '../../partition/widgets/state_badge.dart';
import '../data/profile_providers.dart';

/// A contact entry paired with the owning profile's ID.
typedef ProfileContact = ({String profileId, ContactObject contact});

/// Provider that extracts all contacts from loaded profiles into a flat list.
final contactsProvider =
    FutureProvider.autoDispose<List<ProfileContact>>((ref) async {
  final profiles = await ref.watch(profilesProvider.future);
  final contacts = <ProfileContact>[];
  for (final profile in profiles) {
    for (final contact in profile.contacts) {
      contacts.add((profileId: profile.id, contact: contact));
    }
  }
  return contacts;
});

class ContactsPage extends ConsumerWidget {
  const ContactsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<ProfileContact>(
      dataProvider: contactsProvider,
      title: 'Contacts',
      breadcrumbs: ['Services', service.label, 'Contacts'],
      searchHint: 'Search contacts...',
      columns: const [
        DataColumn(label: Text('DETAIL')),
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('VERIFIED')),
        DataColumn(label: Text('PROFILE ID')),
        DataColumn(label: Text('STATE')),
      ],
      rowBuilder: (entry, selected, onSelect) {
        final contact = entry.contact;
        final typeLabel = contact.type.name;
        final typeColor = switch (contact.type) {
          ContactType.EMAIL => AppColors.tertiary,
          ContactType.MSISDN => AppColors.success,
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
                Icon(
                  contact.type == ContactType.EMAIL
                      ? Icons.email_outlined
                      : Icons.phone_outlined,
                  size: 16,
                  color: typeColor,
                ),
                const SizedBox(width: 8),
                Text(contact.detail),
              ],
            )),
            DataCell(ColorBadge(typeLabel, typeColor)),
            DataCell(Icon(
              contact.verified ? Icons.check_circle : Icons.cancel_outlined,
              size: 18,
              color: contact.verified ? AppColors.success : AppColors.onSurfaceMuted,
            )),
            DataCell(Text(
              entry.profileId.length >= 8
                  ? entry.profileId.substring(0, 8)
                  : entry.profileId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            )),
            DataCell(StateBadge(contact.state)),
          ],
        );
      },
      detailBuilder: (entry) => _ContactDetail(entry: entry),
      onRefresh: () => ref.invalidate(profilesProvider),
    );
  }
}

// ─── Detail Panel ────────────────────────────────────────────────────────────

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({required this.entry});

  final ProfileContact entry;

  @override
  Widget build(BuildContext context) {
    final contact = entry.contact;
    final typeColor = switch (contact.type) {
      ContactType.EMAIL => AppColors.tertiary,
      ContactType.MSISDN => AppColors.success,
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
              child: Icon(
                contact.type == ContactType.EMAIL
                    ? Icons.email_outlined
                    : Icons.phone_outlined,
                color: typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.detail,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(contact.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(label: 'Type', value: contact.type.name),
        _DetailRow(
            label: 'Verified', value: contact.verified ? 'Yes' : 'No'),
        _DetailRow(
            label: 'Communication',
            value: contact.communicationLevel.name),
        _DetailRow(label: 'State', value: contact.state.name),
        _DetailRow(label: 'Profile ID', value: entry.profileId),
      ],
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
