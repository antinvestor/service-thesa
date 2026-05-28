import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';

import 'analytics_client.dart';

/// Implementation of [AnalyticsDataSource] backed by the Thesa BFF.
///
/// Delegates to [ThesaAnalyticsClient] which routes every request through
/// the auth runtime so the access token is attached automatically.
class ThesaAnalyticsDataSource implements AnalyticsDataSource {
  ThesaAnalyticsDataSource(this._client);

  final ThesaAnalyticsClient _client;

  @override
  Future<List<MetricValue>> getMetrics(
    String service, {
    AnalyticsTimeRange? timeRange,
  }) async {
    // The BFF doesn't expose a bulk metrics endpoint yet; service-specific
    // dashboards build their own KPI tiles. Return an empty list so the
    // generic dashboard renders without throwing.
    return const <MetricValue>[];
  }

  @override
  Future<List<TimeSeries>> getTimeSeries(
    String service,
    String metric, {
    AnalyticsTimeRange? timeRange,
  }) async {
    final points = await _client.queryTimeSeries(
      metric: metric,
      filters: {'service': service},
      timeRange: timeRange,
    );
    return [
      TimeSeries(key: metric, label: metric, points: points),
    ];
  }

  @override
  Future<List<DistributionSegment>> getDistribution(
    String service,
    String metric,
    String groupBy, {
    AnalyticsTimeRange? timeRange,
  }) {
    return _client.queryGrouped(
      metric: metric,
      groupBy: groupBy,
      filters: {'service': service},
      timeRange: timeRange,
    );
  }

  @override
  Future<List<TopNItem>> getTopN(
    String service,
    String metric, {
    int limit = 10,
    AnalyticsTimeRange? timeRange,
  }) {
    return _client.queryTopN(
      metric: metric,
      limit: limit,
      filters: {'service': service},
      timeRange: timeRange,
    );
  }
}
