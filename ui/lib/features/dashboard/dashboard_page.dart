import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';
import 'widgets/activity_feed.dart';
import 'widgets/asset_distribution.dart';
import 'widgets/kpi_card.dart';
import 'widgets/portfolio_chart.dart';
import 'widgets/regional_performance.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  title: 'Overview',
                  breadcrumbs: ['Dashboard', 'Analytics Dashboard'],
                ),
                const SizedBox(height: 24),
                // KPI Row
                _buildKpiRow(context, screenSize),
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
    const cards = [
      KpiCard(
        label: 'Active Users',
        value: '24,592',
        change: '+12.5%',
        icon: Icons.group_outlined,
      ),
      KpiCard(
        label: 'Total Investments',
        value: '\$142.8M',
        change: '+8.2%',
        icon: Icons.payments_outlined,
      ),
      KpiCard(
        label: 'Growth Rate',
        value: '18.4%',
        icon: Icons.trending_up,
      ),
    ];

    if (screenSize == ScreenSize.mobile) {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: c,
        )).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              )))
          .toList(),
    );
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
        Expanded(child: Padding(
          padding: EdgeInsets.only(right: 6),
          child: AssetDistribution(),
        )),
        Expanded(child: Padding(
          padding: EdgeInsets.only(left: 6),
          child: RegionalPerformance(),
        )),
      ],
    );
  }
}
