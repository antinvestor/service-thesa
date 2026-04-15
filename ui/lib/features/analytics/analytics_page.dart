import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Analytics page that renders a full, data-driven analytics dashboard for a
/// selected service. Uses the [AnalyticsDashboard] widget from ui_core which
/// handles all data fetching, loading states, and chart rendering.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _selectedService = 'payment';

  @override
  Widget build(BuildContext context) {
    final config = _serviceConfigs[_selectedService]!;

    return AnalyticsDashboard(
      key: ValueKey(_selectedService),
      service: _selectedService,
      title: config.title,
      breadcrumbs: ['Dashboard', 'Analytics', config.title],
      metrics: config.metrics,
      charts: config.charts,
      tables: config.tables,
      refreshInterval: const Duration(minutes: 5),
      actions: [
        DropdownButton<String>(
          value: _selectedService,
          underline: const SizedBox.shrink(),
          items: _serviceConfigs.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value.title),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedService = value);
          },
        ),
      ],
    );
  }
}

class _ServiceDashboardConfig {
  const _ServiceDashboardConfig({
    required this.title,
    required this.metrics,
    required this.charts,
    this.tables = const [],
  });

  final String title;
  final List<String> metrics;
  final List<ChartConfig> charts;
  final List<TableConfig> tables;
}

const _serviceConfigs = <String, _ServiceDashboardConfig>{
  'payment': _ServiceDashboardConfig(
    title: 'Payments',
    metrics: ['total_payments', 'total_volume', 'success_rate', 'avg_processing_time'],
    charts: [
      ChartConfig.timeSeries('payment_volume', label: 'Payment Volume'),
      ChartConfig.distribution('payment_routes', label: 'By Route', groupBy: 'route'),
      ChartConfig.timeSeries('payment_amount', label: 'Payment Amount'),
      ChartConfig.distribution('payment_status', label: 'By Status', groupBy: 'status'),
    ],
    tables: [
      TableConfig.topN('top_recipients', label: 'Top Recipients', limit: 10),
    ],
  ),
  'profile': _ServiceDashboardConfig(
    title: 'Profiles',
    metrics: ['total_profiles', 'active_profiles', 'new_registrations', 'verification_rate'],
    charts: [
      ChartConfig.timeSeries('registrations', label: 'Registrations'),
      ChartConfig.distribution('profile_types', label: 'By Type', groupBy: 'profile_type'),
    ],
    tables: [
      TableConfig.topN('top_active_profiles', label: 'Most Active Profiles', limit: 10),
    ],
  ),
  'notification': _ServiceDashboardConfig(
    title: 'Notifications',
    metrics: ['total_sent', 'delivery_rate', 'open_rate', 'failed_count'],
    charts: [
      ChartConfig.timeSeries('notifications_sent', label: 'Notifications Sent'),
      ChartConfig.distribution('notification_channels', label: 'By Channel', groupBy: 'channel'),
      ChartConfig.distribution('notification_status', label: 'By Status', groupBy: 'status'),
    ],
    tables: [
      TableConfig.topN('top_templates', label: 'Top Templates', limit: 10),
    ],
  ),
  'billing': _ServiceDashboardConfig(
    title: 'Billing',
    metrics: ['active_subscriptions', 'mrr', 'outstanding_invoices', 'churn_rate'],
    charts: [
      ChartConfig.timeSeries('revenue', label: 'Revenue'),
      ChartConfig.distribution('subscription_plans', label: 'By Plan', groupBy: 'plan_name'),
    ],
    tables: [
      TableConfig.topN('top_customers', label: 'Top Customers', limit: 10),
    ],
  ),
  'tenancy': _ServiceDashboardConfig(
    title: 'Tenancy',
    metrics: ['total_tenants', 'total_partitions', 'active_users', 'new_tenants'],
    charts: [
      ChartConfig.timeSeries('tenant_growth', label: 'Tenant Growth'),
      ChartConfig.distribution('tenants_by_plan', label: 'By Plan', groupBy: 'plan'),
    ],
    tables: [
      TableConfig.topN('top_tenants', label: 'Largest Tenants', limit: 10),
    ],
  ),
  'audit': _ServiceDashboardConfig(
    title: 'Audit',
    metrics: ['total_entries', 'unique_actors', 'integrity_checks', 'anomalies'],
    charts: [
      ChartConfig.timeSeries('audit_volume', label: 'Audit Volume'),
      ChartConfig.distribution('audit_actions', label: 'By Action', groupBy: 'action'),
      ChartConfig.distribution('audit_services', label: 'By Service', groupBy: 'service'),
    ],
    tables: [
      TableConfig.topN('top_actors', label: 'Most Active Actors', limit: 10),
    ],
  ),
  'files': _ServiceDashboardConfig(
    title: 'Files',
    metrics: ['total_files', 'total_storage', 'uploads_today', 'avg_file_size'],
    charts: [
      ChartConfig.timeSeries('upload_volume', label: 'Uploads'),
      ChartConfig.distribution('file_types', label: 'By Type', groupBy: 'content_type'),
    ],
    tables: [
      TableConfig.topN('top_uploaders', label: 'Top Uploaders', limit: 10),
    ],
  ),
  'geolocation': _ServiceDashboardConfig(
    title: 'Geolocation',
    metrics: ['total_areas', 'total_routes', 'geo_events', 'active_trackers'],
    charts: [
      ChartConfig.timeSeries('geo_event_volume', label: 'Geo Events'),
      ChartConfig.distribution('event_types', label: 'By Event Type', groupBy: 'event_type'),
    ],
    tables: [
      TableConfig.topN('top_areas', label: 'Most Active Areas', limit: 10),
    ],
  ),
  'settings': _ServiceDashboardConfig(
    title: 'Settings',
    metrics: ['total_settings', 'recent_changes', 'modules_count'],
    charts: [
      ChartConfig.timeSeries('setting_changes', label: 'Configuration Changes'),
      ChartConfig.distribution('settings_by_module', label: 'By Module', groupBy: 'module'),
    ],
  ),
};
