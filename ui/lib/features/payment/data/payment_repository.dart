import 'package:antinvestor_api_payment/antinvestor_api_payment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [PaymentServiceClient] for payment operations.
class PaymentRepository {
  PaymentRepository(this._client);

  final PaymentServiceClient _client;

  Future<List<Payment>> search({String query = ''}) async {
    final items = <Payment>[];
    await for (final response in _client.search(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<StatusResponse> status(String id) async =>
      _client.status(StatusRequest(id: id));

  Future<ReleaseResponse> release({
    required String id,
    String comment = '',
  }) async =>
      _client.release(ReleaseRequest(id: id, comment: comment));
}

final paymentRepositoryProvider =
    FutureProvider<PaymentRepository>((ref) async {
  final client = await ref.watch(paymentServiceClientProvider.future);
  return PaymentRepository(client);
});
