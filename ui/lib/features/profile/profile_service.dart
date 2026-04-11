import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
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
  requiredPermissions: {'profile_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'profiles',
      label: 'Profiles',
      icon: Icons.person_outlined,
      description: 'Search and manage profiles',
      hasDetailPage: true,
      requiredPermissions: {'profile_view'},
    ),
    SubFeatureDefinition(
      id: 'contacts',
      label: 'Contacts',
      icon: Icons.contact_phone_outlined,
      description: 'View contacts across all profiles',
      requiredPermissions: {'contact_manage'},
    ),
    SubFeatureDefinition(
      id: 'addresses',
      label: 'Addresses',
      icon: Icons.location_on_outlined,
      description: 'View addresses across all profiles',
      requiredPermissions: {'address_manage'},
    ),
    SubFeatureDefinition(
      id: 'roster',
      label: 'Roster',
      icon: Icons.contacts_outlined,
      description: 'Search and manage profile rosters',
      requiredPermissions: {'roster_view'},
    ),
    SubFeatureDefinition(
      id: 'relationships',
      label: 'Relationships',
      icon: Icons.people_alt_outlined,
      description: 'Manage profile relationships (members, affiliations)',
      requiredPermissions: {'relationship_view'},
    ),
    SubFeatureDefinition(
      id: 'merge',
      label: 'Merge Profiles',
      icon: Icons.merge_outlined,
      description: 'Merge duplicate profiles into one',
      requiredPermissions: {'profile_merge'},
    ),
    SubFeatureDefinition(
      id: 'devices',
      label: 'Devices',
      icon: Icons.devices_outlined,
      description: 'View and manage linked devices',
      hasDetailPage: true,
      requiredPermissions: {'device_view'},
    ),
  ],
);

/// Register the Profile Service with the global service registry.
void registerProfileService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: profileServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'profile',
            title: 'Profile Analytics',
            metrics: [
              'total_profiles',
              'active_profiles',
              'new_registrations',
              'verification_rate',
            ],
            charts: [
              ChartConfig.timeSeries('registrations',
                  label: 'Registrations Over Time'),
              ChartConfig.distribution('profile_types',
                  groupBy: 'profile_type', label: 'By Type'),
            ],
            tables: [
              TableConfig.topN('top_active_profiles',
                  label: 'Most Active Profiles', limit: 10),
            ],
          ),
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
