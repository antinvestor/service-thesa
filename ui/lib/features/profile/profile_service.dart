import 'package:antinvestor_ui_profile/antinvestor_ui_profile.dart'
    as profile_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Profile Service definition for the admin sidebar.
///
/// All profile screens are now provided by the antinvestor_ui_profile library.
const profileServiceDef = ServiceDefinition(
  id: 'profile',
  label: 'Profile Service',
  icon: Icons.people_outlined,
  description: 'Manage profiles, contacts, addresses, relationships, and devices',
  subFeatures: [
    SubFeatureDefinition(
      id: 'profiles',
      label: 'Profiles',
      icon: Icons.person_outlined,
      description: 'Search and manage profiles',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'contacts',
      label: 'Contacts',
      icon: Icons.contact_phone_outlined,
      description: 'View contacts across all profiles',
    ),
    SubFeatureDefinition(
      id: 'addresses',
      label: 'Addresses',
      icon: Icons.location_on_outlined,
      description: 'View addresses across all profiles',
    ),
    SubFeatureDefinition(
      id: 'roster',
      label: 'Roster',
      icon: Icons.contacts_outlined,
      description: 'Search and manage profile rosters',
    ),
    SubFeatureDefinition(
      id: 'relationships',
      label: 'Relationships',
      icon: Icons.people_alt_outlined,
      description: 'Manage profile relationships (members, affiliations)',
    ),
    SubFeatureDefinition(
      id: 'merge',
      label: 'Merge Profiles',
      icon: Icons.merge_outlined,
      description: 'Merge duplicate profiles into one',
    ),
    SubFeatureDefinition(
      id: 'devices',
      label: 'Devices',
      icon: Icons.devices_outlined,
      description: 'View and manage linked devices',
      hasDetailPage: true,
    ),
  ],
);

/// Register the Profile Service with the global service registry.
void registerProfileService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: profileServiceDef,
      analyticsBuilder: (context, service) =>
          const profile_lib.ProfileAnalyticsScreen(),
      featureBuilders: {
        // All screens from antinvestor_ui_profile library
        'profiles': (context, service, feature) =>
            const profile_lib.ProfileSearchScreen(),
        'contacts': (context, service, feature) =>
            const profile_lib.ContactsScreen(),
        'addresses': (context, service, feature) =>
            const profile_lib.AddressesScreen(),
        'roster': (context, service, feature) =>
            const profile_lib.RosterScreen(profileId: ''),
        'relationships': (context, service, feature) =>
            const profile_lib.RelationshipsScreen(profileId: ''),
        'merge': (context, service, feature) =>
            const profile_lib.ProfileMergeScreen(),
        // Screens from antinvestor_ui_device library
        'devices': (context, service, feature) =>
            const profile_lib.ProfileSearchScreen(),
      },
      detailBuilders: {
        'profiles': (context, service, feature, entityId) =>
            profile_lib.ProfileDetailScreen(profileId: entityId),
        'devices': (context, service, feature, entityId) =>
            profile_lib.ProfileDetailScreen(profileId: entityId),
      },
    ),
  );
}
