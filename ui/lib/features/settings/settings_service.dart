import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_settings/antinvestor_ui_settings.dart'
    as settings_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/all_settings_page.dart';
import 'pages/modules_page.dart';

/// Settings Service with enhanced bulk edit from antinvestor_ui_settings library.
const settingsServiceDef = ServiceDefinition(
  id: 'settings',
  label: 'Settings Service',
  icon: Icons.settings_outlined,
  description: 'Manage application configuration and settings',
  requiredPermissions: {'setting_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'all',
      label: 'All Settings',
      icon: Icons.tune_outlined,
      description: 'Browse and manage all settings',
      hasDetailPage: true,
      requiredPermissions: {'setting_view'},
    ),
    SubFeatureDefinition(
      id: 'modules',
      label: 'Modules',
      icon: Icons.widgets_outlined,
      description: 'Explore settings grouped by module',
      requiredPermissions: {'setting_view'},
    ),
    SubFeatureDefinition(
      id: 'bulk',
      label: 'Bulk Edit',
      icon: Icons.edit_note_outlined,
      description: 'Edit multiple settings at once',
      requiredPermissions: {'setting_update'},
    ),
  ],
);

void registerSettingsService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: settingsServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'settings',
            title: 'Settings Analytics',
            metrics: [
              'total_settings',
              'recent_changes',
              'modules_count',
            ],
            charts: [
              ChartConfig.timeSeries('setting_changes',
                  label: 'Configuration Changes'),
              ChartConfig.distribution('settings_by_module',
                  groupBy: 'module', label: 'By Module'),
            ],
          ),
      featureBuilders: {
        // Thesa's own admin pages
        'all': (context, service, feature) =>
            AllSettingsPage(service: service, feature: feature),
        'modules': (context, service, feature) =>
            SettingsModulesPage(service: service, feature: feature),
        // Bulk edit from antinvestor_ui_settings library
        'bulk': (context, service, feature) =>
            const settings_lib.SettingsBulkEditScreen(),
      },
      detailBuilders: {
        // Setting detail/edit from library
        'all': (context, service, feature, entityId) =>
            settings_lib.SettingDetailScreen(settingKey: entityId),
      },
    ),
  );
}
