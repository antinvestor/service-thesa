import 'package:antinvestor_api_device/antinvestor_api_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [DeviceServiceClient] for device operations.
class DeviceRepository {
  DeviceRepository(this._client);

  final DeviceServiceClient _client;

  Future<List<DeviceObject>> search({String query = ''}) async {
    final items = <DeviceObject>[];
    await for (final response in _client.search(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<List<DeviceObject>> getById(List<String> ids,
      {bool extensive = false}) async {
    final response = await _client.getById(GetByIdRequest(
      id: ids,
      extensive: extensive,
    ));
    return response.data;
  }

  Future<List<DeviceLog>> listLogs(String deviceId, {int count = 20}) async {
    final items = <DeviceLog>[];
    await for (final response in _client.listLogs(ListLogsRequest(
      deviceId: deviceId,
      count: count,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<DeviceObject> link({
    required String id,
    required String profileId,
  }) async =>
      (await _client.link(LinkRequest(id: id, profileId: profileId))).data;
}

/// Riverpod provider for device repository.
final deviceRepositoryProvider =
    FutureProvider<DeviceRepository>((ref) async {
  final client = await ref.watch(deviceServiceClientProvider.future);
  return DeviceRepository(client);
});

/// Devices for a specific profile (by searching with profileId query).
final devicesForProfileProvider =
    FutureProvider.family<List<DeviceObject>, String>(
        (ref, profileId) async {
  final repo = await ref.watch(deviceRepositoryProvider.future);
  return repo.search(query: profileId);
});
