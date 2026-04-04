import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/addresses_page.dart';
import 'pages/contacts_page.dart';
import 'pages/profile_analytics_page.dart';
import 'pages/profile_detail_page.dart';
import 'pages/profiles_page.dart';
import 'pages/roster_page.dart';

/// Profile Service definition for the admin sidebar.
const profileServiceDef = ServiceDefinition(
  id: 'profile',
  label: 'Profile Service',
  icon: Icons.people_outlined,
  description: 'Manage profiles, contacts, addresses, and rosters',
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
  ],
);

/// Register the Profile Service with the global service registry.
void registerProfileService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: profileServiceDef,
      analyticsBuilder: (context, service) =>
          ProfileAnalyticsPage(service: service),
      featureBuilders: {
        'profiles': (context, service, feature) =>
            ProfilesPage(service: service, feature: feature),
        'contacts': (context, service, feature) =>
            ContactsPage(service: service, feature: feature),
        'addresses': (context, service, feature) =>
            AddressesPage(service: service, feature: feature),
        'roster': (context, service, feature) =>
            RosterPage(service: service, feature: feature),
      },
      detailBuilders: {
        'profiles': (context, service, feature, entityId) =>
            ProfileDetailPage(profileId: entityId),
      },
    ),
  );
}
