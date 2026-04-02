import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart' show ProtobufEnum;

import '../../../core/theme/app_colors.dart';

/// Reusable badge for displaying protobuf STATE values.
class StateBadge extends StatelessWidget {
  const StateBadge(this.state, {super.key});

  final ProtobufEnum state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.name) {
      'ACTIVE' => ('ACTIVE', AppColors.success),
      'INACTIVE' => ('INACTIVE', AppColors.onSurfaceMuted),
      'DELETED' => ('DELETED', AppColors.error),
      _ => (state.name, AppColors.onSurfaceMuted),
    };

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

/// Badge for TenantEnvironment enum.
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = label.contains('PRODUCTION')
        ? AppColors.tertiary
        : label.contains('STAGING')
            ? AppColors.warning
            : AppColors.onSurfaceMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.replaceAll('TENANT_ENVIRONMENT_', ''),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Generic colored badge.
class ColorBadge extends StatelessWidget {
  const ColorBadge(this.label, this.color, {super.key});

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
