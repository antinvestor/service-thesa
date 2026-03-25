import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.time,
    this.iconColor,
    this.statusIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final String time;
  final Color? iconColor;
  final IconData? statusIcon;
}

const _sampleActivities = [
  ActivityItem(
    icon: Icons.shopping_cart_outlined,
    title: 'Equity Purchase',
    subtitle: 'Portfolio: Blue-Chip Tech',
    meta: '\$12,400.00',
    time: '2 mins ago',
    iconColor: AppColors.success,
    statusIcon: Icons.check_circle,
  ),
  ActivityItem(
    icon: Icons.person_add_outlined,
    title: 'New User Onboarded',
    subtitle: 'User: Marcus Aurelius',
    meta: 'KYC Verified',
    time: '15 mins ago',
    iconColor: AppColors.tertiary,
  ),
  ActivityItem(
    icon: Icons.warning_amber_outlined,
    title: 'High Volatility Alert',
    subtitle: 'Asset: ETH/USD (-8.2%)',
    meta: 'System Trigger',
    time: '1 hour ago',
    iconColor: AppColors.warning,
  ),
  ActivityItem(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Dividend Payout',
    subtitle: 'Quarterly payout processed',
    meta: '\$452,000.00',
    time: '3 hours ago',
    iconColor: AppColors.success,
  ),
  ActivityItem(
    icon: Icons.description_outlined,
    title: 'Q3 Report Generated',
    subtitle: 'Global compliance audit ready',
    meta: '68 MB \u2022 PDF',
    time: '5 hours ago',
    iconColor: AppColors.onSurfaceMuted,
  ),
];

class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key});

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
          Row(
            children: [
              Expanded(
                child: Text('Recent Activities',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
          Text(
            'Live stream of terminal events',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ..._sampleActivities.map((a) => _ActivityTile(item: a)),
          const SizedBox(height: 16),
          // Upgrade CTA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primarySwatch[800]!],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade Terminal',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get access to real-time order flow and institutional insights.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                    ),
                    child: const Text('GO PREMIUM'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (item.iconColor ?? AppColors.tertiary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 18, color: item.iconColor ?? AppColors.tertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.meta,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      ' \u2022 ',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      item.time,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
