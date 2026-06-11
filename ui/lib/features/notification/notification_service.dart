import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_notification/antinvestor_ui_notification.dart'
    as notif_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Notification Service with enhanced compose and template editing from
/// antinvestor_ui_notification library.
const notificationServiceDef = ServiceDefinition(
  id: 'notification',
  label: 'Notification Service',
  icon: Icons.notifications_outlined,
  description: 'Send, manage, and track notification delivery with templates',
  requiredPermissions: {'notification_search'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'notifications',
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      description: 'View notification history and delivery status',
      hasDetailPage: true,
      requiredPermissions: {'notification_search'},
    ),
    SubFeatureDefinition(
      id: 'compose',
      label: 'Compose',
      icon: Icons.send_outlined,
      description: 'Send new notifications',
      requiredPermissions: {'notification_send'},
    ),
    SubFeatureDefinition(
      id: 'templates',
      label: 'Templates',
      icon: Icons.description_outlined,
      description: 'Manage notification templates',
      hasDetailPage: true,
      requiredPermissions: {'template_manage'},
    ),
  ],
);

void registerNotificationService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: notificationServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
        service: 'notification',
        title: 'Notification Analytics',
        // KPI keys resolve through notificationAnalyticsSpec; charts mirror
        // the spec's notifications_* metric declarations. The notification
        // service does not emit these counters yet, so charts render empty
        // (not errors) until emission lands.
        metrics: ['sent', 'delivered', 'failed', 'queued'],
        charts: [
          ChartConfig.timeSeries(
            'notifications_sent_total',
            label: 'Notifications sent',
          ),
          ChartConfig.distribution(
            'notifications_sent_total',
            groupBy: 'channel',
            label: 'Channel mix',
          ),
        ],
      ),
      featureBuilders: {
        'notifications': (context, service, feature) =>
            const notif_lib.NotificationInboxScreen(),
        'compose': (context, service, feature) =>
            const notif_lib.NotificationSendScreen(),
        'templates': (context, service, feature) =>
            const notif_lib.TemplateListScreen(),
      },
      detailBuilders: {
        // Detail view from library
        'notifications': (context, service, feature, entityId) =>
            notif_lib.NotificationDetailScreen(notificationId: entityId),
        // Template edit from library
        'templates': (context, service, feature, entityId) =>
            notif_lib.TemplateEditScreen(templateId: entityId),
      },
    ),
  );
}
