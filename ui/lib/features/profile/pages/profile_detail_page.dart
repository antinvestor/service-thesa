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
/// Tabs: Overview | Contacts | Addresses | Devices | Roster
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
      return profile.properties.fields['au_name']!.stringValue;
    }
    return 'Profile $profileId';
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final currentName = profile.hasProperties() &&
            profile.properties.fields.containsKey('name')
        ? profile.properties.fields['au_name']!.stringValue
        : '';
    final values = await showEditDialog(
      context: context,
      title: 'Edit Profile',
      fields: [
        DialogField(
          key: 'name',
          label: 'Display Name',
          initialValue: currentName,
        ),
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
      final name = values['name'] ?? '';
      Struct? properties;
      if (name.isNotEmpty) {
        properties = Struct(fields: {
          'name': Value(stringValue: name),
        });
      }
      await repo.update(id: profileId, state: state, properties: properties);
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
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StateBadge(profile.state),
                _TypeBadge(profile.type.name),
                SelectableText('ID: ${profile.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (profile.contacts.isNotEmpty)
                  Text(
                    '${profile.contacts.length} contact${profile.contacts.length == 1 ? '' : 's'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                if (profile.addresses.isNotEmpty)
                  Text(
                    '${profile.addresses.length} address${profile.addresses.length == 1 ? '' : 'es'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted),
                  ),
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
              Tab(text: 'Roster'),
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
                _RosterTab(profileId: profileId),
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

  String get _displayName {
    if (profile.hasProperties() &&
        profile.properties.fields.containsKey('name')) {
      final n = profile.properties.fields['au_name']!;
      if (n.hasStringValue() && n.stringValue.isNotEmpty) return n.stringValue;
    }
    if (profile.contacts.isNotEmpty) return profile.contacts.first.detail;
    return profile.id;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile details + properties side by side
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final detailCard = _buildCard(
              context,
              title: 'Profile Details',
              icon: Icons.person_outlined,
              child: Column(children: [
                _OvRow('Name', _displayName),
                _OvRow('Type', profile.type.name),
                _OvRow('State', profile.state.name),
                _OvRow('ID', profile.id),
              ]),
            );

            final propCard = (profile.hasProperties() &&
                    profile.properties.fields.isNotEmpty)
                ? _buildCard(
                    context,
                    title: 'Properties',
                    icon: Icons.data_object,
                    child: Column(
                      children: [
                        for (final e in profile.properties.fields.entries)
                          _OvRow(e.key, _fmtValue(e.value)),
                      ],
                    ),
                  )
                : null;

            if (wide && propCard != null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: detailCard),
                  const SizedBox(width: 16),
                  Expanded(child: propCard),
                ],
              );
            }
            return Column(children: [
              detailCard,
              if (propCard != null) ...[const SizedBox(height: 16), propCard],
            ]);
          }),
          const SizedBox(height: 16),

          // Contacts summary
          if (profile.contacts.isNotEmpty)
            _buildCard(
              context,
              title: 'Contacts (${profile.contacts.length})',
              icon: Icons.contact_phone_outlined,
              child: Column(
                children: [
                  for (final c in profile.contacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            c.type == ContactType.EMAIL
                                ? Icons.email_outlined
                                : Icons.phone_outlined,
                            size: 16,
                            color: AppColors.onSurfaceMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.detail,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                          ),
                          if (c.verified)
                            Icon(Icons.verified,
                                size: 14, color: AppColors.success)
                          else
                            Icon(Icons.pending_outlined,
                                size: 14,
                                color: AppColors.onSurfaceMuted),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (profile.contacts.isNotEmpty) const SizedBox(height: 16),

          // Addresses summary
          if (profile.addresses.isNotEmpty)
            _buildCard(
              context,
              title: 'Addresses (${profile.addresses.length})',
              icon: Icons.location_on_outlined,
              child: Column(
                children: [
                  for (final a in profile.addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.onSurfaceMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                if (a.name.isNotEmpty) a.name,
                                if (a.city.isNotEmpty) a.city,
                                if (a.country.isNotEmpty) a.country,
                              ].join(', '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtValue(Value v) {
    if (v.hasStringValue()) return v.stringValue;
    if (v.hasBoolValue()) return v.boolValue ? 'true' : 'false';
    if (v.hasNumberValue()) return v.numberValue.toString();
    if (v.hasStructValue()) {
      return v.structValue.fields.entries
          .map((e) => '${e.key}: ${_fmtValue(e.value)}')
          .join(', ');
    }
    return '—';
  }

  Widget _buildCard(BuildContext context,
      {required String title, required IconData icon, required Widget child}) {
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
            Row(children: [
              Icon(icon, size: 18, color: AppColors.tertiary),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _OvRow extends StatelessWidget {
  const _OvRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
            child: SelectableText(value,
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

  Future<void> _verifyContact(
      BuildContext context, WidgetRef ref, ContactObject contact) async {
    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      // Step 1: Create verification (sends code)
      final verification = await repo.createContactVerification(
        profileId: profileId,
        contactId: contact.id,
      );
      if (!context.mounted) return;

      // Step 2: Ask user for the code
      final values = await showEditDialog(
        context: context,
        title: 'Verify ${contact.detail}',
        saveLabel: 'Verify',
        fields: [
          DialogField(
            key: 'code',
            label: 'Verification Code',
            hint: 'Enter the code sent to ${contact.detail}',
          ),
        ],
      );
      if (values == null || !context.mounted) return;

      // Step 3: Check verification
      final result = await repo.checkVerification(
        verificationId: verification.id,
        code: values['code'] ?? '',
      );
      ref.invalidate(profileDetailProvider(profileId));
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact verified successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Verification failed (${result.checkAttempts} attempts)')),
          );
        }
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
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ExpansionTile(
                  leading: Icon(
                    contact.type == ContactType.EMAIL
                        ? Icons.email_outlined
                        : Icons.phone_outlined,
                    size: 20,
                    color: AppColors.tertiary,
                  ),
                  title: Text(contact.detail,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(contact.type.name,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceMuted)),
                      const SizedBox(width: 8),
                      if (contact.verified)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.verified,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success)),
                        ])
                      else
                        Text('Unverified',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!contact.verified)
                        TextButton.icon(
                          onPressed: () =>
                              _verifyContact(context, ref, contact),
                          icon: const Icon(Icons.verified_outlined,
                              size: 16),
                          label: const Text('Verify',
                              style: TextStyle(fontSize: 12)),
                        ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        tooltip: 'Remove',
                        onPressed: () =>
                            _removeContact(context, ref, contact),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OvRow('Contact ID', contact.id),
                          _OvRow('Type', contact.type.name),
                          _OvRow('Detail', contact.detail),
                          _OvRow('Verified',
                              contact.verified ? 'Yes' : 'No'),
                          _OvRow('State', contact.state.name),
                        ],
                      ),
                    ),
                  ],
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
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final addr = addresses[index];
                final parts = [
                  addr.city,
                  addr.country,
                ].where((s) => s.isNotEmpty).join(', ');
                return ExpansionTile(
                  leading: Icon(Icons.location_on_outlined,
                      size: 20, color: AppColors.tertiary),
                  title: Text(
                      addr.name.isNotEmpty ? addr.name : 'Address',
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(parts.isNotEmpty ? parts : '—',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceMuted)),
                  trailing: addr.latitude != 0 || addr.longitude != 0
                      ? Tooltip(
                          message:
                              '${addr.latitude.toStringAsFixed(5)}, ${addr.longitude.toStringAsFixed(5)}',
                          child: Icon(Icons.my_location,
                              size: 16, color: AppColors.tertiary),
                        )
                      : null,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (addr.name.isNotEmpty)
                            _OvRow('Name', addr.name),
                          if (addr.house.isNotEmpty)
                            _OvRow('House', addr.house),
                          if (addr.street.isNotEmpty)
                            _OvRow('Street', addr.street),
                          if (addr.area.isNotEmpty)
                            _OvRow('Area', addr.area),
                          if (addr.city.isNotEmpty)
                            _OvRow('City', addr.city),
                          if (addr.country.isNotEmpty)
                            _OvRow('Country', addr.country),
                          if (addr.postcode.isNotEmpty)
                            _OvRow('Postcode', addr.postcode),
                          if (addr.latitude != 0 || addr.longitude != 0)
                            _OvRow('Coordinates',
                                '${addr.latitude.toStringAsFixed(5)}, ${addr.longitude.toStringAsFixed(5)}'),
                        ],
                      ),
                    ),
                  ],
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
          separatorBuilder: (_, _) => const Divider(height: 1),
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

// ─── Roster Tab ──────────────────────────────────────────────────────────────

/// Provider for roster entries of a profile.
final _rosterProvider =
    FutureProvider.family<List<RosterObject>, String>(
        (ref, profileId) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.searchRoster(profileId: profileId);
});

class _RosterTab extends ConsumerWidget {
  const _RosterTab({required this.profileId});

  final String profileId;

  Future<void> _removeEntry(
      BuildContext context, WidgetRef ref, RosterObject entry) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove Roster Entry',
      message: 'Remove "${entry.contact.detail}" from roster?',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.removeRoster(entry.id);
      ref.invalidate(_rosterProvider(profileId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roster entry removed')),
        );
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
    final asyncRoster = ref.watch(_rosterProvider(profileId));

    return asyncRoster.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load roster'),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(_rosterProvider(profileId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (entries) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text('${entries.length} roster entries',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(_rosterProvider(profileId)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.contacts_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No roster entries'),
                    SizedBox(height: 4),
                    Text(
                      'Roster entries are synced from the user\'s contact book',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final contact = entry.contact;
                  return ExpansionTile(
                    leading: Icon(
                      contact.type == ContactType.EMAIL
                          ? Icons.email_outlined
                          : Icons.phone_outlined,
                      size: 20,
                      color: AppColors.tertiary,
                    ),
                    title: Text(contact.detail,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(contact.type.name,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceMuted)),
                        const SizedBox(width: 8),
                        if (contact.verified)
                          Icon(Icons.verified,
                              size: 14, color: AppColors.success)
                        else
                          Icon(Icons.pending_outlined,
                              size: 14,
                              color: AppColors.onSurfaceMuted),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      tooltip: 'Remove',
                      onPressed: () =>
                          _removeEntry(context, ref, entry),
                    ),
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OvRow('Roster ID', entry.id),
                            _OvRow('Profile ID', entry.profileId),
                            _OvRow('Contact', contact.detail),
                            _OvRow('Type', contact.type.name),
                            _OvRow('Verified',
                                contact.verified ? 'Yes' : 'No'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
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

