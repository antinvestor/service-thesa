import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/payment_providers.dart';

/// Account detail at /services/payment/ledgers/:ledgerId/accounts/:accountId.
/// Tabs: Overview | Transaction Entries
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({
    super.key,
    required this.ledgerId,
    required this.accountId,
  });

  final String ledgerId;
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccounts = ref.watch(accountsForLedgerProvider(ledgerId));

    return asyncAccounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load account',
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
      data: (accounts) {
        final account =
            accounts.where((a) => a.id == accountId).firstOrNull;
        if (account == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Account not found'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/services/payment/ledgers/$ledgerId'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Ledger'),
                ),
              ],
            ),
          );
        }
        return _Content(
          account: account,
          ledgerId: ledgerId,
          accountId: accountId,
        );
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.account,
    required this.ledgerId,
    required this.accountId,
  });

  final Account account;
  final String ledgerId;
  final String accountId;

  String _money(dynamic m) {
    if (m == null) return '-';
    try {
      return '${m.currencyCode} ${m.units}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceStr = account.hasBalance() ? _money(account.balance) : '-';

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: 'Account',
              breadcrumbs: [
                'Services',
                'Payment Service',
                'Ledgers',
                ledgerId,
                'Accounts',
                accountId,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/services/payment/ledgers/$ledgerId'),
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
                Text('Balance: $balanceStr',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Text('Ledger: ${account.ledger}',
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
              Tab(text: 'Transaction Entries'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(account: account),
                _EntriesTab(accountId: accountId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.account});

  final Account account;

  String _money(dynamic m) {
    try {
      return '${m.currencyCode} ${m.units}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BalanceCard('Balance',
                account.hasBalance() ? _money(account.balance) : '-',
                AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BalanceCard(
                'Uncleared',
                account.hasUnclearedBalance()
                    ? _money(account.unclearedBalance)
                    : '-',
                AppColors.warning),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BalanceCard(
                'Reserved',
                account.hasReservedBalance()
                    ? _money(account.reservedBalance)
                    : '-',
                AppColors.tertiary),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EntriesTab extends ConsumerWidget {
  const _EntriesTab({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(entriesForAccountProvider(accountId));

    return asyncEntries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load entries',
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
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: AppColors.onSurfaceMuted),
                const SizedBox(height: 12),
                Text('No transaction entries',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final amountStr = entry.hasAmount()
                ? '${entry.amount.currencyCode} ${entry.amount.units}'
                : '-';
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: entry.credit
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  entry.credit ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color:
                      entry.credit ? AppColors.success : AppColors.error,
                ),
              ),
              title: Text(amountStr,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${entry.credit ? "Credit" : "Debit"} · ${entry.transactedAt}',
                style: TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceMuted),
              ),
              trailing: entry.clearedAt.isNotEmpty
                  ? _badge('CLEARED', AppColors.success)
                  : _badge('PENDING', AppColors.warning),
            );
          },
        );
      },
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
