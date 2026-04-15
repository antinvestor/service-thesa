import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class AssetDistribution extends ConsumerWidget {
  const AssetDistribution({super.key});

  static const _segmentColors = [
    AppColors.primary,
    AppColors.tertiary,
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = AnalyticsTimeRange.last30Days();
    final distAsync = ref.watch(
      serviceDistributionProvider(
        ServiceDistributionParams(
          'payment',
          'payment_routes',
          'route',
          timeRange: timeRange,
        ),
      ),
    );

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
          Text('Payment Routes',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          distAsync.when(
            data: (segments) => _buildChart(context, segments),
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SizedBox(
              height: 120,
              child: Center(
                child: Text('Unable to load data',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
      BuildContext context, List<DistributionSegment> segments) {
    if (segments.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('No data available',
              style: Theme.of(context).textTheme.bodySmall),
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
                  color: segments[i].color ??
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
                padding: EdgeInsets.only(bottom: i < segments.length - 1 ? 8 : 0),
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
  const _LegendItem(
      {required this.color, required this.label, required this.value});

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
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
