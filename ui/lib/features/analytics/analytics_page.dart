import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/thesa_analytics_data_source.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/analytics_error_view.dart';
import '../../core/widgets/page_header.dart';

/// Analytics query explorer page.
///
/// Allows the user to enter a metric name and view scalar, time series,
/// and grouped results from the cluster analytics backend.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  final _metricController = TextEditingController(text: 'rpc.server.duration');
  final _groupByController = TextEditingController(text: 'rpc_service');

  String _selectedRange = '30d';
  AnalyticsAggregation _aggregation = AnalyticsAggregation.count;

  Future<double>? _scalarFuture;
  Future<List<TimeSeriesPoint>>? _timeSeriesFuture;
  Future<List<DistributionSegment>>? _groupedFuture;

  AnalyticsTimeRange get _timeRange => switch (_selectedRange) {
    '24h' => AnalyticsTimeRange.last24Hours(),
    '7d' => AnalyticsTimeRange.last7Days(),
    '90d' => AnalyticsTimeRange.last90Days(),
    '1y' => AnalyticsTimeRange.lastYear(),
    _ => AnalyticsTimeRange.last30Days(),
  };

  void _runQuery() {
    final dataSource = ref.read(adminAnalyticsProvider);
    final metric = _metricController.text.trim();
    if (metric.isEmpty) return;

    setState(() {
      // `.ignore()` keeps gate rejections (400/403) from surfacing as
      // unhandled async errors before the FutureBuilders subscribe; the
      // builders still receive and render them.
      _scalarFuture = dataSource.queryScalar(
        metric: metric,
        aggregation: _aggregation,
        timeRange: _timeRange,
      )..ignore();
      _timeSeriesFuture = dataSource.queryTimeSeries(
        metric: metric,
        aggregation: _aggregation,
        timeRange: _timeRange,
      )..ignore();

      final groupBy = _groupByController.text.trim();
      if (groupBy.isNotEmpty) {
        _groupedFuture = dataSource.queryGrouped(
          metric: metric,
          aggregation: _aggregation,
          groupBy: groupBy,
          timeRange: _timeRange,
        )..ignore();
      } else {
        _groupedFuture = null;
      }
    });
  }

  @override
  void dispose() {
    _metricController.dispose();
    _groupByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Analytics Explorer',
                breadcrumbs: ['Dashboard', 'Analytics'],
              ),
              const SizedBox(height: 24),
              _buildQueryBar(context),
              if (_scalarFuture != null) ...[
                const SizedBox(height: 24),
                _buildScalarCard(context),
              ],
              if (_timeSeriesFuture != null) ...[
                const SizedBox(height: 24),
                _buildTimeSeriesCard(context),
              ],
              if (_groupedFuture != null) ...[
                const SizedBox(height: 24),
                _buildGroupedCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueryBar(BuildContext context) {
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
          Text('Query', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _metricController,
                  decoration: const InputDecoration(
                    labelText: 'Metric name',
                    hintText: 'e.g. rpc.server.duration',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _groupByController,
                  decoration: const InputDecoration(
                    labelText: 'Group by (optional)',
                    hintText: 'e.g. rpc_service',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<AnalyticsAggregation>(
                value: _aggregation,
                underline: const SizedBox.shrink(),
                items: [
                  for (final agg in AnalyticsAggregation.values)
                    DropdownMenuItem(value: agg, child: Text(agg.wireName)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _aggregation = v);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedRange,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '24h', child: Text('24 hours')),
                  DropdownMenuItem(value: '7d', child: Text('7 days')),
                  DropdownMenuItem(value: '30d', child: Text('30 days')),
                  DropdownMenuItem(value: '90d', child: Text('90 days')),
                  DropdownMenuItem(value: '1y', child: Text('1 year')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRange = v);
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _runQuery,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScalarCard(BuildContext context) {
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
          Text('Scalar Result', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: _scalarFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 140,
                  child: AnalyticsErrorView(error: snapshot.error!),
                );
              }
              final value = snapshot.data ?? 0;
              return Text(
                _formatNumber(value),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeriesCard(BuildContext context) {
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
          Text('Time Series', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: FutureBuilder<List<TimeSeriesPoint>>(
              future: _timeSeriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AnalyticsErrorView(error: snapshot.error!);
                }
                final points = snapshot.data ?? [];
                if (points.isEmpty) {
                  return Center(
                    child: Text(
                      'No data',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return _buildLineChart(context, points);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, List<TimeSeriesPoint> points) {
    final maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    final ceilY = maxY > 0 ? maxY * 1.2 : 10.0;

    return LineChart(
      LineChartData(
        maxY: ceilY,
        minY: 0,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(points.length, (i) {
              return FlSpot(i.toDouble(), points[i].value);
            }),
            isCurved: true,
            color: AppColors.tertiary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.tertiary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard(BuildContext context) {
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
            'Grouped by "${_groupByController.text}"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<DistributionSegment>>(
            future: _groupedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 160,
                  child: AnalyticsErrorView(error: snapshot.error!),
                );
              }
              final segments = snapshot.data ?? [];
              if (segments.isEmpty) {
                return Text(
                  'No data',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final maxVal = segments.fold(
                0.0,
                (m, s) => s.value > m ? s.value : m,
              );
              return Column(
                children: segments.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupedBar(
                      label: s.label,
                      value: maxVal > 0 ? s.value / maxVal : 0,
                      display: _formatNumber(s.value),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatNumber(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _GroupedBar extends StatelessWidget {
  const _GroupedBar({
    required this.label,
    required this.value,
    required this.display,
  });

  final String label;
  final double value;
  final String display;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              display,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.tertiary),
          ),
        ),
      ],
    );
  }
}
