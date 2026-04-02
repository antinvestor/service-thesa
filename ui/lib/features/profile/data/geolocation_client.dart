import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_repository.dart';

/// Lightweight Connect-JSON client for the Geolocation service.
///
/// Since there's no generated Dart client yet, this calls the Connect
/// protocol's JSON endpoints directly.
class GeolocationClient {
  GeolocationClient({
    required this.baseUrl,
    required this.getAccessToken,
  });

  final String baseUrl;
  final Future<String?> Function() getAccessToken;

  Future<Map<String, dynamic>> _call(
      String method, Map<String, dynamic> body) async {
    final url = '$baseUrl/geolocation.v1.GeolocationService/$method';
    final token = await getAccessToken();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Connect-Protocol-Version': '1',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Geolocation API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      final error = data['error'] as Map<String, dynamic>;
      throw Exception('[${error['code']}] ${error['message']}');
    }
    return data;
  }

  /// Get location track for a subject within a time range.
  Future<List<LocationPoint>> getTrack({
    required String subjectId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final body = <String, dynamic>{
      'subjectId': subjectId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      'limit': limit,
    };
    final result = await _call('GetTrack', body);
    final data = result['data'] as List<dynamic>? ?? [];
    return data.map((e) => LocationPoint.fromJson(e)).toList();
  }

  /// Get geofence events for a subject.
  Future<List<GeoEvent>> getSubjectEvents({
    required String subjectId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final body = <String, dynamic>{
      'subjectId': subjectId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      'limit': limit,
    };
    final result = await _call('GetSubjectEvents', body);
    final data = result['data'] as List<dynamic>? ?? [];
    return data.map((e) => GeoEvent.fromJson(e)).toList();
  }

  /// Get route assignments for a subject.
  Future<List<RouteAssignment>> getSubjectRouteAssignments({
    required String subjectId,
  }) async {
    final result = await _call(
        'GetSubjectRouteAssignments', {'subjectId': subjectId});
    final data = result['data'] as List<dynamic>? ?? [];
    return data.map((e) => RouteAssignment.fromJson(e)).toList();
  }

  /// Search areas (geofences).
  Future<List<GeoArea>> searchAreas({String query = '', int limit = 50}) async {
    final result =
        await _call('SearchAreas', {'query': query, 'limit': limit});
    final data = result['data'] as List<dynamic>? ?? [];
    return data.map((e) => GeoArea.fromJson(e)).toList();
  }

  /// Get route details.
  Future<GeoRoute> getRoute(String id) async {
    final result = await _call('GetRoute', {'id': id});
    return GeoRoute.fromJson(result['data'] as Map<String, dynamic>);
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class LocationPoint {
  final String id;
  final String subjectId;
  final String? deviceId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speed;
  final double? bearing;
  final String source;
  final DateTime? timestamp;

  LocationPoint({
    required this.id,
    required this.subjectId,
    this.deviceId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.speed,
    this.bearing,
    required this.source,
    this.timestamp,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? '',
      deviceId: json['deviceId'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      altitude: json['altitude']?.toDouble(),
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      speed: json['speed']?.toDouble(),
      bearing: json['bearing']?.toDouble(),
      source: _sourceLabel(json['source'] ?? ''),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
    );
  }

  static String _sourceLabel(String source) => switch (source) {
        'LOCATION_SOURCE_GPS' => 'GPS',
        'LOCATION_SOURCE_NETWORK' => 'Network',
        'LOCATION_SOURCE_IP' => 'IP',
        'LOCATION_SOURCE_MANUAL' => 'Manual',
        _ => source,
      };
}

class GeoEvent {
  final String id;
  final String subjectId;
  final String areaId;
  final String eventType;
  final double confidence;
  final DateTime? timestamp;

  GeoEvent({
    required this.id,
    required this.subjectId,
    required this.areaId,
    required this.eventType,
    required this.confidence,
    this.timestamp,
  });

  factory GeoEvent.fromJson(Map<String, dynamic> json) {
    return GeoEvent(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? '',
      areaId: json['areaId'] ?? '',
      eventType: _eventLabel(json['eventType'] ?? ''),
      confidence: (json['confidence'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
    );
  }

  static String _eventLabel(String type) => switch (type) {
        'GEO_EVENT_TYPE_ENTER' => 'Entered',
        'GEO_EVENT_TYPE_EXIT' => 'Exited',
        'GEO_EVENT_TYPE_DWELL' => 'Dwelling',
        _ => type,
      };
}

class RouteAssignment {
  final String id;
  final String subjectId;
  final String routeId;
  final DateTime? validFrom;
  final DateTime? validUntil;

  RouteAssignment({
    required this.id,
    required this.subjectId,
    required this.routeId,
    this.validFrom,
    this.validUntil,
  });

  factory RouteAssignment.fromJson(Map<String, dynamic> json) {
    return RouteAssignment(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? '',
      routeId: json['routeId'] ?? '',
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'])
          : null,
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'])
          : null,
    );
  }
}

class GeoArea {
  final String id;
  final String name;
  final String description;
  final String areaType;
  final String geometry;
  final double areaM2;

  GeoArea({
    required this.id,
    required this.name,
    required this.description,
    required this.areaType,
    required this.geometry,
    required this.areaM2,
  });

  factory GeoArea.fromJson(Map<String, dynamic> json) {
    return GeoArea(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      areaType: json['areaType'] ?? '',
      geometry: json['geometry'] ?? '',
      areaM2: (json['areaM2'] ?? 0).toDouble(),
    );
  }
}

class GeoRoute {
  final String id;
  final String name;
  final String description;
  final double lengthM;
  final double? deviationThresholdM;

  GeoRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.lengthM,
    this.deviationThresholdM,
  });

  factory GeoRoute.fromJson(Map<String, dynamic> json) {
    return GeoRoute(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      lengthM: (json['lengthM'] ?? 0).toDouble(),
      deviationThresholdM: json['deviationThresholdM']?.toDouble(),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final geolocationClientProvider = Provider<GeolocationClient>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return GeolocationClient(
    baseUrl: ApiConfig.geolocationBaseUrl,
    getAccessToken: () => authRepo.getAccessToken(),
  );
});

/// Location track for a profile (subject).
final trackForSubjectProvider = FutureProvider.family<List<LocationPoint>,
    ({String subjectId, DateTime? from, DateTime? to})>(
  (ref, params) async {
    final client = ref.watch(geolocationClientProvider);
    return client.getTrack(
      subjectId: params.subjectId,
      from: params.from,
      to: params.to,
    );
  },
);

/// Geofence events for a profile (subject).
final geoEventsForSubjectProvider =
    FutureProvider.family<List<GeoEvent>, String>(
  (ref, subjectId) async {
    final client = ref.watch(geolocationClientProvider);
    return client.getSubjectEvents(subjectId: subjectId);
  },
);

/// Route assignments for a profile (subject).
final routeAssignmentsForSubjectProvider =
    FutureProvider.family<List<RouteAssignment>, String>(
  (ref, subjectId) async {
    final client = ref.watch(geolocationClientProvider);
    return client.getSubjectRouteAssignments(subjectId: subjectId);
  },
);
