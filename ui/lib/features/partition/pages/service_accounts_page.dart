import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';

/// Placeholder page for Service Accounts management.
///
/// The ServiceAccount RPCs are not yet available in the current version
/// of `antinvestor_api_partition`. This page will be implemented once
/// the API is updated.
class ServiceAccountsPage extends ConsumerWidget {
  const ServiceAccountsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.engineering_outlined,
              size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 16),
          Text(
            'Service Accounts',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Service account management will be available in a future API update.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
