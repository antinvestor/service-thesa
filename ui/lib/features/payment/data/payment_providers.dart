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
