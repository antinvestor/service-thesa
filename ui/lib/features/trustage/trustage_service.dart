import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_trustage/antinvestor_ui_trustage.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Trustage (Workflow Orchestration) service definition for the admin sidebar.
///
/// Provides command deck overview, run explorer with execution graph,
/// execution queue, and workflow catalog for managing durable workflow
/// executions.
const trustageServiceDef = ServiceDefinition(
  id: 'trustage',
  label: 'Orchestrator',
  icon: Icons.hub_outlined,
  activeIcon: Icons.hub,
  description:
      'Manage workflow orchestration — runs, executions, and workflow catalog',
  requiredPermissions: {'trustage_read'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'runs',
      label: 'Run Explorer',
      icon: Icons.play_circle_outline,
      description: 'Browse and inspect workflow instances with execution graph',
      hasDetailPage: true,
      requiredPermissions: {'trustage_read'},
    ),
    SubFeatureDefinition(
      id: 'executions',
      label: 'Execution Queue',
      icon: Icons.list_alt,
      description:
          'Monitor pending, running, and failed executions with one-click retry',
      requiredPermissions: {'trustage_read'},
    ),
    SubFeatureDefinition(
      id: 'workflows',
      label: 'Workflow Catalog',
      icon: Icons.schema_outlined,
      description: 'Browse and manage active workflow definitions',
      requiredPermissions: {'trustage_read'},
    ),
  ],
);

/// Register the Trustage Orchestrator service with the global service registry.
void registerTrustageService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: trustageServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
        service: 'trustage',
        title: 'Orchestrator Analytics',
        // The trustage service emits these via frame's tenant-scoped
        // business metrics (engine./queue. and workflow_ prefixes are
        // gate-allowlisted).
        charts: [
          ChartConfig.timeSeries(
            'engine.executions.total',
            label: 'Workflow Executions',
          ),
          ChartConfig.timeSeries(
            'workflow_lifecycle_total',
            label: 'Workflow Lifecycle Events',
          ),
          ChartConfig.timeSeries(
            'queue.enqueue.total',
            label: 'Queue Enqueues',
          ),
        ],
      ),
      featureBuilders: {
        'runs': (context, service, feature) => const RunExplorerScreen(),
        'executions': (context, service, feature) =>
            const ExecutionQueueScreen(),
        'workflows': (context, service, feature) =>
            const WorkflowCatalogScreen(),
      },
      detailBuilders: {
        'runs': (context, service, feature, entityId) =>
            RunExplorerScreen(initialInstanceId: entityId),
      },
    ),
  );
}
