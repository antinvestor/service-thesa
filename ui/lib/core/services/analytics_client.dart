import 'dart:convert';

import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:antinvestor_ui_core/analytics/analytics_models.dart';

/// POST-based analytics query client for the Thesa BFF.
///
/// All requests flow through [AuthRuntime.fetch] so the access token is
/// attached automatically. Calls the generic proxy endpoints:
///   POST /api/analytics/query/scalar
///   POST /api/analytics/query/timeseries
///   POST /api/analytics/query/grouped
///   POST /api/analytics/query/topn
class ThesaAnalyticsClient {
  ThesaAnalyticsClient(this._runtime, this._baseUrl);

  final AuthRuntime _runtime;
  final String _baseUrl;

  /// Query a single scalar value (e.g. sum, avg, count).
  Future<double> queryScalar({
    required String metric,
    required String aggregation,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation,
      'filters': ?filters,
      ..._timeRangeFields(timeRange),
    };

    final data = await _post('/api/analytics/query/scalar', body);
    return (data['value'] as num?)?.toDouble() ?? 0.0;
  }

  /// Query time series data points.
  Future<List<TimeSeriesPoint>> queryTimeSeries({
    required String metric,
    String aggregation = 'sum',
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation,
      'filters': ?filters,
      ..._timeRangeFields(timeRange),
    };

    final data = await _post('/api/analytics/query/timeseries', body);
    final points = data['points'] as List<dynamic>? ?? [];

    return points.map((p) {
      final map = p as Map<String, dynamic>;
      return TimeSeriesPoint(
        timestamp: DateTime.parse(map['timestamp'] as String),
        value: (map['value'] as num).toDouble(),
        label: map['label'] as String?,
      );
    }).toList();
  }

  /// Query grouped/distribution data (e.g. for pie charts).
  Future<List<DistributionSegment>> queryGrouped({
    required String metric,
    required String groupBy,
    String aggregation = 'sum',
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'group_by': groupBy,
      'aggregation': aggregation,
      'filters': ?filters,
      ..._timeRangeFields(timeRange),
    };

    final data = await _post('/api/analytics/query/grouped', body);
    final segments = data['segments'] as List<dynamic>? ?? [];

    return segments.map((s) {
      final map = s as Map<String, dynamic>;
      return DistributionSegment(
        label: map['label'] as String,
        value: (map['value'] as num).toDouble(),
      );
    }).toList();
  }

  /// Query top-N ranked items.
  Future<List<TopNItem>> queryTopN({
    required String metric,
    String aggregation = 'sum',
    String? groupBy,
    int limit = 10,
    Map<String, String>? filters,
    AnalyticsTimeRange? timeRange,
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation,
      'limit': limit,
      'group_by': ?groupBy,
      'filters': ?filters,
      ..._timeRangeFields(timeRange),
    };

    final data = await _post('/api/analytics/query/topn', body);
    final items = data['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      final metadata = (map['metadata'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString()));
      return TopNItem(
        label: map['label'] as String,
        value: (map['value'] as num).toDouble(),
        metadata: metadata,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _timeRangeFields(AnalyticsTimeRange? tr) {
    if (tr == null) return {};
    return {
      'start': tr.start.toUtc().toIso8601String(),
      'end': tr.end.toUtc().toIso8601String(),
      if (tr.granularity != null) 'granularity': tr.granularity!.name,
    };
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await _runtime.fetch(
      '$_baseUrl$path',
      method: 'POST',
      headers: const {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.status != 200) {
      Map<String, dynamic>? parsed;
      try {
        parsed = json.decode(utf8.decode(response.body))
            as Map<String, dynamic>?;
      } catch (_) {
        parsed = null;
      }
      final msg = parsed?['error'] ?? 'HTTP ${response.status}';
      throw Exception('Analytics API error: $msg');
    }
    return json.decode(utf8.decode(response.body))
        as Map<String, dynamic>;
  }
}
