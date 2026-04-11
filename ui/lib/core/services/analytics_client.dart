import 'dart:convert';

import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Implements [AnalyticsDataSource] by calling Thesa's analytics REST API.
class ThesaAnalyticsDataSource implements AnalyticsDataSource {
  ThesaAnalyticsDataSource(this._httpClient, this._baseUrl);

  final http.Client _httpClient;
  final String _baseUrl;

  @override
  Future<List<MetricValue>> getMetrics(
    String service, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final params = {
      'service': service,
      ...?(timeRange?.toQueryParams()),
    };
    final uri =
        Uri.parse('$_baseUrl/api/analytics/metrics').replace(queryParameters: params);

    final response = await _httpClient.get(uri);
    _checkResponse(response);

    final body = json.decode(response.body) as Map<String, dynamic>;
    final metrics = body['metrics'] as List<dynamic>? ?? [];

    return metrics.map((m) {
      final map = m as Map<String, dynamic>;
      final prev = map['previous_value'] as num?;
      return MetricValue(
        key: map['key'] as String,
        label: map['label'] as String,
        value: (map['value'] as num).toDouble(),
        previousValue: prev?.toDouble(),
        unit: map['unit'] as String?,
        icon: _iconFromName(map['icon'] as String?),
        trend: _parseTrend(map['trend'] as String?),
      );
    }).toList();
  }

  @override
  Future<List<TimeSeries>> getTimeSeries(
    String service,
    String metric, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final params = {
      'service': service,
      'metric': metric,
      ...?(timeRange?.toQueryParams()),
    };
    final uri =
        Uri.parse('$_baseUrl/api/analytics/timeseries').replace(queryParameters: params);

    final response = await _httpClient.get(uri);
    _checkResponse(response);

    final body = json.decode(response.body) as Map<String, dynamic>;
    final seriesList = body['series'] as List<dynamic>? ?? [];

    return seriesList.map((s) {
      final map = s as Map<String, dynamic>;
      final points = (map['points'] as List<dynamic>? ?? []).map((p) {
        final pm = p as Map<String, dynamic>;
        return TimeSeriesPoint(
          timestamp: DateTime.parse(pm['timestamp'] as String),
          value: (pm['value'] as num).toDouble(),
          label: pm['label'] as String?,
        );
      }).toList();

      return TimeSeries(
        key: map['key'] as String,
        label: map['label'] as String,
        points: points,
        color: _colorFromHex(map['color'] as String?),
      );
    }).toList();
  }

  @override
  Future<List<DistributionSegment>> getDistribution(
    String service,
    String metric,
    String groupBy, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final params = {
      'service': service,
      'metric': metric,
      'group_by': groupBy,
      ...?(timeRange?.toQueryParams()),
    };
    final uri =
        Uri.parse('$_baseUrl/api/analytics/distribution').replace(queryParameters: params);

    final response = await _httpClient.get(uri);
    _checkResponse(response);

    final body = json.decode(response.body) as Map<String, dynamic>;
    final segments = body['segments'] as List<dynamic>? ?? [];

    return segments.map((s) {
      final map = s as Map<String, dynamic>;
      return DistributionSegment(
        label: map['label'] as String,
        value: (map['value'] as num).toDouble(),
        color: _colorFromHex(map['color'] as String?),
      );
    }).toList();
  }

  @override
  Future<List<TopNItem>> getTopN(
    String service,
    String metric, {
    int limit = 10,
    AnalyticsTimeRange? timeRange,
  }) async {
    final params = {
      'service': service,
      'metric': metric,
      'limit': '$limit',
      ...?(timeRange?.toQueryParams()),
    };
    final uri =
        Uri.parse('$_baseUrl/api/analytics/top').replace(queryParameters: params);

    final response = await _httpClient.get(uri);
    _checkResponse(response);

    final body = json.decode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];

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

  void _checkResponse(http.Response response) {
    if (response.statusCode != 200) {
      final body = json.decode(response.body) as Map<String, dynamic>?;
      final msg = body?['error'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Analytics API error: $msg');
    }
  }

  static MetricTrend? _parseTrend(String? trend) {
    return switch (trend) {
      'up' => MetricTrend.up,
      'down' => MetricTrend.down,
      'flat' => MetricTrend.flat,
      _ => null,
    };
  }

  static IconData? _iconFromName(String? name) {
    if (name == null) return null;
    // Map common icon names to Material icons
    const iconMap = <String, IconData>{
      'payment': Icons.payment,
      'attach_money': Icons.attach_money,
      'check_circle': Icons.check_circle_outlined,
      'timer': Icons.timer_outlined,
      'people': Icons.people_outlined,
      'person': Icons.person_outlined,
      'person_add': Icons.person_add_outlined,
      'verified': Icons.verified_outlined,
      'send': Icons.send_outlined,
      'mark_email_read': Icons.mark_email_read_outlined,
      'visibility': Icons.visibility_outlined,
      'error': Icons.error_outlined,
      'autorenew': Icons.autorenew,
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'receipt_long': Icons.receipt_long_outlined,
      'folder': Icons.folder_outlined,
      'storage': Icons.storage_outlined,
      'upload': Icons.upload_outlined,
      'description': Icons.description_outlined,
      'map': Icons.map_outlined,
      'route': Icons.route_outlined,
      'place': Icons.place_outlined,
      'gps_fixed': Icons.gps_fixed_outlined,
      'settings': Icons.settings_outlined,
      'edit': Icons.edit_outlined,
      'widgets': Icons.widgets_outlined,
      'domain': Icons.domain_outlined,
      'account_tree': Icons.account_tree_outlined,
      'group': Icons.group_outlined,
      'add_business': Icons.add_business_outlined,
      'history': Icons.history_outlined,
      'warning': Icons.warning_outlined,
    };
    return iconMap[name];
  }

  static Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return null;
  }
}
