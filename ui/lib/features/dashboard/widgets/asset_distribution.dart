import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/thesa_analytics_data_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/analytics_error_view.dart';

/// Traffic by Service pie chart.
///
/// Queries the allowlisted `rpc.server.duration` call count grouped by
/// `rpc_service` to show the distribution of API traffic across cluster
/// services.
class AssetDistribution extends StatefulWidget {
  const AssetDistribution({super.key, required this.dataSource});

  final AdminAnalyticsDataSource dataSource;

  @override
  State<AssetDistribution> createState() => _AssetDistributionState();
}

class _AssetDistributionState extends State<AssetDistribution> {
  late Future<List<DistributionSegment>> _future;

  static const _segmentColors = [
    AppColors.primary,
    AppColors.tertiary,
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    AppColors.info,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.dataSource.queryGrouped(
      metric: 'rpc.server.duration',
      aggregation: AnalyticsAggregation.count,
      groupBy: 'rpc_service',
      timeRange: AnalyticsTimeRange.last30Days(),
    );
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
            'Traffic by Service',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<DistributionSegment>>(
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
                    onRetry: () => setState(_load),
                  ),
                );
              }
              return _buildChart(context, snapshot.data ?? []);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<DistributionSegment> segments) {
    if (segments.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No data available',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final total = segments.fold(0.0, (sum, s) => sum + s.value);

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(segments.length, (i) {
                return PieChartSectionData(
                  value: segments[i].value,
                  color:
                      segments[i].color ??
                      _segmentColors[i % _segmentColors.length],
                  radius: 25,
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: List.generate(segments.length, (i) {
              final s = segments[i];
              final pct = total > 0
                  ? '${(s.value / total * 100).toStringAsFixed(0)}%'
                  : '0%';
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < segments.length - 1 ? 8 : 0,
                ),
                child: _LegendItem(
                  color: s.color ?? _segmentColors[i % _segmentColors.length],
                  label: s.label,
                  value: pct,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
