import 'package:antinvestor_api_common/antinvestor_api_common.dart'
    hide Timestamp, Struct;
import 'package:antinvestor_api_geolocation/antinvestor_api_geolocation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';

import '../../../core/services/api_config.dart';
import '../../../core/services/connect_client.dart';
import '../../../core/services/transport/transport.dart';

// ─── Client Provider ──────────────────────────────────────────────────────────

/// Geolocation API client provider.
final geolocationClientProvider =
    FutureProvider<ConnectClientBase<GeolocationServiceClient>>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);

  await tokenManager.initialize();

  return newClient<GeolocationServiceClient>(
    defaultEndpoint: 'https://geolocation.antinvestor.com',
    createServiceClient: GeolocationServiceClient.new,
    createTransport: createTransportFactory(),
    endpoint: ApiConfig.geolocationBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
  );
});

/// Expose the raw GeolocationServiceClient stub.
final geolocationServiceClientProvider =
    FutureProvider<GeolocationServiceClient>((ref) async {
  final client = await ref.watch(geolocationClientProvider.future);
  return client.stub;
});

// ─── Repository ───────────────────────────────────────────────────────────────

class GeolocationRepository {
  GeolocationRepository(this._client);

  final GeolocationServiceClient _client;

  /// Get location track for a subject within a time range.
  Future<List<LocationPointObject>> getTrack({
    required String subjectId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final response = await _client.getTrack(GetTrackRequest(
      subjectId: subjectId,
      from: from != null ? _toTimestamp(from) : null,
      to: to != null ? _toTimestamp(to) : null,
      limit: limit,
    ));
    return response.data;
  }

  /// Get geofence events for a subject.
  Future<List<GeoEventObject>> getSubjectEvents({
    required String subjectId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final response = await _client.getSubjectEvents(GetSubjectEventsRequest(
      subjectId: subjectId,
      from: from != null ? _toTimestamp(from) : null,
      to: to != null ? _toTimestamp(to) : null,
      limit: limit,
    ));
    return response.data;
  }

  /// Get route assignments for a subject.
  Future<List<RouteAssignmentObject>> getSubjectRouteAssignments({
    required String subjectId,
  }) async {
    final response = await _client.getSubjectRouteAssignments(
      GetSubjectRouteAssignmentsRequest(subjectId: subjectId),
    );
    return response.data;
  }

  /// Search geofence areas.
  Future<List<AreaObject>> searchAreas({
    String query = '',
    String ownerId = '',
    int limit = 50,
  }) async {
    final response = await _client.searchAreas(SearchAreasRequest(
      query: query,
      ownerId: ownerId,
      limit: limit,
    ));
    return response.data;
  }

  /// Get a route by ID.
  Future<RouteObject> getRoute(String id) async {
    final response = await _client.getRoute(GetRouteRequest(id: id));
    return response.data;
  }

  /// Search routes.
  Future<List<RouteObject>> searchRoutes({
    String ownerId = '',
    int limit = 50,
  }) async {
    final response = await _client.searchRoutes(SearchRoutesRequest(
      ownerId: ownerId,
      limit: limit,
    ));
    return response.data;
  }

  static Timestamp _toTimestamp(DateTime dt) {
    final utc = dt.toUtc();
    return Timestamp(
      seconds: Int64(utc.millisecondsSinceEpoch ~/ 1000),
      nanos: utc.microsecond * 1000,
    );
  }
}

/// Riverpod provider for geolocation repository.
final geolocationRepositoryProvider =
    FutureProvider<GeolocationRepository>((ref) async {
  final client = await ref.watch(geolocationServiceClientProvider.future);
  return GeolocationRepository(client);
});

// ─── Data Providers ───────────────────────────────────────────────────────────

/// Location track for a profile (subject).
final trackForSubjectProvider = FutureProvider.family<
    List<LocationPointObject>,
    ({String subjectId, DateTime? from, DateTime? to})>(
  (ref, params) async {
    final repo = await ref.watch(geolocationRepositoryProvider.future);
    return repo.getTrack(
      subjectId: params.subjectId,
      from: params.from,
      to: params.to,
    );
  },
);

/// Geofence events for a profile (subject).
final geoEventsForSubjectProvider =
    FutureProvider.family<List<GeoEventObject>, String>(
  (ref, subjectId) async {
    final repo = await ref.watch(geolocationRepositoryProvider.future);
    return repo.getSubjectEvents(subjectId: subjectId);
  },
);

/// Route assignments for a profile (subject).
final routeAssignmentsForSubjectProvider =
    FutureProvider.family<List<RouteAssignmentObject>, String>(
  (ref, subjectId) async {
    final repo = await ref.watch(geolocationRepositoryProvider.future);
    return repo.getSubjectRouteAssignments(subjectId: subjectId);
  },
);
