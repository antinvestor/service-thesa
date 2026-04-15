import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';
import 'widgets/activity_feed.dart';
import 'widgets/asset_distribution.dart';
import 'widgets/kpi_card.dart';
import 'widgets/portfolio_chart.dart';
import 'widgets/regional_performance.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = screenSizeOf(context);
    final showSideFeed = screenSize == ScreenSize.desktop;

    final timeRange = AnalyticsTimeRange.last30Days();
    final paymentMetrics = ref.watch(
      serviceMetricsProvider(
        ServiceMetricsParams('payment', timeRange: timeRange),
      ),
    );
    final tenancyMetrics = ref.watch(
      serviceMetricsProvider(
        ServiceMetricsParams('tenancy', timeRange: timeRange),
      ),
    );

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
                      title: 'Overview',
                      breadcrumbs: ['Dashboard', 'Analytics Dashboard'],
                    ),
                    const SizedBox(height: 24),
                    // KPI Row
                    _buildKpiRow(context, screenSize, paymentMetrics, tenancyMetrics),
                    const SizedBox(height: 24),
                    // Chart
                    const PortfolioChart(),
                    const SizedBox(height: 24),
                    // Distribution + Regional
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

  Widget _buildKpiRow(
    BuildContext context,
    ScreenSize screenSize,
    AsyncValue<List<MetricValue>> paymentMetrics,
    AsyncValue<List<MetricValue>> tenancyMetrics,
  ) {
    final cards = <Widget>[
      _metricKpiCard(
        tenancyMetrics,
        'active_users',
        fallbackLabel: 'Active Users',
        fallbackIcon: Icons.group_outlined,
      ),
      _metricKpiCard(
        paymentMetrics,
        'total_volume',
        fallbackLabel: 'Total Volume',
        fallbackIcon: Icons.payments_outlined,
      ),
      _metricKpiCard(
        paymentMetrics,
        'success_rate',
        fallbackLabel: 'Success Rate',
        fallbackIcon: Icons.trending_up,
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

  Widget _metricKpiCard(
    AsyncValue<List<MetricValue>> metricsAsync,
    String key, {
    required String fallbackLabel,
    required IconData fallbackIcon,
  }) {
    return metricsAsync.when(
      data: (metrics) {
        final m = metrics.where((m) => m.key == key).firstOrNull;
        if (m == null) {
          return KpiCard(label: fallbackLabel, value: '--', icon: fallbackIcon);
        }
        final change = m.changePercent;
        String? changeStr;
        bool positive = true;
        if (change != null) {
          positive = change >= 0;
          changeStr = '${positive ? '+' : ''}${change.toStringAsFixed(1)}%';
        }
        return KpiCard(
          label: m.label,
          value: _formatValue(m.value, m.unit),
          icon: m.icon ?? fallbackIcon,
          change: changeStr,
          changePositive: positive,
        );
      },
      loading: () => KpiCard(
        label: fallbackLabel,
        value: '...',
        icon: fallbackIcon,
      ),
      error: (_, _) => KpiCard(
        label: fallbackLabel,
        value: '--',
        icon: fallbackIcon,
      ),
    );
  }

  static String _formatValue(double value, String? unit) {
    return switch (unit) {
      'currency' => _formatCurrency(value),
      'percent' => '${value.toStringAsFixed(1)}%',
      'duration' => '${value.toStringAsFixed(0)}ms',
      'bytes' => _formatBytes(value),
      _ => _formatCount(value),
    };
  }

  static String _formatCurrency(double value) {
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(1)}K';
    return '\$${value.toStringAsFixed(2)}';
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

  Widget _buildBottomRow(BuildContext context, ScreenSize screenSize) {
    if (screenSize == ScreenSize.mobile) {
      return const Column(
        children: [
          AssetDistribution(),
          SizedBox(height: 24),
          RegionalPerformance(),
        ],
      );
    }

    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: 6),
          child: AssetDistribution(),
        )),
        Expanded(
            child: Padding(
          padding: EdgeInsets.only(left: 6),
          child: RegionalPerformance(),
        )),
      ],
    );
  }
}
