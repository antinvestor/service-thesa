import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/notification_providers.dart';

class NotificationAnalyticsPage extends ConsumerWidget {
  const NotificationAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(notificationsProvider);
    final asyncTemplates = ref.watch(templatesProvider);

    final notifCount = asyncNotifications.value?.length ?? 0;
    final templateCount = asyncTemplates.value?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Notification Service',
            breadcrumbs: ['Services', service.label, 'Analytics'],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _StatCard(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                value: '$notifCount',
                color: AppColors.tertiary,
              ),
              const SizedBox(width: 16),
              _StatCard(
                icon: Icons.description_outlined,
                label: 'Templates',
                value: '$templateCount',
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
