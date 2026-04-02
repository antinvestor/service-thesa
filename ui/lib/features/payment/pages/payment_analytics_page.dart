import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/payment_providers.dart';

class PaymentAnalyticsPage extends ConsumerWidget {
  const PaymentAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentCount = ref.watch(paymentsProvider).value?.length ?? 0;
    final ledgerCount = ref.watch(ledgersProvider).value?.length ?? 0;
    final accountCount = ref.watch(accountsProvider).value?.length ?? 0;
    final txCount = ref.watch(transactionsProvider).value?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Payment Service',
            breadcrumbs: ['Services', service.label, 'Analytics'],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(Icons.payment, 'Payments', '$paymentCount',
                  AppColors.tertiary),
              _StatCard(Icons.account_balance, 'Ledgers', '$ledgerCount',
                  AppColors.primary),
              _StatCard(Icons.account_balance_wallet, 'Accounts',
                  '$accountCount', AppColors.success),
              _StatCard(Icons.receipt_long, 'Transactions', '$txCount',
                  Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.label, this.value, this.color);

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
