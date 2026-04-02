import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/profile_analytics_page.dart';
import 'pages/profile_detail_page.dart';
import 'pages/profiles_page.dart';
import 'pages/relationships_page.dart';

/// Profile Service definition for the admin sidebar.
const profileServiceDef = ServiceDefinition(
  id: 'profile',
  label: 'Profile Service',
  icon: Icons.people_outlined,
  description: 'Manage profiles, contacts, and relationships',
  subFeatures: [
    SubFeatureDefinition(
      id: 'profiles',
      label: 'Profiles',
      icon: Icons.person_outlined,
      description: 'Search and manage profiles',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'relationships',
      label: 'Relationships',
      icon: Icons.group_work_outlined,
      description: 'Manage relationships between profiles',
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
        'relationships': (context, service, feature) =>
            RelationshipsPage(service: service, feature: feature),
      },
      detailBuilders: {
        'profiles': (context, service, feature, entityId) =>
            ProfileDetailPage(profileId: entityId),
      },
    ),
  );
}
