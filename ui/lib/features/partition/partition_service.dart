import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/access_page.dart';
import 'pages/clients_page.dart';
import 'pages/partition_analytics_page.dart';
import 'pages/partition_detail_page.dart';
import 'pages/partitions_page.dart';
import 'pages/service_accounts_page.dart';
import 'pages/tenant_detail_page.dart';
import 'pages/tenants_page.dart';

/// Partition Service definition for the admin sidebar.
const tenancyServiceDef = ServiceDefinition(
  id: 'tenancy',
  label: 'Tenancy Service',
  icon: Icons.hub_outlined,
  description: 'Manage tenants, partitions, and access control',
  subFeatures: [
    SubFeatureDefinition(
      id: 'tenants',
      label: 'Tenants',
      icon: Icons.domain_outlined,
      description: 'Manage tenant organizations',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'partitions',
      label: 'Partitions',
      icon: Icons.account_tree_outlined,
      description: 'Manage data partitions',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'access',
      label: 'Access',
      icon: Icons.security_outlined,
      description: 'Manage profile access to partitions',
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

/// Register the Tenancy Service with the global service registry.
void registerTenancyService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: tenancyServiceDef,
      analyticsBuilder: (context, service) =>
          PartitionAnalyticsPage(service: service),
      featureBuilders: {
        'tenants': (context, service, feature) =>
            TenantsPage(service: service, feature: feature),
        'partitions': (context, service, feature) =>
            PartitionsPage(service: service, feature: feature),
        'access': (context, service, feature) =>
            AccessPage(service: service, feature: feature),
        'service-accounts': (context, service, feature) =>
            ServiceAccountsPage(service: service, feature: feature),
        'clients': (context, service, feature) =>
            ClientsPage(service: service, feature: feature),
      },
      detailBuilders: {
        'tenants': (context, service, feature, entityId) =>
            TenantDetailPage(tenantId: entityId),
        'partitions': (context, service, feature, entityId) =>
            PartitionDetailPage(partitionId: entityId),
      },
    ),
  );
}
