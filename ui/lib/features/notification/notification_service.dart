import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/notification_analytics_page.dart';
import 'pages/notifications_page.dart';
import 'pages/templates_page.dart';

const notificationServiceDef = ServiceDefinition(
  id: 'notification',
  label: 'Notification Service',
  icon: Icons.notifications_outlined,
  description: 'Manage notification templates and delivery',
  subFeatures: [
    SubFeatureDefinition(
      id: 'templates',
      label: 'Templates',
      icon: Icons.description_outlined,
      description: 'Manage notification templates',
    ),
    SubFeatureDefinition(
      id: 'notifications',
      label: 'Notifications',
      icon: Icons.send_outlined,
      description: 'View and manage notifications',
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
        'templates': (context, service, feature) =>
            TemplatesPage(service: service, feature: feature),
        'notifications': (context, service, feature) =>
            NotificationsPage(service: service, feature: feature),
      },
    ),
  );
}
