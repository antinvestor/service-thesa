import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../data/ledger_repository.dart';
import '../data/payment_providers.dart';

/// Ledger detail at /services/payment/ledgers/:ledgerId.
/// Tabs: Overview | Accounts
class LedgerDetailPage extends ConsumerWidget {
  const LedgerDetailPage({super.key, required this.ledgerId});

  final String ledgerId;

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
            Text('Failed to load ledger',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (ledgers) {
        final ledger =
            ledgers.where((l) => l.id == ledgerId).firstOrNull;
        if (ledger == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ledger not found'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/services/payment/ledgers'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ],
            ),
          );
        }
        return _Content(ledger: ledger, ledgerId: ledgerId);
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.ledger, required this.ledgerId});

  final Ledger ledger;
  final String ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: 'Ledger: ${ledger.type.name}',
              breadcrumbs: [
                'Services',
                'Payment Service',
                'Ledgers',
                ledgerId,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/services/payment/ledgers'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ledger.type.name,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Text('ID: ${ledger.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Accounts'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(ledger: ledger),
                _AccountsTab(ledgerId: ledgerId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ledger Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _row(context, 'ID', ledger.id),
              _row(context, 'Type', ledger.type.name),
              if (ledger.parent.isNotEmpty) _row(context, 'Parent', ledger.parent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab({required this.ledgerId});

  final String ledgerId;

  Future<void> _createAccount(BuildContext context, WidgetRef ref) async {
    final values = await showEditDialog(
      context: context,
      title: 'New Account',
      saveLabel: 'Create',
      fields: const [
        DialogField(key: 'currency', label: 'Currency Code', hint: 'e.g. KES'),
      ],
    );
    if (values == null || !context.mounted) return;

    try {
      final repo = await ref.read(ledgerRepositoryProvider.future);
      await repo.createAccount(
        ledgerId: ledgerId,
        currency: values['currency'] ?? '',
      );
      ref.invalidate(accountsForLedgerProvider(ledgerId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccounts = ref.watch(accountsForLedgerProvider(ledgerId));

    return asyncAccounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load accounts',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
      ),
      data: (accounts) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _createAccount(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Account'),
                ),
              ],
            ),
          ),
          if (accounts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 48, color: AppColors.onSurfaceMuted),
                    const SizedBox(height: 12),
                    Text('No accounts for this ledger',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.onSurfaceMuted)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final balanceStr = account.hasBalance()
                      ? '${account.balance.currencyCode} ${account.balance.units}'
                      : '-';
                  return ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: AppColors.tertiary),
                    title: Text(account.id,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                            fontSize: 13)),
                    subtitle: Text('Balance: $balanceStr',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceMuted)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.go(
                        '/services/payment/ledgers/$ledgerId/accounts/${account.id}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
