import 'dart:async';

import 'package:antinvestor_api_audit/antinvestor_api_audit.dart'
    show AuditEntryObject, Timestamp;
import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart'
    show AuditEntryTile, AuditListParams, auditEntriesProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';

const _kFeedCount = 6;
const _kRefreshInterval = Duration(seconds: 30);

/// Dashboard activity feed backed by the audit service.
///
/// Shows the most recent audit trail entries across all services for the
/// active tenant/partition, refreshing every [_kRefreshInterval]. VIEW ALL
/// opens the full audit log.
class ActivityFeed extends ConsumerStatefulWidget {
  const ActivityFeed({super.key});

  @override
  ConsumerState<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends ConsumerState<ActivityFeed> {
  static const _params = AuditListParams(count: _kFeedCount);

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(_kRefreshInterval, (_) {
      if (mounted) {
        ref.invalidate(auditEntriesProvider(_params));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(auditEntriesProvider(_params));

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
                child: Text(
                  'Recent Activities',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/services/audit/log'),
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
          Text(
            'Live stream of audit trail events',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          asyncEntries.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _FeedMessage(
              icon: Icons.error_outline,
              color: AppColors.warning,
              message: 'Could not load activity',
            ),
            data: (entries) => entries.isEmpty
                ? const _FeedMessage(
                    icon: Icons.inbox_outlined,
                    color: AppColors.onSurfaceMuted,
                    message: 'No recent activity',
                  )
                : Column(
                    children: [
                      for (final entry in entries)
                        _ActivityTile(entry: entry),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final AuditEntryObject entry;

  String get _title {
    final action = entry.action.isEmpty ? 'activity' : entry.action;
    final resource = entry.resourceType.replaceAll('_', ' ');
    final label = resource.isEmpty ? action : '$action $resource';
    return label[0].toUpperCase() + label.substring(1);
  }

  String get _subtitle {
    if (entry.resourceId.isNotEmpty) return entry.resourceId;
    if (entry.profileId.isNotEmpty) return 'Actor: ${entry.profileId}';
    return '—';
  }

  String get _serviceLabel => entry.service.isEmpty
      ? 'platform'
      : entry.service.replaceFirst('service_', '');

  static String _relativeTime(Timestamp ts) {
    if (!ts.hasSeconds()) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      ts.seconds.toInt() * 1000 + ts.nanos ~/ 1000000,
    );
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AuditEntryTile.colorForAction(entry.action, theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              AuditEntryTile.iconForAction(entry.action),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _serviceLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(' • ', style: theme.textTheme.labelSmall),
                    Text(
                      _relativeTime(entry.createdAt),
                      style: theme.textTheme.labelSmall,
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
