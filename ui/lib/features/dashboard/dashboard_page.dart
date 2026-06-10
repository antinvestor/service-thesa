import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/thesa_analytics_data_source.dart';
import '../../core/widgets/analytics_error_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';
import 'widgets/activity_feed.dart';
import 'widgets/asset_distribution.dart';
import 'widgets/kpi_card.dart';
import 'widgets/portfolio_chart.dart';
import 'widgets/regional_performance.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final AdminAnalyticsDataSource _analytics;
  late final AnalyticsTimeRange _timeRange;

  // KPI futures
  late Future<double> _totalApiRequests;
  late Future<double> _errorRate;
  late Future<double> _organizationsCreated;
  late Future<double> _notificationsSent;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _timeRange = AnalyticsTimeRange.last30Days();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _analytics = ref.read(adminAnalyticsProvider);
    _loadMetrics();
  }

  void _loadMetrics() {
    // All metric names below are in the gate's allowlist; tenant scoping
    // is injected server-side from the JWT.
    _totalApiRequests = _analytics.queryScalar(
      metric: 'rpc.server.duration',
      aggregation: AnalyticsAggregation.count,
      timeRange: _timeRange,
    );

    _errorRate = _computeErrorRate();

    _organizationsCreated = _analytics.queryScalar(
      metric: 'identity_organizations_created_total',
      timeRange: _timeRange,
    );

    _notificationsSent = _analytics.queryScalar(
      metric: 'notifications_sent_total',
      timeRange: _timeRange,
    );
  }

  /// Error rate computed client-side from two allowlisted scalars; the
  /// standardized gate has no ratio endpoint.
  Future<double> _computeErrorRate() async {
    final results = await Future.wait([
      _analytics.queryScalar(
        metric: 'rpc.server.duration',
        aggregation: AnalyticsAggregation.count,
        filters: {'rpc_grpc_status_code': 'OK'},
        timeRange: _timeRange,
      ),
      _analytics.queryScalar(
        metric: 'rpc.server.duration',
        aggregation: AnalyticsAggregation.count,
        timeRange: _timeRange,
      ),
    ]);
    final ok = results[0];
    final total = results[1];
    if (total == 0) return 0;
    return ((total - ok) / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = screenSizeOf(context);
    final showSideFeed = screenSize == ScreenSize.desktop;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content area
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: 'Cluster Overview',
                      breadcrumbs: ['Dashboard', 'Cluster Overview'],
                    ),
                    const SizedBox(height: 24),
                    // Row 1: Platform KPI cards
                    _buildKpiRow(context, screenSize),
                    const SizedBox(height: 24),
                    // Row 2: Traffic charts
                    _buildTrafficCharts(context, screenSize),
                    const SizedBox(height: 24),
                    // Row 3 + Row 4: Distribution + Service load
                    _buildBottomRow(context, screenSize),
                    // Activity feed inline on mobile/tablet
                    if (!showSideFeed) ...[
                      const SizedBox(height: 24),
                      const ActivityFeed(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Side activity feed on desktop
        if (showSideFeed)
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
              child: const ActivityFeed(),
            ),
          ),
      ],
    );
  }

  Widget _buildKpiRow(BuildContext context, ScreenSize screenSize) {
    final cards = <Widget>[
      _scalarKpiCard(
        future: _totalApiRequests,
        label: 'API Requests',
        icon: Icons.api_outlined,
      ),
      _scalarKpiCard(
        future: _errorRate,
        label: 'Error Rate',
        icon: Icons.error_outline,
        unit: 'percent',
      ),
      _scalarKpiCard(
        future: _organizationsCreated,
        label: 'Organizations Created',
        icon: Icons.domain_outlined,
      ),
      _scalarKpiCard(
        future: _notificationsSent,
        label: 'Notifications Sent',
        icon: Icons.send_outlined,
      ),
    ];

    if (screenSize == ScreenSize.mobile) {
      return Column(
        children: cards
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
            )
            .toList(),
      );
    }

    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _scalarKpiCard({
    required Future<double> future,
    required String label,
    required IconData icon,
    String? unit,
  }) {
    return FutureBuilder<double>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return KpiCard(label: label, value: '...', icon: icon);
        }
        if (snapshot.hasError) {
          // Friendly classified state: card shows a dash, the tooltip
          // carries the reason (no tenant scope, allowlist reject, ...).
          final info = describeAnalyticsError(snapshot.error!);
          return Tooltip(
            message: '${info.title}: ${info.detail}',
            child: KpiCard(label: label, value: '--', icon: icon),
          );
        }
        final value = snapshot.data ?? 0;
        return KpiCard(
          label: label,
          value: _formatValue(value, unit),
          icon: icon,
        );
      },
    );
  }

  Widget _buildTrafficCharts(BuildContext context, ScreenSize screenSize) {
    if (screenSize == ScreenSize.mobile) {
      return Column(
        children: [
          PortfolioChart(dataSource: _analytics),
          const SizedBox(height: 24),
          _PaymentVolumeChart(dataSource: _analytics),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PortfolioChart(dataSource: _analytics),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _PaymentVolumeChart(dataSource: _analytics),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context, ScreenSize screenSize) {
    if (screenSize == ScreenSize.mobile) {
      return Column(
        children: [
          AssetDistribution(dataSource: _analytics),
          const SizedBox(height: 24),
          RegionalPerformance(dataSource: _analytics),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AssetDistribution(dataSource: _analytics),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: RegionalPerformance(dataSource: _analytics),
          ),
        ),
      ],
    );
  }

  static String _formatValue(double value, String? unit) {
    return switch (unit) {
      'percent' => '${value.toStringAsFixed(1)}%',
      'bytes' => _formatBytes(value),
      _ => _formatCount(value),
    };
  }

  static String _formatCount(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  static String _formatBytes(double value) {
    if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(1)} TB';
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)} GB';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)} MB';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)} KB';
    return '${value.toStringAsFixed(0)} B';
  }
}

/// Payment Volume time series chart (Row 2, right panel).
class _PaymentVolumeChart extends StatefulWidget {
  const _PaymentVolumeChart({required this.dataSource});

  final AdminAnalyticsDataSource dataSource;

  @override
  State<_PaymentVolumeChart> createState() => _PaymentVolumeChartState();
}

class _PaymentVolumeChartState extends State<_PaymentVolumeChart> {
  late Future<List<TimeSeriesPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.dataSource.queryTimeSeries(
      metric: 'payments_transactions_total',
      timeRange: AnalyticsTimeRange.lastYear(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortfolioChart.fromFuture(
      title: 'Payment Volume',
      subtitle: 'Transactions over time',
      future: _future,
    );
  }
}
