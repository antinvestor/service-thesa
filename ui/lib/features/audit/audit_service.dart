import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart';
import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Audit Service definition for the admin sidebar.
///
/// Provides tamper-proof audit trail browsing, search, analytics,
/// and hash chain integrity verification.
const auditServiceDef = ServiceDefinition(
  id: 'audit',
  label: 'Audit Trail',
  icon: Icons.history_outlined,
  activeIcon: Icons.history,
  description: 'Browse, search, and verify tamper-proof audit trail entries',
  requiredPermissions: {'audit_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'log',
      label: 'Audit Log',
      icon: Icons.list_alt_outlined,
      description: 'Browse and search all audit entries with filters',
      hasDetailPage: true,
      requiredPermissions: {'audit_view'},
    ),
    SubFeatureDefinition(
      id: 'analytics',
      label: 'Analytics',
      icon: Icons.analytics_outlined,
      description: 'Audit trail analytics and KPI dashboard',
      requiredPermissions: {'audit_view'},
    ),
    SubFeatureDefinition(
      id: 'integrity',
      label: 'Integrity Check',
      icon: Icons.verified_outlined,
      description: 'Verify hash chain integrity of the audit trail',
      requiredPermissions: {'audit_verify'},
    ),
  ],
);

/// Register the Audit Service with the global service registry.
void registerAuditService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: auditServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'audit',
            title: 'Audit Trail Analytics',
            metrics: [
              'total_entries',
              'unique_actors',
              'integrity_checks',
              'anomalies',
            ],
            charts: [
              ChartConfig.timeSeries('audit_volume',
                  label: 'Audit Volume'),
              ChartConfig.distribution('audit_actions',
                  groupBy: 'action', label: 'By Action'),
              ChartConfig.distribution('audit_services',
                  groupBy: 'service', label: 'By Service'),
            ],
            tables: [
              TableConfig.topN('top_actors',
                  label: 'Most Active Actors', limit: 10),
            ],
          ),
      featureBuilders: {
        'log': (context, service, feature) => const AuditLogScreen(),
        'analytics': (context, service, feature) =>
            const AuditAnalyticsScreen(),
        'integrity': (context, service, feature) =>
            const IntegrityCheckScreen(),
      },
      detailBuilders: {
        'log': (context, service, feature, entityId) =>
            AuditDetailScreen(entryId: entityId),
      },
    ),
  );
}
