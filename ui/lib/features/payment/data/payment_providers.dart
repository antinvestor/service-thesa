import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:antinvestor_api_payment/antinvestor_api_payment.dart'
    hide Account;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ledger_repository.dart';
import 'payment_repository.dart';

/// All payments.
final paymentsProvider =
    FutureProvider<List<Payment>>((ref) async {
  final repo = await ref.watch(paymentRepositoryProvider.future);
  return repo.search();
});

/// All ledgers.
final ledgersProvider =
    FutureProvider<List<Ledger>>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.searchLedgers();
});

/// All accounts.
final accountsProvider =
    FutureProvider<List<Account>>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.searchAccounts();
});

/// All transactions.
final transactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.searchTransactions();
});

/// Accounts scoped to a specific ledger.
final accountsForLedgerProvider =
    FutureProvider.family<List<Account>, String>((ref, ledgerId) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.searchAccounts(query: ledgerId);
});

/// Transaction entries scoped to a specific account.
final entriesForAccountProvider =
    FutureProvider.family<List<TransactionEntry>, String>(
        (ref, accountId) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.searchTransactionEntries(query: accountId);
});
