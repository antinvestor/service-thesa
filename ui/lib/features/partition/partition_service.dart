import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/partition_analytics_page.dart';
import 'pages/partition_detail_page.dart';
import 'pages/partitions_page.dart';
import 'pages/tenant_detail_page.dart';
import 'pages/tenants_page.dart';

/// Tenancy Service definition for the admin sidebar.
///
/// Only top-level entities (Tenants, Partitions) appear in the sidebar.
/// Child entities (Roles, Access, Service Accounts, Clients) are
/// discoverable as tabs within the Partition detail page.
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
