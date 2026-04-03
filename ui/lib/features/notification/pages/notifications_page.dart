import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(notificationsProvider);

    return asyncNotifications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load notifications',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(notificationsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (notifications) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Notifications',
              breadcrumbs: ['Services', service.label, 'Notifications'],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (notifications.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      const Text('No notifications'),
                    ],
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('TYPE')),
                      DataColumn(label: Text('TEMPLATE')),
                      DataColumn(label: Text('RECIPIENT')),
                      DataColumn(label: Text('PRIORITY')),
                      DataColumn(label: Text('OUTBOUND')),
                    ],
                    rows: notifications.map((n) {
                      final recipient = n.hasRecipient()
                          ? n.recipient.detail
                          : '';
                      return DataRow(cells: [
                        DataCell(Text(n.id,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12))),
                        DataCell(Text(n.type)),
                        DataCell(Text(n.template)),
                        DataCell(Text(recipient)),
                        DataCell(_PriorityBadge(n.priority.name)),
                        DataCell(Icon(
                          n.outBound
                              ? Icons.call_made
                              : Icons.call_received,
                          size: 16,
                          color: n.outBound
                              ? AppColors.tertiary
                              : AppColors.success,
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.priority);

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'HIGH' => AppColors.error,
      'LOW' => AppColors.onSurfaceMuted,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(priority,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
