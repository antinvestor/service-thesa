import 'package:antinvestor_api_common/antinvestor_api_common.dart' show STATE;
import 'package:antinvestor_api_device/antinvestor_api_device.dart'
    show DeviceObject;
import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../partition/widgets/state_badge.dart';
import '../data/device_repository.dart';
import '../data/profile_repository.dart';

/// Single profile detail provider.
final profileDetailProvider =
    FutureProvider.family<ProfileObject, String>((ref, profileId) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.getById(profileId);
});

/// Detail page for a single profile at /services/profile/profiles/:profileId.
///
/// Tabs: Overview | Contacts | Addresses | Devices | Relationships
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(profileDetailProvider(profileId)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (profile) =>
          _ProfileDetailContent(profile: profile, profileId: profileId),
    );
  }
}

class _ProfileDetailContent extends ConsumerWidget {
  const _ProfileDetailContent({
    required this.profile,
    required this.profileId,
  });

  final ProfileObject profile;
  final String profileId;

  String get _displayName {
    if (profile.hasProperties() &&
        profile.properties.fields.containsKey('name')) {
      return profile.properties.fields['name']!.stringValue;
    }
    return 'Profile $profileId';
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'Edit Profile',
      fields: [
        DialogField(
          key: 'state',
          label: 'State',
          initialValue: profile.state.name,
          type: DialogFieldType.dropdown,
          options: ['CREATED', 'ACTIVE', 'INACTIVE', 'DELETED'],
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final state = STATE.values
          .where((s) => s.name == values['state'])
          .firstOrNull;
      await repo.update(id: profileId, state: state);
      ref.invalidate(profileDetailProvider(profileId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
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
                _TypeBadge(profile.type.name),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Contacts'),
              Tab(text: 'Addresses'),
              Tab(text: 'Devices'),
              Tab(text: 'Relationships'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(profile: profile),
                _ContactsTab(profile: profile, profileId: profileId),
                _AddressesTab(profile: profile, profileId: profileId),
                _DevicesTab(profileId: profileId),
                _RelationshipsTab(profileId: profileId),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(title: 'Profile Details', rows: [
            ('ID', profile.id),
            ('Type', profile.type.name),
            ('State', profile.state.name),
            ('Contacts', '${profile.contacts.length}'),
            ('Addresses', '${profile.addresses.length}'),
          ]),
          if (profile.hasProperties() &&
              profile.properties.fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Properties',
              rows: profile.properties.fields.entries
                  .map((e) => (e.key, e.value.stringValue))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Contacts Tab ─────────────────────────────────────────────────────────────

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab({required this.profile, required this.profileId});

  final ProfileObject profile;
  final String profileId;

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'Add Contact',
      saveLabel: 'Add',
      fields: const [
        DialogField(
          key: 'contact',
          label: 'Contact (email or phone)',
          hint: 'e.g. user@example.com or +254712345678',
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.addContact(
        profileId: profileId,
        contact: values['contact'] ?? '',
      );
      ref.invalidate(profileDetailProvider(profileId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contact added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeContact(
      BuildContext context, WidgetRef ref, ContactObject contact) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Contact',
      message: 'Remove "${contact.detail}"?',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.removeContact(contact.id);
      ref.invalidate(profileDetailProvider(profileId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contact removed')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = profile.contacts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addContact(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contact'),
              ),
            ],
          ),
        ),
        if (contacts.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.contact_phone_outlined,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No contacts'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
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
                  subtitle: Text(
                      '${contact.type.name} · ${contact.verified ? "Verified" : "Unverified"}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceMuted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contact.verified)
                        Icon(Icons.verified,
                            size: 18, color: AppColors.success)
                      else
                        Icon(Icons.pending_outlined,
                            size: 18, color: AppColors.onSurfaceMuted),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        tooltip: 'Remove',
                        onPressed: () =>
                            _removeContact(context, ref, contact),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Addresses Tab ────────────────────────────────────────────────────────────

class _AddressesTab extends ConsumerWidget {
  const _AddressesTab({required this.profile, required this.profileId});

  final ProfileObject profile;
  final String profileId;

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'Add Address',
      saveLabel: 'Add',
      fields: const [
        DialogField(key: 'name', label: 'Address Name', hint: 'e.g. Home'),
        DialogField(key: 'country', label: 'Country'),
        DialogField(key: 'city', label: 'City'),
        DialogField(key: 'area', label: 'Area/District'),
        DialogField(key: 'street', label: 'Street'),
        DialogField(key: 'house', label: 'House/Building'),
        DialogField(key: 'postcode', label: 'Postal Code'),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.addAddress(
        profileId: profileId,
        address: AddressObject(
          name: values['name'] ?? '',
          country: values['country'] ?? '',
          city: values['city'] ?? '',
          area: values['area'] ?? '',
          street: values['street'] ?? '',
          house: values['house'] ?? '',
          postcode: values['postcode'] ?? '',
        ),
      );
      ref.invalidate(profileDetailProvider(profileId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Address added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = profile.addresses;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addAddress(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Address'),
              ),
            ],
          ),
        ),
        if (addresses.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No addresses'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final addr = addresses[index];
                final parts = [
                  addr.house,
                  addr.street,
                  addr.area,
                  addr.city,
                  addr.country,
                ].where((s) => s.isNotEmpty).join(', ');
                return ListTile(
                  leading: Icon(Icons.location_on_outlined,
                      size: 20, color: AppColors.tertiary),
                  title: Text(addr.name.isNotEmpty ? addr.name : 'Address',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(parts,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceMuted)),
                  trailing: addr.latitude != 0 || addr.longitude != 0
                      ? Tooltip(
                          message:
                              '${addr.latitude.toStringAsFixed(5)}, ${addr.longitude.toStringAsFixed(5)}',
                          child: Icon(Icons.my_location,
                              size: 16, color: AppColors.tertiary),
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Devices Tab ──────────────────────────────────────────────────────────────

class _DevicesTab extends ConsumerWidget {
  const _DevicesTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDevices = ref.watch(devicesForProfileProvider(profileId));

    return asyncDevices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load devices',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(devicesForProfileProvider(profileId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (devices) {
        if (devices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No devices linked to this profile'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            return _DeviceTile(device: device, profileId: profileId);
          },
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.profileId});

  final DeviceObject device;
  final String profileId;

  IconData get _icon {
    final ua = device.userAgent.toLowerCase();
    if (ua.contains('android')) return Icons.phone_android;
    if (ua.contains('iphone') || ua.contains('ios')) return Icons.phone_iphone;
    if (ua.contains('windows') || ua.contains('mac') || ua.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, size: 20, color: AppColors.tertiary),
      title: Text(
        device.name.isNotEmpty ? device.name : 'Device ${device.id}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        [
          if (device.os.isNotEmpty) device.os,
          if (device.ip.isNotEmpty) device.ip,
          if (device.lastSeen.isNotEmpty) 'Last: ${device.lastSeen}',
        ].join(' · '),
        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PresenceDot(device.presence.name),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceMuted),
        ],
      ),
      onTap: () => context.go(
          '/services/profile/profiles/$profileId/devices/${device.id}'),
    );
  }
}

// ─── Relationships Tab ────────────────────────────────────────────────────────

class _RelationshipsTab extends ConsumerWidget {
  const _RelationshipsTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Relationships require explicit query — show search UI
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_work_outlined,
              size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text('Relationships',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 8),
          Text(
              'Use the Relationships page to search and manage relationships.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/services/profile/relationships'),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Go to Relationships'),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'PERSON' => AppColors.tertiary,
      'INSTITUTION' => AppColors.primary,
      'BOT' => AppColors.onSurfaceMuted,
      _ => AppColors.onSurfaceMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ONLINE' => Colors.green,
      'AWAY' => Colors.orange,
      'BUSY' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              Padding(
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
              ),
          ],
        ),
      ),
    );
  }
}
