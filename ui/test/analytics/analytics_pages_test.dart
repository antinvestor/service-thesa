import 'dart:async';
import 'dart:convert';

import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:antinvestor_ui_core/analytics/thesa_analytics_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:thesa/core/services/service_definition.dart';
import 'package:thesa/core/services/thesa_analytics_data_source.dart';
import 'package:thesa/features/analytics/analytics_page.dart';
import 'package:thesa/features/dashboard/dashboard_page.dart';
import 'package:thesa/features/partition/data/partition_providers.dart';
import 'package:thesa/features/partition/pages/partition_analytics_page.dart';
import 'package:thesa/features/profile/data/profile_providers.dart';
import 'package:thesa/features/profile/pages/profile_analytics_page.dart';

/// A request captured by the mocked analytics transport.
class RecordedRequest {
  RecordedRequest(this.path, this.body);
  final String path;
  final Map<String, dynamic> body;
}

/// Mocked [AnalyticsTransport] recording every request and replying with
/// canned per-endpoint payloads (or a fixed error status).
AnalyticsTransport mockTransport(
  List<RecordedRequest> log, {
  int statusCode = 200,
  String errorMessage = 'boom',
  Map<String, double> scalarByMetric = const {},
  List<Map<String, dynamic>> points = const [],
  List<Map<String, dynamic>> segments = const [],
  List<Map<String, dynamic>> items = const [],
}) {
  return (String path, {Object? body}) async {
    final decoded = json.decode(body! as String) as Map<String, dynamic>;
    log.add(RecordedRequest(path, decoded));
    if (statusCode != 200) {
      return http.Response(json.encode({'error': errorMessage}), statusCode);
    }
    final Object payload;
    if (path.endsWith('/scalar')) {
      payload = {'value': scalarByMetric[decoded['metric']] ?? 0};
    } else if (path.endsWith('/timeseries')) {
      payload = {'points': points};
    } else if (path.endsWith('/grouped')) {
      payload = {'segments': segments};
    } else {
      payload = {'items': items};
    }
    return http.Response(json.encode(payload), 200);
  };
}

/// Asserts the deterministic part of a request body matches [expected]
/// exactly, and that the stripped `time_range` is well-formed RFC3339.
void expectBody(RecordedRequest req, Map<String, dynamic> expected) {
  final body = Map<String, dynamic>.of(req.body);
  final timeRange = body.remove('time_range') as Map<String, dynamic>?;
  expect(timeRange, isNotNull, reason: 'time_range missing on ${req.path}');
  expect(DateTime.parse(timeRange!['start'] as String).isUtc, isTrue);
  expect(DateTime.parse(timeRange['end'] as String).isUtc, isTrue);
  expect(body, expected, reason: 'unexpected body for ${req.path}');
}

const _testService = ServiceDefinition(
  id: 'test',
  label: 'Test',
  icon: Icons.science_outlined,
  subFeatures: [],
);

Widget wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('AdminAnalyticsDataSource contract', () {
    test('wildcard time series sends partition_ids ["*"] and step', () async {
      final log = <RecordedRequest>[];
      final ds = AdminAnalyticsDataSource(mockTransport(log));

      await ds.queryTimeSeriesAllPartitions(
        metric: 'identity_organizations_created_total',
        timeRange: AnalyticsTimeRange.lastYear(),
      );

      expect(log.single.path, '/api/analytics/query/timeseries');
      expectBody(log.single, {
        'metric': 'identity_organizations_created_total',
        'aggregation': 'sum',
        'step': 'month',
        'partition_ids': ['*'],
      });
    });

    test(
      'wildcard top-N sends group_by, limit and partition_ids ["*"]',
      () async {
        final log = <RecordedRequest>[];
        final ds = AdminAnalyticsDataSource(mockTransport(log));

        await ds.queryTopNAllPartitions(
          metric: 'identity_organizations_created_total',
          groupBy: 'partition_id',
          limit: 5,
          timeRange: AnalyticsTimeRange.last30Days(),
        );

        expect(log.single.path, '/api/analytics/query/topn');
        expectBody(log.single, {
          'metric': 'identity_organizations_created_total',
          'aggregation': 'sum',
          'group_by': 'partition_id',
          'limit': 5,
          'partition_ids': ['*'],
        });
      },
    );

    test('inherited standard queries strip reserved tenancy filters', () async {
      final log = <RecordedRequest>[];
      final ds = AdminAnalyticsDataSource(mockTransport(log));

      await ds.queryScalar(
        metric: 'notifications_sent_total',
        filters: {'tenant.id': 'spoof', 'partition_id': 'x', 'kind': 'sms'},
      );

      expect(log.single.body['filters'], {'kind': 'sms'});
    });

    test(
      'non-200 maps to AnalyticsQueryException with server message',
      () async {
        final ds = AdminAnalyticsDataSource(
          mockTransport(
            [],
            statusCode: 400,
            errorMessage: 'metric not allowed: "up"',
          ),
        );

        await expectLater(
          ds.queryScalar(metric: 'up'),
          throwsA(
            isA<AnalyticsQueryException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  'metric not allowed: "up"',
                ),
          ),
        );
      },
    );
  });

  group('DashboardPage', () {
    Future<void> pump(WidgetTester tester, AdminAnalyticsDataSource ds) async {
      await tester.pumpWidget(
        wrap(const DashboardPage(), [
          adminAnalyticsProvider.overrideWithValue(ds),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('issues only allowlisted queries with the exact bodies', (
      tester,
    ) async {
      final log = <RecordedRequest>[];
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          log,
          scalarByMetric: {
            'rpc.server.duration': 2000,
            'identity_organizations_created_total': 42,
            'notifications_sent_total': 1234,
          },
        ),
      );

      await pump(tester, ds);

      final scalars = log.where((r) => r.path.endsWith('/scalar')).toList();
      final series = log.where((r) => r.path.endsWith('/timeseries')).toList();
      final grouped = log.where((r) => r.path.endsWith('/grouped')).toList();

      // KPIs: total requests + error-rate pair + organizations +
      // notifications.
      expect(scalars, hasLength(5));
      expectBody(scalars[0], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
      });
      // Error rate pair: OK-filtered and total.
      expectBody(scalars[1], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
        'filters': {'rpc_grpc_status_code': 'OK'},
      });
      expectBody(scalars[2], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
      });
      expectBody(scalars[3], {
        'metric': 'identity_organizations_created_total',
        'aggregation': 'sum',
      });
      expectBody(scalars[4], {
        'metric': 'notifications_sent_total',
        'aggregation': 'sum',
      });

      // Charts: API traffic (1y) + payment volume (1y).
      expect(series, hasLength(2));
      expectBody(series[0], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
        'step': 'month',
      });
      expectBody(series[1], {
        'metric': 'payments_initiated_total',
        'aggregation': 'sum',
        'step': 'month',
      });

      // Distributions: traffic by rpc_service + service load (http/db).
      expect(grouped, hasLength(3));
      expectBody(grouped[0], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
        'group_by': 'rpc_service',
      });
      expectBody(grouped[1], {
        'metric': 'http.server.request.duration',
        'aggregation': 'count',
        'group_by': 'service_name',
      });
      expectBody(grouped[2], {
        'metric': 'db.client.operation.duration',
        'aggregation': 'count',
        'group_by': 'service_name',
      });

      // No request may carry reserved tenancy filters.
      for (final req in log) {
        final filters = req.body['filters'] as Map<String, dynamic>?;
        expect(filters?.containsKey('tenant_id') ?? false, isFalse);
        expect(filters?.containsKey('partition_id') ?? false, isFalse);
      }

      // KPI values rendered.
      expect(find.text('2.0K'), findsOneWidget); // API requests
      expect(find.text('42'), findsOneWidget); // organizations
      expect(find.text('1.2K'), findsOneWidget); // notifications
    });

    testWidgets('claim-less 403 renders friendly states, not crashes', (
      tester,
    ) async {
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          [],
          statusCode: 403,
          errorMessage: 'analytics queries require tenant scope',
        ),
      );

      await pump(tester, ds);

      // KPI cards degrade to a dash with a classified tooltip.
      expect(find.text('--'), findsNWidgets(4));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Tooltip &&
              (w.message ?? '').startsWith('No analytics access'),
        ),
        findsNWidgets(4),
      );
      // Chart cards show the friendly error view.
      expect(find.text('No analytics access'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('allowlist 400 renders the rejected-query state', (
      tester,
    ) async {
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          [],
          statusCode: 400,
          errorMessage: 'metric not allowed: "container_cpu"',
        ),
      );

      await pump(tester, ds);

      expect(find.text('Query rejected'), findsWidgets);
      expect(
        find.textContaining('metric not allowed: "container_cpu"'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('backend 503 renders the unavailable state', (tester) async {
      final ds = AdminAnalyticsDataSource(mockTransport([], statusCode: 503));

      await pump(tester, ds);

      expect(find.text('Analytics unavailable'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows loading indicators while queries are in flight', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final ds = AdminAnalyticsDataSource(
        (String path, {Object? body}) => pending.future,
      );

      await tester.pumpWidget(
        wrap(const DashboardPage(), [
          adminAnalyticsProvider.overrideWithValue(ds),
        ]),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('...'), findsWidgets);
    });

    testWidgets('empty responses render the empty chart states', (
      tester,
    ) async {
      final ds = AdminAnalyticsDataSource(mockTransport([]));

      await pump(tester, ds);

      expect(find.text('No data available'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('AnalyticsPage explorer', () {
    testWidgets('runs the default allowlisted query with exact bodies', (
      tester,
    ) async {
      final log = <RecordedRequest>[];
      final ds = AdminAnalyticsDataSource(mockTransport(log));

      await tester.pumpWidget(
        wrap(const AnalyticsPage(), [
          adminAnalyticsProvider.overrideWithValue(ds),
        ]),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(log, hasLength(3));
      expectBody(log[0], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
      });
      expectBody(log[1], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
        'step': 'day',
      });
      expectBody(log[2], {
        'metric': 'rpc.server.duration',
        'aggregation': 'count',
        'group_by': 'rpc_service',
      });
    });

    testWidgets('renders classified error states for gate rejections', (
      tester,
    ) async {
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          [],
          statusCode: 400,
          errorMessage: 'invalid group_by "secret"',
        ),
      );

      await tester.pumpWidget(
        wrap(const AnalyticsPage(), [
          adminAnalyticsProvider.overrideWithValue(ds),
        ]),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Query rejected'), findsWidgets);
      expect(find.textContaining('invalid group_by'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileAnalyticsPage', () {
    Future<void> pump(WidgetTester tester, AdminAnalyticsDataSource ds) async {
      await tester.pumpWidget(
        wrap(ProfileAnalyticsPage(service: _testService), [
          adminAnalyticsProvider.overrideWithValue(ds),
          profilesProvider.overrideWith((ref, query) async => []),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('trend and activity come from profile/completed_calls', (
      tester,
    ) async {
      final log = <RecordedRequest>[];
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          log,
          scalarByMetric: {'profile/completed_calls': 350},
          points: [
            {'timestamp': '2026-06-01T00:00:00Z', 'value': 10},
            {'timestamp': '2026-06-02T00:00:00Z', 'value': 12},
          ],
        ),
      );

      await pump(tester, ds);

      final series = log.where((r) => r.path.endsWith('/timeseries')).toList();
      final scalars = log.where((r) => r.path.endsWith('/scalar')).toList();

      expect(series, hasLength(1));
      expectBody(series[0], {
        'metric': 'profile/completed_calls',
        'aggregation': 'sum',
        'step': 'day',
      });

      // Activity panel: 24h + 7d completed-call scalars.
      expect(scalars, hasLength(2));
      for (final s in scalars) {
        expectBody(s, {
          'metric': 'profile/completed_calls',
          'aggregation': 'sum',
        });
      }

      expect(find.text('Service Activity'), findsWidgets);
      expect(find.text('Completed calls (24h)'), findsOneWidget);
      expect(find.text('350'), findsNWidgets(2));
      // The old mock event feed is gone.
      expect(find.text('New profile registered'), findsNothing);
    });

    testWidgets('403 renders friendly access states', (tester) async {
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          [],
          statusCode: 403,
          errorMessage: 'analytics queries require tenant scope',
        ),
      );

      await pump(tester, ds);

      expect(find.text('No analytics access'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty analytics renders empty states', (tester) async {
      final ds = AdminAnalyticsDataSource(mockTransport([]));

      await pump(tester, ds);

      expect(find.text('No data for this period yet'), findsOneWidget);
      expect(find.text('No recorded activity yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PartitionAnalyticsPage', () {
    Future<void> pump(WidgetTester tester, AdminAnalyticsDataSource ds) async {
      await tester.pumpWidget(
        wrap(PartitionAnalyticsPage(service: _testService), [
          adminAnalyticsProvider.overrideWithValue(ds),
          tenantsProvider.overrideWith((ref) async => []),
          partitionsProvider.overrideWith((ref) async => []),
          partitionRolesProvider.overrideWith((ref) async => []),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'growth chart and top table query identity_organizations_created_total',
      (tester) async {
        final log = <RecordedRequest>[];
        final ds = AdminAnalyticsDataSource(
          mockTransport(
            log,
            scalarByMetric: {'partition/completed_calls': 90},
            points: [
              {'timestamp': '2026-01-01T00:00:00Z', 'value': 3},
              {'timestamp': '2026-02-01T00:00:00Z', 'value': 5},
            ],
            items: [
              {'label': 'partition-a', 'value': 12},
              {'label': 'partition-b', 'value': 7},
            ],
          ),
        );

        await pump(tester, ds);

        final series = log
            .where((r) => r.path.endsWith('/timeseries'))
            .toList();
        final topn = log.where((r) => r.path.endsWith('/topn')).toList();
        final scalars = log.where((r) => r.path.endsWith('/scalar')).toList();

        // Real partition growth replaces the fake 12-month bars: a
        // partition-wide identity_organizations_created_total time series.
        expect(series, hasLength(1));
        expectBody(series[0], {
          'metric': 'identity_organizations_created_total',
          'aggregation': 'sum',
          'step': 'month',
          'partition_ids': ['*'],
        });

        // Top partitions table.
        expect(topn, hasLength(1));
        expectBody(topn[0], {
          'metric': 'identity_organizations_created_total',
          'aggregation': 'sum',
          'group_by': 'partition_id',
          'limit': 5,
          'partition_ids': ['*'],
        });

        // Activity panel on the partition service's completed calls.
        expect(scalars, hasLength(2));
        for (final s in scalars) {
          expectBody(s, {
            'metric': 'partition/completed_calls',
            'aggregation': 'sum',
          });
        }

        // Rendered real data; mock rows are gone.
        expect(find.text('partition-a'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Vortex Dynamics'), findsNothing);
        expect(find.text('New Partition Created'), findsNothing);
      },
    );

    testWidgets('403 renders friendly access states', (tester) async {
      final ds = AdminAnalyticsDataSource(
        mockTransport(
          [],
          statusCode: 403,
          errorMessage: 'analytics queries require tenant scope',
        ),
      );

      await pump(tester, ds);

      expect(find.text('No analytics access'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty analytics renders empty states', (tester) async {
      final ds = AdminAnalyticsDataSource(mockTransport([]));

      await pump(tester, ds);

      expect(find.text('No data for this period yet'), findsOneWidget);
      expect(find.text('No recorded activity yet'), findsOneWidget);
      expect(
        find.text('No partition activity in this period yet'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
