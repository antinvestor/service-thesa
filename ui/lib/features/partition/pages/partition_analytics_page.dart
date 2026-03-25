import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/service_analytics_page.dart';
import '../data/partition_providers.dart';

class PartitionAnalyticsPage extends ConsumerWidget {
  const PartitionAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider);
    final partitionsAsync = ref.watch(partitionsProvider);
    final rolesAsync = ref.watch(partitionRolesProvider);

    final tenantsCount = tenantsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final partitionsCount =
        partitionsAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final rolesCount = rolesAsync.whenOrNull(data: (d) => d.length) ?? 0;

    return ServiceAnalyticsPage(
      title: 'Partition Service',
      breadcrumbs: ['Services', 'Partition Service', 'Analytics'],
      kpis: [
        ServiceKpi(
          label: 'Total Tenants',
          value: '$tenantsCount',
          icon: Icons.domain_outlined,
        ),
        ServiceKpi(
          label: 'Total Partitions',
          value: '$partitionsCount',
          icon: Icons.account_tree_outlined,
        ),
        ServiceKpi(
          label: 'Total Roles',
          value: '$rolesCount',
          icon: Icons.security_outlined,
        ),
      ],
      chartTitle: 'Partition Growth',
      chartSubtitle: '12-month network-wide scaling metrics',
      chartWidget: _PartitionGrowthChart(),
      events: const [
        ServiceEvent(
          title: 'New Partition Created',
          timeAgo: '2 mins ago',
          severity: EventSeverity.success,
          icon: Icons.add_box_outlined,
        ),
        ServiceEvent(
          title: 'Security Policy Update',
          timeAgo: '45 mins ago',
          severity: EventSeverity.warning,
          icon: Icons.shield_outlined,
        ),
        ServiceEvent(
          title: 'Threshold Alert',
          timeAgo: '3 hours ago',
          severity: EventSeverity.error,
          icon: Icons.warning_amber,
        ),
        ServiceEvent(
          title: 'Tenant Onboarded',
          timeAgo: '5 hours ago',
          severity: EventSeverity.info,
        ),
      ],
      bottomSection: _buildTopTenants(context),
    );
  }

  Widget _buildTopTenants(BuildContext context) {
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
          Text('Top Performing Tenants',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('ORGANIZATION')),
                DataColumn(label: Text('PARTITIONS'), numeric: true),
                DataColumn(label: Text('IOPS AVG')),
                DataColumn(label: Text('SECURITY SCORE')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('Vortex Dynamics')),
                  DataCell(Text('2,490')),
                  DataCell(Text('14.2k/s')),
                  DataCell(Text('98%')),
                  DataCell(_StatusBadge('OPTIMIZED', AppColors.success)),
                ]),
                DataRow(cells: [
                  DataCell(Text('Nexus Logistics')),
                  DataCell(Text('1,823')),
                  DataCell(Text('11.8k/s')),
                  DataCell(Text('95%')),
                  DataCell(_StatusBadge('OPTIMIZED', AppColors.success)),
                ]),
                DataRow(cells: [
                  DataCell(Text('Atlas Industries')),
                  DataCell(Text('1,204')),
                  DataCell(Text('9.4k/s')),
                  DataCell(Text('87%')),
                  DataCell(_StatusBadge('ACTIVE', AppColors.info)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PartitionGrowthChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 2000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(months[value.toInt()],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.onSurfaceMuted)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.onSurfaceMuted));
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        barGroups: List.generate(12, (i) {
          final values = [
            800, 950, 1100, 1050, 1200, 1400,
            1350, 1500, 1600, 1550, 1700, 1850,
          ];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i].toDouble(),
                color: AppColors.tertiary,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
