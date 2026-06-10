import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';

import '../../../core/services/thesa_analytics_data_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/analytics_error_view.dart';

/// Service Load widget showing HTTP and database operation volume per
/// service over the last 24 hours.
///
/// Queries the allowlisted OTel semconv duration metrics
/// (`http.server.request.duration`, `db.client.operation.duration`)
/// grouped by `service_name` and renders comparative progress bars.
class RegionalPerformance extends StatefulWidget {
  const RegionalPerformance({super.key, required this.dataSource});

  final AdminAnalyticsDataSource dataSource;

  @override
  State<RegionalPerformance> createState() => _RegionalPerformanceState();
}

class _RegionalPerformanceState extends State<RegionalPerformance> {
  late Future<List<_ServiceLoadEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadServiceLoad();
  }

  void _reload() {
    setState(() {
      _future = _loadServiceLoad();
    });
  }

  Future<List<_ServiceLoadEntry>> _loadServiceLoad() async {
    final timeRange = AnalyticsTimeRange.last24Hours();

    final results = await Future.wait([
      widget.dataSource.queryGrouped(
        metric: 'http.server.request.duration',
        aggregation: AnalyticsAggregation.count,
        groupBy: 'service_name',
        timeRange: timeRange,
      ),
      widget.dataSource.queryGrouped(
        metric: 'db.client.operation.duration',
        aggregation: AnalyticsAggregation.count,
        groupBy: 'service_name',
        timeRange: timeRange,
      ),
    ]);

    final httpByService = results[0];
    final dbByService = results[1];

    // Collect unique service names.
    final services = <String>{
      ...httpByService.map((s) => s.label),
      ...dbByService.map((s) => s.label),
    };

    // Normalize each dimension against its max across services.
    final maxHttp = httpByService.fold(
      0.0,
      (m, s) => s.value > m ? s.value : m,
    );
    final maxDb = dbByService.fold(0.0, (m, s) => s.value > m ? s.value : m);

    final entries = <_ServiceLoadEntry>[];
    for (final service in services) {
      final httpSeg = httpByService
          .where((s) => s.label == service)
          .firstOrNull;
      final dbSeg = dbByService.where((s) => s.label == service).firstOrNull;

      entries.add(
        _ServiceLoadEntry(
          service: service,
          httpFraction: maxHttp > 0 ? (httpSeg?.value ?? 0) / maxHttp : 0,
          httpDisplay: _formatCount(httpSeg?.value ?? 0),
          dbFraction: maxDb > 0 ? (dbSeg?.value ?? 0) / maxDb : 0,
          dbDisplay: _formatCount(dbSeg?.value ?? 0),
        ),
      );
    }

    // Sort by HTTP volume descending, take top 5.
    entries.sort((a, b) => b.httpFraction.compareTo(a.httpFraction));
    return entries.take(5).toList();
  }

  static String _formatCount(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Load', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'HTTP and database operations by service (24h)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<_ServiceLoadEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 160,
                  child: AnalyticsErrorView(
                    error: snapshot.error!,
                    onRetry: _reload,
                  ),
                );
              }
              return _buildBars(context, snapshot.data ?? []);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBars(BuildContext context, List<_ServiceLoadEntry> entries) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No data available',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.service,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _ProgressBar(
                label: 'HTTP',
                value: entry.httpFraction,
                display: entry.httpDisplay,
                color: AppColors.tertiary,
              ),
              const SizedBox(height: 6),
              _ProgressBar(
                label: 'DB',
                value: entry.dbFraction,
                display: entry.dbDisplay,
                color: AppColors.success,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ServiceLoadEntry {
  const _ServiceLoadEntry({
    required this.service,
    required this.httpFraction,
    required this.httpDisplay,
    required this.dbFraction,
    required this.dbDisplay,
  });

  final String service;
  final double httpFraction;
  final String httpDisplay;
  final double dbFraction;
  final String dbDisplay;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.value,
    required this.display,
    this.color = AppColors.tertiary,
  });

  final String label;
  final double value;
  final String display;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
