import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart';
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
  subFeatures: [
    SubFeatureDefinition(
      id: 'log',
      label: 'Audit Log',
      icon: Icons.list_alt_outlined,
      description: 'Browse and search all audit entries with filters',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'analytics',
      label: 'Analytics',
      icon: Icons.analytics_outlined,
      description: 'Audit trail analytics and KPI dashboard',
    ),
    SubFeatureDefinition(
      id: 'integrity',
      label: 'Integrity Check',
      icon: Icons.verified_outlined,
      description: 'Verify hash chain integrity of the audit trail',
    ),
  ],
);

/// Register the Audit Service with the global service registry.
void registerAuditService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: auditServiceDef,
      analyticsBuilder: (context, service) =>
          const AuditAnalyticsScreen(),
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
