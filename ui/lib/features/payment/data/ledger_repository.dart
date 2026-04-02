import 'package:antinvestor_api_ledger/antinvestor_api_ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [LedgerServiceClient] for ledger operations.
class LedgerRepository {
  LedgerRepository(this._client);

  final LedgerServiceClient _client;

  // ── Ledgers ─────────────────────────────────────────────────────────────

  Future<List<Ledger>> searchLedgers({String query = ''}) async {
    final items = <Ledger>[];
    await for (final response in _client.searchLedgers(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<Ledger> createLedger({
    required String id,
    required LedgerType type,
    String parentId = '',
  }) async =>
      (await _client.createLedger(CreateLedgerRequest(
        id: id,
        type: type,
        parentId: parentId,
      )))
          .data;

  // ── Accounts ────────────────────────────────────────────────────────────

  Future<List<Account>> searchAccounts({String query = ''}) async {
    final items = <Account>[];
    await for (final response in _client.searchAccounts(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<Account> createAccount({
    String? id,
    required String ledgerId,
    required String currency,
  }) async =>
      (await _client.createAccount(CreateAccountRequest(
        id: id,
        ledgerId: ledgerId,
        currency: currency,
      )))
          .data;

  // ── Transactions ────────────────────────────────────────────────────────

  Future<List<Transaction>> searchTransactions({String query = ''}) async {
    final items = <Transaction>[];
    await for (final response in _client.searchTransactions(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<Transaction> reverseTransaction(String id) async =>
      (await _client.reverseTransaction(ReverseTransactionRequest(id: id)))
          .data;

  // ── Transaction Entries ─────────────────────────────────────────────────

  Future<List<TransactionEntry>> searchTransactionEntries(
      {String query = ''}) async {
    final items = <TransactionEntry>[];
    await for (final response in _client.searchTransactionEntries(
        SearchRequest(query: query))) {
      items.addAll(response.data);
    }
    return items;
  }
}

final ledgerRepositoryProvider =
    FutureProvider<LedgerRepository>((ref) async {
  final client = await ref.watch(ledgerServiceClientProvider.future);
  return LedgerRepository(client);
});
