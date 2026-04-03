import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/all_settings_page.dart';
import 'pages/modules_page.dart';
import 'pages/settings_analytics_page.dart';

const settingsServiceDef = ServiceDefinition(
  id: 'settings',
  label: 'Settings Service',
  icon: Icons.settings_outlined,
  description: 'Manage application configuration and settings',
  subFeatures: [
    SubFeatureDefinition(
      id: 'all',
      label: 'All Settings',
      icon: Icons.tune_outlined,
      description: 'Browse and manage all settings',
    ),
    SubFeatureDefinition(
      id: 'modules',
      label: 'Modules',
      icon: Icons.widgets_outlined,
      description: 'Explore settings grouped by module',
    ),
  ],
);

void registerSettingsService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: settingsServiceDef,
      analyticsBuilder: (context, service) =>
          SettingsAnalyticsPage(service: service),
      featureBuilders: {
        'all': (context, service, feature) =>
            AllSettingsPage(service: service, feature: feature),
        'modules': (context, service, feature) =>
            SettingsModulesPage(service: service, feature: feature),
      },
    ),
  );
}
