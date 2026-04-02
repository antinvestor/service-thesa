import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [SettingsServiceClient] for all settings operations.
class SettingsRepository {
  SettingsRepository(this._client);

  final SettingsServiceClient _client;

  Future<List<SettingObject>> search({String query = ''}) async {
    final items = <SettingObject>[];
    await for (final response in _client.search(
      SearchRequest(query: query),
    )) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<List<SettingObject>> list({
    String name = '',
    String object = '',
    String objectId = '',
    String lang = '',
    String module = '',
  }) async {
    final items = <SettingObject>[];
    await for (final response in _client.list(
      ListRequest(
        key: Setting(
          name: name.isEmpty ? null : name,
          object: object.isEmpty ? null : object,
          objectId: objectId.isEmpty ? null : objectId,
          lang: lang.isEmpty ? null : lang,
          module: module.isEmpty ? null : module,
        ),
      ),
    )) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<SettingObject> get({
    required String name,
    String object = '',
    String objectId = '',
    String lang = '',
    String module = '',
  }) async {
    final response = await _client.get(
      GetRequest(
        key: Setting(
          name: name,
          object: object.isEmpty ? null : object,
          objectId: objectId.isEmpty ? null : objectId,
          lang: lang.isEmpty ? null : lang,
          module: module.isEmpty ? null : module,
        ),
      ),
    );
    return response.data;
  }

  Future<SettingObject> set({
    required String name,
    required String value,
    String object = '',
    String objectId = '',
    String lang = '',
    String module = '',
  }) async {
    final response = await _client.set(
      SetRequest(
        key: Setting(
          name: name,
          object: object.isEmpty ? null : object,
          objectId: objectId.isEmpty ? null : objectId,
          lang: lang.isEmpty ? null : lang,
          module: module.isEmpty ? null : module,
        ),
        value: value,
      ),
    );
    return response.data;
  }
}

final settingsRepositoryProvider =
    FutureProvider<SettingsRepository>((ref) async {
  final client = await ref.watch(settingsServiceClientProvider.future);
  return SettingsRepository(client);
});
