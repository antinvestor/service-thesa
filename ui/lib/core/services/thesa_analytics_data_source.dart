import 'package:antinvestor_ui_core/antinvestor_ui_core.dart'
    show ServiceAnalyticsSpec;
import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart'
    show auditAnalyticsSpec;
import 'package:antinvestor_ui_files/antinvestor_ui_files.dart'
    show filesAnalyticsSpec;
import 'package:antinvestor_ui_fort/antinvestor_ui_fort.dart'
    show fortAnalyticsSpec;
import 'package:antinvestor_ui_notification/antinvestor_ui_notification.dart'
    show notificationAnalyticsSpec;
import 'package:antinvestor_ui_profile/antinvestor_ui_profile.dart'
    show profileAnalyticsSpec;
import 'package:antinvestor_ui_tenancy/antinvestor_ui_tenancy.dart'
    show tenancyAnalyticsSpec;
import 'dart:convert';

import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/thesa_analytics_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Adapts [AuthRuntime.fetch] onto ui_core's [AnalyticsTransport] so the
/// standard [ThesaAnalyticsDataSource] can POST to the Thesa BFF with the
/// access token attached by the runtime.
AnalyticsTransport runtimeAnalyticsTransport(
  AuthRuntime runtime,
  String baseUrl,
) {
  return (String path, {Object? body}) async {
    final response = await runtime.fetch(
      '$baseUrl$path',
      method: 'POST',
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
    return http.Response.bytes(response.body, response.status);
  };
}

/// Thesa admin console analytics data source.
///
/// Extends the standard ui_core [ThesaAnalyticsDataSource] (exact gate
/// contract: nested `time_range`, `step` granularity, server-side tenant
/// scoping, client-side reserved-filter stripping) with admin-only
/// queries that span every partition the caller can access
/// (`partition_ids: ["*"]`).
/// Every service's exported analytics spec, registered so KPI scalar
/// queries resolve for the embedded service overview pages.
final registeredAnalyticsSpecs = <ServiceAnalyticsSpec>[
  fortAnalyticsSpec,
  notificationAnalyticsSpec,
  filesAnalyticsSpec,
  auditAnalyticsSpec,
  tenancyAnalyticsSpec,
  profileAnalyticsSpec,
];

class AdminAnalyticsDataSource extends ThesaAnalyticsDataSource {
  // Not convertible to a super parameter: the transport is also kept on
  // this class for the partition-wide extension queries below.
  // ignore: use_super_parameters
  AdminAnalyticsDataSource(AnalyticsTransport transport)
    : _transport = transport,
      super(transport, specs: registeredAnalyticsSpecs);

  final AnalyticsTransport _transport;

  /// Time-series query across all accessible partitions.
  Future<List<TimeSeriesPoint>> queryTimeSeriesAllPartitions({
    required String metric,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    AnalyticsTimeRange? timeRange,
    TimeGranularity? granularity,
  }) async {
    final data = await _postWildcard('/api/analytics/query/timeseries', {
      'metric': metric,
      'aggregation': aggregation.wireName,
      if (granularity != null || timeRange?.granularity != null)
        'step': (granularity ?? timeRange!.granularity!).name,
    }, timeRange);
    final points = data['points'] as List<dynamic>? ?? const [];
    return [
      for (final p in points.cast<Map<String, dynamic>>())
        TimeSeriesPoint(
          timestamp: DateTime.parse(p['timestamp'] as String),
          value: (p['value'] as num).toDouble(),
          label: p['label'] as String?,
        ),
    ];
  }

  /// Top-N query across all accessible partitions.
  Future<List<TopNItem>> queryTopNAllPartitions({
    required String metric,
    required String groupBy,
    AnalyticsAggregation aggregation = AnalyticsAggregation.sum,
    int limit = 10,
    AnalyticsTimeRange? timeRange,
  }) async {
    final data = await _postWildcard('/api/analytics/query/topn', {
      'metric': metric,
      'aggregation': aggregation.wireName,
      'group_by': groupBy,
      'limit': limit,
    }, timeRange);
    final items = data['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items.cast<Map<String, dynamic>>())
        TopNItem(
          label: item['label'] as String,
          value: (item['value'] as num).toDouble(),
          metadata: (item['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        ),
    ];
  }

  Future<Map<String, dynamic>> _postWildcard(
    String path,
    Map<String, dynamic> fields,
    AnalyticsTimeRange? timeRange,
  ) async {
    final body = <String, dynamic>{
      ...fields,
      'partition_ids': const ['*'],
      if (timeRange != null)
        'time_range': {
          'start': timeRange.start.toUtc().toIso8601String(),
          'end': timeRange.end.toUtc().toIso8601String(),
        },
    };
    final response = await _transport(path, body: json.encode(body));
    if (response.statusCode != 200) {
      throw AnalyticsQueryException(
        statusCode: response.statusCode,
        message: _serverError(response),
        path: path,
      );
    }
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static String _serverError(http.Response response) {
    try {
      final parsed = json.decode(utf8.decode(response.bodyBytes));
      final msg = (parsed as Map<String, dynamic>)['error'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {
      // Fall through to the generic message.
    }
    return 'HTTP ${response.statusCode}';
  }
}

/// Single analytics data source for the whole admin console. Also used
/// to override ui_core's `analyticsDataSourceProvider` in main.dart so
/// the generic [AnalyticsDashboard] pages share the same instance.
final adminAnalyticsProvider = Provider<AdminAnalyticsDataSource>((ref) {
  final runtime = ref.watch(authRuntimeProvider);
  return AdminAnalyticsDataSource(
    runtimeAnalyticsTransport(runtime, ApiConfig.thesaBaseUrl),
  );
});
