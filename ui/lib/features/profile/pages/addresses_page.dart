import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../partition/widgets/async_entity_list.dart';
import '../data/profile_providers.dart';

/// An address entry paired with the owning profile's ID and name.
typedef ProfileAddress = ({
  String profileId,
  String profileName,
  AddressObject address,
});

/// Provider that extracts all addresses from loaded profiles into a flat list.
final addressesProvider =
    FutureProvider<List<ProfileAddress>>((ref) async {
  final profiles = await ref.watch(profilesProvider.future);
  final addresses = <ProfileAddress>[];
  for (final profile in profiles) {
    final name = _profileName(profile);
    for (final address in profile.addresses) {
      addresses.add((
        profileId: profile.id,
        profileName: name,
        address: address,
      ));
    }
  }
  return addresses;
});

String _profileName(ProfileObject profile) {
  if (profile.hasProperties() &&
      profile.properties.fields.containsKey('name')) {
    final n = profile.properties.fields['name']!;
    if (n.hasStringValue() && n.stringValue.isNotEmpty) return n.stringValue;
  }
  if (profile.contacts.isNotEmpty) return profile.contacts.first.detail;
  return profile.id.length >= 8
      ? 'Profile ${profile.id.substring(0, 8)}'
      : profile.id;
}

class AddressesPage extends ConsumerWidget {
  const AddressesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncEntityList<ProfileAddress>(
      dataProvider: addressesProvider,
      title: 'Addresses',
      breadcrumbs: ['Services', service.label, 'Addresses'],
      searchHint: 'Search addresses...',
      exportRow: (pa) => [
        pa.address.name,
        pa.address.city,
        pa.address.country,
        pa.profileName,
        pa.profileId,
      ],
      columns: const [
        DataColumn(label: Text('NAME')),
        DataColumn(label: Text('LOCATION')),
        DataColumn(label: Text('PROFILE')),
      ],
      rowBuilder: (pa, selected, onSelect) {
        final parts = [
          pa.address.city,
          pa.address.country,
        ].where((s) => s.isNotEmpty).join(', ');

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
                Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(pa.address.name.isNotEmpty ? pa.address.name : 'Address',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            )),
            DataCell(Text(parts.isNotEmpty ? parts : '—')),
            DataCell(Text(pa.profileName,
                style: const TextStyle(fontSize: 12))),
          ],
        );
      },
      detailBuilder: (pa) => _AddressDetail(pa: pa),
      onRefresh: () => ref.invalidate(addressesProvider),
    );
  }
}

class _AddressDetail extends StatelessWidget {
  const _AddressDetail({required this.pa});
  final ProfileAddress pa;

  @override
  Widget build(BuildContext context) {
    final addr = pa.address;
    final fullAddress = [
      addr.house,
      addr.street,
      addr.area,
      addr.city,
      addr.country,
      addr.postcode,
    ].where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on_outlined,
                  size: 24, color: AppColors.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr.name.isNotEmpty ? addr.name : 'Address',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(pa.profileName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Row('Address', fullAddress.isNotEmpty ? fullAddress : '—'),
        if (addr.street.isNotEmpty) _Row('Street', addr.street),
        if (addr.area.isNotEmpty) _Row('Area', addr.area),
        if (addr.city.isNotEmpty) _Row('City', addr.city),
        if (addr.country.isNotEmpty) _Row('Country', addr.country),
        if (addr.postcode.isNotEmpty) _Row('Postcode', addr.postcode),
        _Row('Profile ID', pa.profileId),
        if (addr.latitude != 0 || addr.longitude != 0)
          _Row('Coordinates',
              '${addr.latitude.toStringAsFixed(5)}, ${addr.longitude.toStringAsFixed(5)}'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
