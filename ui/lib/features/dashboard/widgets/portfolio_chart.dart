import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class PortfolioChart extends ConsumerStatefulWidget {
  const PortfolioChart({super.key});

  @override
  ConsumerState<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends ConsumerState<PortfolioChart> {
  String _range = '1Y';

  AnalyticsTimeRange get _timeRange => _range == '1Y'
      ? AnalyticsTimeRange.lastYear()
      : AnalyticsTimeRange.last90Days();

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(
      serviceTimeSeriesProvider(
        ServiceTimeSeriesParams('payment', 'payment_volume',
            timeRange: _timeRange),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Volume',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Transaction volume over time',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _RangeChip(
                label: '90 DAYS',
                selected: _range == '90D',
                onTap: () => setState(() => _range = '90D'),
              ),
              const SizedBox(width: 6),
              _RangeChip(
                label: '1 YEAR',
                selected: _range == '1Y',
                onTap: () => setState(() => _range = '1Y'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: seriesAsync.when(
              data: (series) => _buildChart(context, series),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Unable to load chart',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<TimeSeries> series) {
    final points =
        series.isNotEmpty ? series.first.points : <TimeSeriesPoint>[];
    if (points.isEmpty) {
      return Center(
        child: Text('No data available',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    final ceilY = maxY > 0 ? (maxY * 1.2) : 10.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: ceilY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              final label = value >= 1000
                  ? '${(value / 1000).toStringAsFixed(1)}K'
                  : value.toStringAsFixed(0);
              return BarTooltipItem(
                label,
                Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                final label = value >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}K'
                    : value.toStringAsFixed(0);
                return Text(label,
                    style: Theme.of(context).textTheme.labelSmall);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                // Show month abbreviation for each point
                final month = points[idx].timestamp;
                final months = [
                  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
                ];
                // Skip labels if too many points
                if (points.length > 12 && idx % 2 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    months[month.month - 1],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(points.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].value,
                color: AppColors.tertiary,
                width: points.length > 12 ? 12 : 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : AppColors.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
