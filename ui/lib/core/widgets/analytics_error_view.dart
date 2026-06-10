import 'package:antinvestor_ui_core/analytics/thesa_analytics_data_source.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Classifies an analytics gate failure into user-facing copy.
///
/// The hardened gate returns 400 for metric-allowlist / validation
/// rejections, 403 when the caller's JWT carries no tenant claims (or a
/// partition outside their access), and 5xx when the metrics backend is
/// unreachable.
({IconData icon, String title, String detail}) describeAnalyticsError(
  Object error,
) {
  if (error is AnalyticsQueryException) {
    return switch (error.statusCode) {
      401 || 403 => (
        icon: Icons.lock_outline,
        title: 'No analytics access',
        detail:
            'Your session has no tenant scope. Sign in with a tenant '
            'account or ask an administrator for analytics access.',
      ),
      400 => (
        icon: Icons.search_off_outlined,
        title: 'Query rejected',
        detail: error.message,
      ),
      >= 500 => (
        icon: Icons.cloud_off_outlined,
        title: 'Analytics unavailable',
        detail:
            'The analytics backend is temporarily unavailable. '
            'Please retry in a moment.',
      ),
      _ => (
        icon: Icons.error_outline,
        title: 'Analytics error (${error.statusCode})',
        detail: error.message,
      ),
    };
  }
  return (
    icon: Icons.wifi_off_outlined,
    title: 'Connection problem',
    detail:
        'Could not reach the analytics service. Check your connection '
        'and retry.',
  );
}

/// Friendly in-card error state for analytics widgets. Renders an icon,
/// a short title, classified detail copy, and an optional retry action.
class AnalyticsErrorView extends StatelessWidget {
  const AnalyticsErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Compact mode for small cards: single row, no retry button text.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = describeAnalyticsError(error);

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(info.icon, size: 16, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              info.title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ),
        ],
      );
    }

    // Scroll-safe: error copy length varies and host cards have fixed
    // heights, so absorb any overflow instead of breaking layout.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 28, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 8),
            Text(
              info.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                info.detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
