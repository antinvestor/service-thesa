import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/analytics_client.dart';
import '../../../core/theme/app_colors.dart';

/// API Traffic / time series bar chart.
///
/// Can be created either with a [ThesaAnalyticsClient] (fetches
/// `rpc_server_duration_count` time series) or with a pre-built
/// [Future<List<TimeSeriesPoint>>] via [PortfolioChart.fromFuture].
class PortfolioChart extends StatefulWidget {
  /// Creates a chart that queries API traffic from the given [client].
  const PortfolioChart({super.key, required ThesaAnalyticsClient client})
      : _client = client,
        _future = null,
        _title = 'API Traffic Over Time',
        _subtitle = 'RPC request volume';

  /// Creates a chart from an already-fetched future.
  const PortfolioChart.fromFuture({
    super.key,
    required String title,
    String subtitle = '',
    required Future<List<TimeSeriesPoint>> future,
  })  : _client = null,
        _future = future,
        _title = title,
        _subtitle = subtitle;

  final ThesaAnalyticsClient? _client;
  final Future<List<TimeSeriesPoint>>? _future;
  final String _title;
  final String _subtitle;

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends State<PortfolioChart> {
  String _range = '1Y';
  late Future<List<TimeSeriesPoint>> _pointsFuture;

  AnalyticsTimeRange get _timeRange => _range == '1Y'
      ? AnalyticsTimeRange.lastYear()
      : AnalyticsTimeRange.last90Days();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (widget._future != null) {
      _pointsFuture = widget._future!;
    } else {
      _pointsFuture = widget._client!.queryTimeSeries(
        metric: 'rpc_server_duration_count',
        timeRange: _timeRange,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRangeChips = widget._client != null;

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
                    Text(widget._title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (widget._subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget._subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (showRangeChips) ...[
                _RangeChip(
                  label: '90 DAYS',
                  selected: _range == '90D',
                  onTap: () {
                    setState(() {
                      _range = '90D';
                      _loadData();
                    });
                  },
                ),
                const SizedBox(width: 6),
                _RangeChip(
                  label: '1 YEAR',
                  selected: _range == '1Y',
                  onTap: () {
                    setState(() {
                      _range = '1Y';
                      _loadData();
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: FutureBuilder<List<TimeSeriesPoint>>(
              future: _pointsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load chart',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }
                return _buildChart(context, snapshot.data ?? []);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<TimeSeriesPoint> points) {
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
                final month = points[idx].timestamp;
                const months = [
                  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
                ];
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
