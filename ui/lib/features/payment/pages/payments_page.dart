import 'package:antinvestor_api_payment/antinvestor_api_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/payment_providers.dart';
import '../data/payment_repository.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPayments = ref.watch(paymentsProvider);

    return asyncPayments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load payments',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(paymentsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (payments) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Payments',
              breadcrumbs: ['Services', service.label, 'Payments'],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(paymentsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (payments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.payment,
                          size: 48, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 12),
                      const Text('No payments'),
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
                      DataColumn(label: Text('ROUTE')),
                      DataColumn(label: Text('AMOUNT')),
                      DataColumn(label: Text('STATE')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('DATE')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: payments.map((p) {
                      final amount = p.hasAmount()
                          ? '${p.amount.currencyCode} ${p.amount.units}.${p.amount.nanos.toString().padLeft(2, "0")}'
                          : '';
                      return DataRow(cells: [
                        DataCell(Text(p.id,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12))),
                        DataCell(Text(p.route)),
                        DataCell(Text(amount,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                        DataCell(_badge(p.state.name)),
                        DataCell(_badge(p.status.name)),
                        DataCell(Text(p.dateCreated)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_arrow,
                                  size: 16, color: AppColors.success),
                              tooltip: 'Release',
                              onPressed: () async {
                                final repo = await ref.read(
                                    paymentRepositoryProvider.future);
                                try {
                                  await repo.release(id: p.id);
                                  ref.invalidate(paymentsProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
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

  Widget _badge(String label) {
    final color = switch (label) {
      'SUCCESSFUL' || 'ACTIVE' => AppColors.success,
      'FAILED' || 'DELETED' => AppColors.error,
      'IN_PROCESS' || 'QUEUED' => AppColors.tertiary,
      _ => AppColors.onSurfaceMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
