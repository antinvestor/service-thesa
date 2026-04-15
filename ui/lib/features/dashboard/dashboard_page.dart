import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/services/analytics_client.dart';
import '../../core/services/api_config.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';
import 'widgets/activity_feed.dart';
import 'widgets/asset_distribution.dart';
import 'widgets/kpi_card.dart';
import 'widgets/portfolio_chart.dart';
import 'widgets/regional_performance.dart';

/// Riverpod provider for the analytics client used by the dashboard.
final analyticsClientProvider = Provider<ThesaAnalyticsClient>((ref) {
  return ThesaAnalyticsClient(http.Client(), ApiConfig.thesaBaseUrl);
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final ThesaAnalyticsClient _client;
  late final AnalyticsTimeRange _timeRange;

  // KPI futures
  late Future<double> _totalApiRequests;
  late Future<double> _errorRate;
  late Future<double> _activeTenants;
  late Future<double> _notificationsSent;

  @override
  void initState() {
    super.initState();
    _timeRange = AnalyticsTimeRange.last30Days();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = ref.read(analyticsClientProvider);
    _loadMetrics();
  }

  void _loadMetrics() {
    _totalApiRequests = _client.queryScalar(
      metric: 'rpc_server_duration_count',
      aggregation: 'sum',
      timeRange: _timeRange,
    );

    _errorRate = _computeErrorRate();

    _activeTenants = _client.queryScalar(
      metric: 'tenancy_tenants_created_total',
      aggregation: 'sum',
      timeRange: _timeRange,
    );

    _notificationsSent = _client.queryScalar(
      metric: 'notification_sent_total',
      aggregation: 'sum',
      timeRange: _timeRange,
    );
  }

  Future<double> _computeErrorRate() async {
    final results = await Future.wait([
      _client.queryScalar(
        metric: 'rpc_server_duration_count',
        aggregation: 'sum',
        filters: {'rpc_grpc_status_code': 'OK'},
        timeRange: _timeRange,
      ),
      _client.queryScalar(
        metric: 'rpc_server_duration_count',
        aggregation: 'sum',
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
                    // Row 3 + Row 4: Distribution + Resources
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
              padding:
                  const EdgeInsets.only(top: 24, right: 24, bottom: 24),
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
        future: _activeTenants,
        label: 'Active Tenants',
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
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              )))
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
          return KpiCard(label: label, value: '--', icon: icon);
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
          PortfolioChart(client: _client),
          const SizedBox(height: 24),
          _PaymentVolumeChart(client: _client),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PortfolioChart(client: _client),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _PaymentVolumeChart(client: _client),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context, ScreenSize screenSize) {
    if (screenSize == ScreenSize.mobile) {
      return Column(
        children: [
          AssetDistribution(client: _client),
          const SizedBox(height: 24),
          RegionalPerformance(client: _client),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AssetDistribution(client: _client),
        )),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: RegionalPerformance(client: _client),
        )),
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
  const _PaymentVolumeChart({required this.client});

  final ThesaAnalyticsClient client;

  @override
  State<_PaymentVolumeChart> createState() => _PaymentVolumeChartState();
}

class _PaymentVolumeChartState extends State<_PaymentVolumeChart> {
  late Future<List<TimeSeriesPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.queryTimeSeries(
      metric: 'payment_transactions_total',
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
