import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
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
  requiredPermissions: {'tenancy_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'tenants',
      label: 'Tenants',
      icon: Icons.domain_outlined,
      description: 'Manage tenant organizations',
      hasDetailPage: true,
      requiredPermissions: {'tenancy_view'},
    ),
    SubFeatureDefinition(
      id: 'partitions',
      label: 'Partitions',
      icon: Icons.account_tree_outlined,
      description: 'Manage data partitions',
      hasDetailPage: true,
      requiredPermissions: {'partition_view'},
    ),
  ],
);

/// Register the Tenancy Service with the global service registry.
void registerTenancyService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: tenancyServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'tenancy',
            title: 'Tenancy Analytics',
            metrics: [
              'total_tenants',
              'total_partitions',
              'active_users',
              'new_tenants',
            ],
            charts: [
              ChartConfig.timeSeries('tenant_growth',
                  label: 'Tenant Growth'),
              ChartConfig.distribution('tenants_by_plan',
                  groupBy: 'plan', label: 'By Plan'),
            ],
            tables: [
              TableConfig.topN('top_tenants',
                  label: 'Largest Tenants', limit: 10),
            ],
          ),
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
