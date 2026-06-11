import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_fort/antinvestor_ui_fort.dart' as fort_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Fort Email Deliverability service definition for the admin sidebar.
///
/// Provides domain authentication, IP pool management, policy configuration,
/// reputation monitoring, MTA node status, and suppression list management.
const fortServiceDef = ServiceDefinition(
  id: 'fort',
  label: 'Email Deliverability',
  icon: Icons.mark_email_read_outlined,
  activeIcon: Icons.mark_email_read,
  description:
      'Domain authentication, IP warmup, reputation monitoring, and delivery policy management',
  requiredPermissions: {'fort_domain_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'domains',
      label: 'Domains',
      icon: Icons.dns_outlined,
      description: 'Manage sending domains, DKIM keys, and DNS verification',
      hasDetailPage: true,
      requiredPermissions: {'fort_domain_view'},
    ),
    SubFeatureDefinition(
      id: 'pools',
      label: 'IP Pools',
      icon: Icons.hub_outlined,
      description: 'Create and manage IP address pools for sending',
      hasDetailPage: true,
      requiredPermissions: {'fort_pool_manage'},
    ),
    SubFeatureDefinition(
      id: 'policies',
      label: 'Policies',
      icon: Icons.policy_outlined,
      description: 'Create, edit, and manage delivery routing policies',
      hasDetailPage: true,
      requiredPermissions: {'fort_policy_manage'},
    ),
    SubFeatureDefinition(
      id: 'reputation',
      label: 'Reputation',
      icon: Icons.trending_up_outlined,
      description: 'View reputation scores, signals, and history',
      requiredPermissions: {'fort_reputation_view'},
    ),
    SubFeatureDefinition(
      id: 'nodes',
      label: 'MTA Nodes',
      icon: Icons.storage_outlined,
      description: 'Monitor MTA node status and heartbeats',
      requiredPermissions: {'fort_node_view'},
    ),
    SubFeatureDefinition(
      id: 'suppression',
      label: 'Suppression',
      icon: Icons.block_outlined,
      description: 'Check and manage the email suppression list',
      requiredPermissions: {'fort_suppression_manage'},
    ),
  ],
);

/// Register the Fort Email Deliverability service with the global service registry.
void registerFortService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: fortServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
        service: 'fort',
        title: 'Deliverability Analytics',
        // KPI keys resolve through fortAnalyticsSpec; charts mirror the
        // spec's fort_* metric declarations.
        metrics: [
          'delivery_events',
          'complaints',
          'domains_verified',
          'dkim_rotations',
        ],
        charts: [
          ChartConfig.timeSeries(
            'fort_delivery_events_total',
            label: 'Delivery Events',
          ),
          ChartConfig.distribution(
            'fort_delivery_events_total',
            groupBy: 'event_type',
            label: 'Delivery Events by Type',
          ),
          ChartConfig.timeSeries(
            'fort_complaints_total',
            label: 'Complaints Trend',
          ),
        ],
      ),
      featureBuilders: {
        'domains': (context, service, feature) =>
            const fort_lib.DomainListScreen(),
        'pools': (context, service, feature) =>
            const fort_lib.IPPoolListScreen(),
        'policies': (context, service, feature) =>
            const fort_lib.PolicyListScreen(),
        'reputation': (context, service, feature) =>
            const fort_lib.ReputationScreen(),
        'nodes': (context, service, feature) => const fort_lib.NodeListScreen(),
        'suppression': (context, service, feature) =>
            const fort_lib.SuppressionListScreen(),
      },
      detailBuilders: {
        'domains': (context, service, feature, entityId) =>
            fort_lib.DomainDetailScreen(domainId: entityId),
        'pools': (context, service, feature, entityId) =>
            fort_lib.IPPoolDetailScreen(poolId: entityId),
        'policies': (context, service, feature, entityId) =>
            fort_lib.PolicyEditScreen(policyId: entityId),
      },
    ),
  );
}
