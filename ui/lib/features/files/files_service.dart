import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_files/antinvestor_ui_files.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// File Management service definition for the admin sidebar.
const filesServiceDef = ServiceDefinition(
  id: 'files',
  label: 'File Management',
  icon: Icons.folder_outlined,
  activeIcon: Icons.folder,
  description:
      'Upload, browse, and manage files with access control and versioning',
  requiredPermissions: {'file_view'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'browser',
      label: 'Files',
      icon: Icons.folder_open_outlined,
      description: 'Browse and search uploaded files',
      hasDetailPage: true,
      requiredPermissions: {'file_view'},
    ),
    SubFeatureDefinition(
      id: 'upload',
      label: 'Upload',
      icon: Icons.upload_file_outlined,
      description: 'Upload new files',
      requiredPermissions: {'file_upload'},
    ),
    SubFeatureDefinition(
      id: 'storage',
      label: 'Storage',
      icon: Icons.storage_outlined,
      description: 'View storage usage and quotas',
      requiredPermissions: {'file_view'},
    ),
    SubFeatureDefinition(
      id: 'retention',
      label: 'Retention',
      icon: Icons.policy_outlined,
      description: 'Manage file retention policies',
      requiredPermissions: {'file_retention_manage'},
    ),
  ],
);

/// Register the File Management service with the global service registry.
void registerFilesService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: filesServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
        service: 'files',
        title: 'File Management Analytics',
        // KPI keys resolve through filesAnalyticsSpec to the
        // file_service_* metrics the files service exposes.
        metrics: ['uploads', 'downloads', 'upload_bytes', 'download_bytes'],
        charts: [
          ChartConfig.timeSeries('file_service_uploads_total', label: 'Uploads'),
          ChartConfig.timeSeries(
            'file_service_downloads_total',
            label: 'Downloads',
          ),
        ],
      ),
      featureBuilders: {
        'browser': (context, service, feature) => const FilesBrowserScreen(),
        'upload': (context, service, feature) => const FileUploadScreen(),
        'storage': (context, service, feature) =>
            const StorageDashboardScreen(),
        'retention': (context, service, feature) => const FileRetentionScreen(),
      },
      detailBuilders: {
        'browser': (context, service, feature, entityId) =>
            FileDetailScreen(contentId: entityId),
      },
    ),
  );
}
