import 'package:antinvestor_api_notification/antinvestor_api_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [NotificationServiceClient] for notification operations.
class NotificationRepository {
  NotificationRepository(this._client);

  final NotificationServiceClient _client;

  // ── Notifications ───────────────────────────────────────────────────────

  Future<List<Notification>> search({String query = ''}) async {
    final items = <Notification>[];
    await for (final response in _client.search(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<StatusResponse> status(String id) async =>
      _client.status(StatusRequest(id: id));

  Future<StatusUpdateResponse> statusUpdate({
    required String id,
    required STATE state,
  }) async =>
      _client.statusUpdate(StatusUpdateRequest(
        id: id,
        state: state,
      ));

  // ── Templates ───────────────────────────────────────────────────────────

  Future<List<Template>> searchTemplates({
    String query = '',
    String languageCode = '',
  }) async {
    final items = <Template>[];
    await for (final response in _client.templateSearch(
      TemplateSearchRequest(
        query: query,
        languageCode: languageCode,
      ),
    )) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<Template> saveTemplate({
    required String name,
    String languageCode = '',
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.templateSave(TemplateSaveRequest(
      name: name,
      languageCode: languageCode,
    ));
    return response.data;
  }
}

final notificationRepositoryProvider =
    FutureProvider<NotificationRepository>((ref) async {
  final client = await ref.watch(notificationServiceClientProvider.future);
  return NotificationRepository(client);
});
