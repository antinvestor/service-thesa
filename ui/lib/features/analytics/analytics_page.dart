import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = screenSizeOf(context);
    final crossCount = screenSize == ScreenSize.mobile ? 1 : 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Analytics',
            breadcrumbs: ['Dashboard', 'Analytics'],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: const [
              _UserGrowthChart(),
              _RevenueChart(),
              _ConversionChart(),
              _TrafficSourceChart(),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _UserGrowthChart extends StatelessWidget {
  const _UserGrowthChart();

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'User Growth',
      subtitle: 'Monthly active users trend',
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 12), FlSpot(1, 14), FlSpot(2, 13), FlSpot(3, 17),
                FlSpot(4, 19), FlSpot(5, 21), FlSpot(6, 20), FlSpot(7, 24),
                FlSpot(8, 22), FlSpot(9, 26), FlSpot(10, 28), FlSpot(11, 30),
              ],
              isCurved: true,
              color: AppColors.tertiary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.tertiary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Revenue',
      subtitle: 'Monthly revenue breakdown',
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(8, (i) {
            final values = [3.2, 2.8, 4.1, 3.6, 5.0, 4.5, 5.8, 6.2];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppColors.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _ConversionChart extends StatelessWidget {
  const _ConversionChart();

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Conversion Rate',
      subtitle: 'Lead to customer conversion',
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 4.2), FlSpot(1, 4.5), FlSpot(2, 4.1), FlSpot(3, 5.0),
                FlSpot(4, 5.3), FlSpot(5, 5.8), FlSpot(6, 5.5), FlSpot(7, 6.1),
              ],
              isCurved: true,
              color: AppColors.success,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.success.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficSourceChart extends StatelessWidget {
  const _TrafficSourceChart();

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Traffic Sources',
      subtitle: 'Where users come from',
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            PieChartSectionData(value: 40, color: AppColors.primary, radius: 30, showTitle: false),
            PieChartSectionData(value: 25, color: AppColors.tertiary, radius: 30, showTitle: false),
            PieChartSectionData(value: 20, color: AppColors.secondary, radius: 30, showTitle: false),
            PieChartSectionData(value: 15, color: AppColors.success, radius: 30, showTitle: false),
          ],
        ),
      ),
    );
  }
}
