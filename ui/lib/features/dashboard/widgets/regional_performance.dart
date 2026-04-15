import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class RegionalPerformance extends ConsumerWidget {
  const RegionalPerformance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = AnalyticsTimeRange.last30Days();
    final topNAsync = ref.watch(
      serviceTopNProvider(
        ServiceTopNParams('payment', 'top_recipients',
            limit: 5, timeRange: timeRange),
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
          Text('Top Recipients',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Highest volume payment recipients',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          topNAsync.when(
            data: (items) => _buildBars(context, items),
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SizedBox(
              height: 120,
              child: Center(
                child: Text('Unable to load data',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBars(BuildContext context, List<TopNItem> items) {
    if (items.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('No data available',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }

    final maxValue = items.fold(0.0, (m, i) => i.value > m ? i.value : m);

    return Column(
      children: items.map((item) {
        final fraction = maxValue > 0 ? item.value / maxValue : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ProgressBar(
            label: item.label,
            value: fraction,
            display: _formatValue(item.value),
          ),
        );
      }).toList(),
    );
  }

  static String _formatValue(double value) {
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(1)}K';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
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
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              display,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.tertiary),
          ),
        ),
      ],
    );
  }
}
