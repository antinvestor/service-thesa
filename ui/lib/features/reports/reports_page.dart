import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/responsive_layout.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = screenSizeOf(context);
    final crossCount = screenSize == ScreenSize.mobile ? 1 : screenSize == ScreenSize.tablet ? 2 : 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Reports',
            breadcrumbs: const ['Dashboard', 'Reports'],
            actions: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Generate Report'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: const [
              _ReportCard(
                icon: Icons.assessment,
                title: 'Q3 Financial Report',
                subtitle: 'Comprehensive quarterly overview',
                date: 'Generated Apr 10, 2024',
                size: '68 MB',
                status: 'Ready',
              ),
              _ReportCard(
                icon: Icons.security,
                title: 'Compliance Audit',
                subtitle: 'Regulatory compliance check',
                date: 'Generated Apr 5, 2024',
                size: '24 MB',
                status: 'Ready',
              ),
              _ReportCard(
                icon: Icons.people,
                title: 'User Activity Report',
                subtitle: 'Monthly user behavior analysis',
                date: 'Generated Apr 1, 2024',
                size: '12 MB',
                status: 'Ready',
              ),
              _ReportCard(
                icon: Icons.trending_up,
                title: 'Portfolio Performance',
                subtitle: 'Investment returns analysis',
                date: 'Generating...',
                size: '',
                status: 'Processing',
              ),
              _ReportCard(
                icon: Icons.account_balance,
                title: 'Tax Summary',
                subtitle: 'Annual tax documentation',
                date: 'Generated Mar 31, 2024',
                size: '8 MB',
                status: 'Ready',
              ),
              _ReportCard(
                icon: Icons.analytics,
                title: 'Risk Assessment',
                subtitle: 'Portfolio risk analysis',
                date: 'Generated Mar 28, 2024',
                size: '15 MB',
                status: 'Ready',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.size,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
  final String size;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isReady = status == 'Ready';

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tertiarySwatch[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.tertiary, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isReady ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(date, style: Theme.of(context).textTheme.labelSmall),
              if (size.isNotEmpty) ...[
                Text(' \u2022 ', style: Theme.of(context).textTheme.labelSmall),
                Text(size, style: Theme.of(context).textTheme.labelSmall),
              ],
              const Spacer(),
              if (isReady)
                Icon(Icons.download_outlined, size: 18, color: AppColors.tertiary),
            ],
          ),
        ],
      ),
    );
  }
}
