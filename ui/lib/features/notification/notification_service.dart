import 'package:antinvestor_ui_notification/antinvestor_ui_notification.dart'
    as notif_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/notification_analytics_page.dart';
import 'pages/notifications_page.dart';
import 'pages/templates_page.dart';

/// Notification Service with enhanced compose and template editing from
/// antinvestor_ui_notification library.
const notificationServiceDef = ServiceDefinition(
  id: 'notification',
  label: 'Notification Service',
  icon: Icons.notifications_outlined,
  description: 'Send, manage, and track notification delivery with templates',
  subFeatures: [
    SubFeatureDefinition(
      id: 'notifications',
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      description: 'View notification history and delivery status',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'compose',
      label: 'Compose',
      icon: Icons.send_outlined,
      description: 'Send new notifications',
    ),
    SubFeatureDefinition(
      id: 'templates',
      label: 'Templates',
      icon: Icons.description_outlined,
      description: 'Manage notification templates',
      hasDetailPage: true,
    ),
  ],
);

void registerNotificationService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: notificationServiceDef,
      analyticsBuilder: (context, service) =>
          NotificationAnalyticsPage(service: service),
      featureBuilders: {
        // Thesa's own admin page for notification list
        'notifications': (context, service, feature) =>
            NotificationsPage(service: service, feature: feature),
        // Compose screen from antinvestor_ui_notification library
        'compose': (context, service, feature) =>
            const notif_lib.NotificationSendScreen(),
        // Thesa's own template management
        'templates': (context, service, feature) =>
            TemplatesPage(service: service, feature: feature),
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
