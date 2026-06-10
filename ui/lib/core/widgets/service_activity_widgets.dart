import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/time_series_chart.dart';
import 'package:flutter/material.dart';

import '../services/thesa_analytics_data_source.dart';
import '../theme/app_colors.dart';
import 'analytics_error_view.dart';

/// Trend chart backed by an analytics-gate time-series query.
///
/// Handles loading, classified error (with retry), and empty states, and
/// renders real points with ui_core's [TimeSeriesChart].
class AnalyticsTrendChart extends StatefulWidget {
  const AnalyticsTrendChart({
    super.key,
    required this.label,
    required this.loader,
    this.granularity,
  });

  final String label;
  final Future<List<TimeSeriesPoint>> Function() loader;
  final TimeGranularity? granularity;

  @override
  State<AnalyticsTrendChart> createState() => _AnalyticsTrendChartState();
}

class _AnalyticsTrendChartState extends State<AnalyticsTrendChart> {
  late Future<List<TimeSeriesPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() {
    setState(() {
      _future = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimeSeriesPoint>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AnalyticsErrorView(error: snapshot.error!, onRetry: _reload);
        }
        final points = snapshot.data ?? const <TimeSeriesPoint>[];
        if (points.isEmpty) {
          return const Center(
            child: Text(
              'No data for this period yet',
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
          );
        }
        // Host cards give the chart area a fixed 240px; leave headroom
        // for the chart's line/bar mode toggle row.
        return TimeSeriesChart(
          series: [
            TimeSeries(key: widget.label, label: widget.label, points: points),
          ],
          height: 180,
          granularity: widget.granularity,
        );
      },
    );
  }
}

/// "Service Activity" side panel: live call volume for a service from the
/// analytics gate, using frame's built-in `{pkg}/completed_calls` metric.
///
/// Shows completed calls over the last 24 hours and the last 7 days with
/// a per-day average — replacing the previous mock "Recent Events" feeds.
class ServiceActivityPanel extends StatefulWidget {
  const ServiceActivityPanel({
    super.key,
    required this.dataSource,
    required this.metric,
    this.title = 'Service Activity',
  });

  final AdminAnalyticsDataSource dataSource;

  /// Completed-calls metric for the service (e.g. `profile/completed_calls`).
  final String metric;

  final String title;

  @override
  State<ServiceActivityPanel> createState() => _ServiceActivityPanelState();
}

class _ServiceActivityPanelState extends State<ServiceActivityPanel> {
  late Future<List<double>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<double>> _load() {
    return Future.wait([
      widget.dataSource.queryScalar(
        metric: widget.metric,
        timeRange: AnalyticsTimeRange.last24Hours(),
      ),
      widget.dataSource.queryScalar(
        metric: widget.metric,
        timeRange: AnalyticsTimeRange.last7Days(),
      ),
    ]);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  static String _formatCount(double value) {
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
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
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<double>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 180,
                  child: AnalyticsErrorView(
                    error: snapshot.error!,
                    onRetry: _reload,
                  ),
                );
              }
              final day = snapshot.data?[0] ?? 0;
              final week = snapshot.data?[1] ?? 0;
              if (day == 0 && week == 0) {
                return const SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      'No recorded activity yet',
                      style: TextStyle(color: AppColors.onSurfaceMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  _ActivityStat(
                    icon: Icons.bolt_outlined,
                    label: 'Completed calls (24h)',
                    value: _formatCount(day),
                  ),
                  const SizedBox(height: 12),
                  _ActivityStat(
                    icon: Icons.calendar_view_week_outlined,
                    label: 'Completed calls (7d)',
                    value: _formatCount(week),
                  ),
                  const SizedBox(height: 12),
                  _ActivityStat(
                    icon: Icons.speed_outlined,
                    label: 'Average per day (7d)',
                    value: _formatCount(week / 7),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.tertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
