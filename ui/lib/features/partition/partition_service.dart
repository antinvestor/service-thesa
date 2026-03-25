import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/access_page.dart';
import 'pages/access_roles_page.dart';
import 'pages/clients_page.dart';
import 'pages/pages_page.dart';
import 'pages/partition_analytics_page.dart';
import 'pages/partition_roles_page.dart';
import 'pages/partitions_page.dart';
import 'pages/service_accounts_page.dart';
import 'pages/tenants_page.dart';

/// Partition Service definition for the admin sidebar.
const partitionServiceDef = ServiceDefinition(
  id: 'partition',
  label: 'Partition Service',
  icon: Icons.hub_outlined,
  description: 'Manage tenants, partitions, and access control',
  subFeatures: [
    SubFeatureDefinition(
      id: 'tenants',
      label: 'Tenants',
      icon: Icons.domain_outlined,
      description: 'Manage tenant organizations',
    ),
    SubFeatureDefinition(
      id: 'partitions',
      label: 'Partitions',
      icon: Icons.account_tree_outlined,
      description: 'Manage data partitions',
    ),
    SubFeatureDefinition(
      id: 'roles',
      label: 'Partition Roles',
      icon: Icons.badge_outlined,
      description: 'Manage partition role definitions',
    ),
    SubFeatureDefinition(
      id: 'pages',
      label: 'Pages',
      icon: Icons.web_outlined,
      description: 'Manage partition pages',
    ),
    SubFeatureDefinition(
      id: 'access',
      label: 'Access',
      icon: Icons.security_outlined,
      description: 'Manage profile access to partitions',
    ),
    SubFeatureDefinition(
      id: 'access-roles',
      label: 'Access Roles',
      icon: Icons.admin_panel_settings_outlined,
      description: 'Assign roles to access grants',
    ),
    SubFeatureDefinition(
      id: 'service-accounts',
      label: 'Service Accounts',
      icon: Icons.engineering_outlined,
      description: 'Manage service accounts',
    ),
    SubFeatureDefinition(
      id: 'clients',
      label: 'Clients',
      icon: Icons.key_outlined,
      description: 'Manage OAuth2 clients',
    ),
  ],
);

/// Register the Partition Service with the global service registry.
void registerPartitionService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: partitionServiceDef,
      analyticsBuilder: (context, service) =>
          PartitionAnalyticsPage(service: service),
      featureBuilders: {
        'tenants': (context, service, feature) =>
            TenantsPage(service: service, feature: feature),
        'partitions': (context, service, feature) =>
            PartitionsPage(service: service, feature: feature),
        'roles': (context, service, feature) =>
            PartitionRolesPage(service: service, feature: feature),
        'pages': (context, service, feature) =>
            PagesPage(service: service, feature: feature),
        'access': (context, service, feature) =>
            AccessPage(service: service, feature: feature),
        'access-roles': (context, service, feature) =>
            AccessRolesPage(service: service, feature: feature),
        'service-accounts': (context, service, feature) =>
            ServiceAccountsPage(service: service, feature: feature),
        'clients': (context, service, feature) =>
            ClientsPage(service: service, feature: feature),
      },
    ),
  );
}
