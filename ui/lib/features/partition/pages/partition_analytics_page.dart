import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/services/thesa_analytics_data_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/analytics_error_view.dart';
import '../../../core/widgets/service_activity_widgets.dart';
import '../../../core/widgets/service_analytics_page.dart';
import '../data/partition_providers.dart';

/// Frame `{pkg}/completed_calls` metric emitted by the partition service.
const _partitionCallsMetric = 'partition/completed_calls';

/// Partition service analytics.
///
/// Inventory KPIs (tenant/partition/role counts) come from the entity
/// APIs; the growth chart, activity panel, and top-partitions table are
/// live queries against the Thesa analytics gate (tenant scoping
/// injected server-side from the JWT).
class PartitionAnalyticsPage extends ConsumerWidget {
  const PartitionAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider);
    final partitionsAsync = ref.watch(partitionsProvider);
    final rolesAsync = ref.watch(partitionRolesProvider);
    final analytics = ref.watch(adminAnalyticsProvider);

    final tenantsCount = tenantsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final partitionsCount =
        partitionsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final rolesCount = rolesAsync.whenOrNull(data: (d) => d.length) ?? 0;

    return ServiceAnalyticsPage(
      title: 'Partition Service',
      breadcrumbs: const ['Services', 'Partition Service', 'Analytics'],
      kpis: [
        ServiceKpi(
          label: 'Total Tenants',
          value: '$tenantsCount',
          icon: Icons.domain_outlined,
        ),
        ServiceKpi(
          label: 'Total Partitions',
          value: '$partitionsCount',
          icon: Icons.account_tree_outlined,
        ),
        ServiceKpi(
          label: 'Total Roles',
          value: '$rolesCount',
          icon: Icons.security_outlined,
        ),
      ],
      chartTitle: 'Partition Growth',
      chartSubtitle:
          'Organizations created across accessible partitions (12 months)',
      chartWidget: AnalyticsTrendChart(
        label: 'Organizations created',
        granularity: TimeGranularity.month,
        loader: () => analytics.queryTimeSeriesAllPartitions(
          metric: 'identity_organizations_created_total',
          timeRange: AnalyticsTimeRange.lastYear(),
        ),
      ),
      sidePanel: ServiceActivityPanel(
        dataSource: analytics,
        metric: _partitionCallsMetric,
      ),
      bottomSection: _TopPartitionsTable(analytics: analytics),
    );
  }
}

/// Top partitions ranked by organizations created in the last 30 days,
/// from the analytics gate's top-N endpoint.
class _TopPartitionsTable extends StatefulWidget {
  const _TopPartitionsTable({required this.analytics});

  final AdminAnalyticsDataSource analytics;

  @override
  State<_TopPartitionsTable> createState() => _TopPartitionsTableState();
}

class _TopPartitionsTableState extends State<_TopPartitionsTable> {
  late Future<List<TopNItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TopNItem>> _load() {
    return widget.analytics.queryTopNAllPartitions(
      metric: 'identity_organizations_created_total',
      groupBy: 'partition_id',
      limit: 5,
      timeRange: AnalyticsTimeRange.last30Days(),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Partitions by Organizations Created (30d)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<TopNItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 160,
                  child: AnalyticsErrorView(
                    error: snapshot.error!,
                    onRetry: _reload,
                  ),
                );
              }
              final items = snapshot.data ?? const <TopNItem>[];
              if (items.isEmpty) {
                return const SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      'No partition activity in this period yet',
                      style: TextStyle(color: AppColors.onSurfaceMuted),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('PARTITION')),
                    DataColumn(
                      label: Text('ORGANIZATIONS CREATED'),
                      numeric: true,
                    ),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(Text(item.label)),
                          DataCell(Text(item.value.toStringAsFixed(0))),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
