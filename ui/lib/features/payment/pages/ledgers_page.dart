import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/payment_providers.dart';

class LedgersPage extends ConsumerWidget {
  const LedgersPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLedgers = ref.watch(ledgersProvider);

    return asyncLedgers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load ledgers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(ledgersProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (ledgers) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Ledgers',
              breadcrumbs: ['Services', service.label, 'Ledgers'],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(ledgersProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (ledgers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      const Text('No ledgers'),
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
                child: Column(
                  children: [
                    for (var i = 0; i < ledgers.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          _ledgerIcon(ledgers[i].type),
                          size: 20,
                          color: _ledgerColor(ledgers[i].type),
                        ),
                        title: Text(ledgers[i].id,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                        subtitle: Text(ledgers[i].type.name,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceMuted)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.go(
                            '/services/payment/ledgers/${ledgers[i].id}'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _ledgerIcon(LedgerType type) => switch (type) {
        LedgerType.ASSET => Icons.trending_up,
        LedgerType.LIABILITY => Icons.trending_down,
        LedgerType.INCOME => Icons.arrow_downward,
        LedgerType.EXPENSE => Icons.arrow_upward,
        LedgerType.CAPITAL => Icons.account_balance,
        _ => Icons.book,
      };

  Color _ledgerColor(LedgerType type) => switch (type) {
        LedgerType.ASSET => AppColors.success,
        LedgerType.LIABILITY => AppColors.error,
        LedgerType.INCOME => AppColors.tertiary,
        LedgerType.EXPENSE => Colors.orange,
        LedgerType.CAPITAL => AppColors.primary,
        _ => AppColors.onSurfaceMuted,
      };
}
