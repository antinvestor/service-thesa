import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';

import '../../../core/services/analytics_client.dart';
import '../../../core/theme/app_colors.dart';

/// Cluster Resources widget showing CPU, Memory, and Disk usage per pod.
///
/// Queries container-level metrics grouped by pod name and renders
/// progress bars for each resource dimension.
class RegionalPerformance extends StatefulWidget {
  const RegionalPerformance({super.key, required this.client});

  final ThesaAnalyticsClient client;

  @override
  State<RegionalPerformance> createState() => _RegionalPerformanceState();
}

class _RegionalPerformanceState extends State<RegionalPerformance> {
  late Future<List<_ResourceEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadResources();
  }

  Future<List<_ResourceEntry>> _loadResources() async {
    final timeRange = AnalyticsTimeRange.last24Hours();

    final results = await Future.wait([
      widget.client.queryGrouped(
        metric: 'container_cpu_usage_seconds_total',
        groupBy: 'pod',
        timeRange: timeRange,
      ),
      widget.client.queryGrouped(
        metric: 'container_memory_working_set_bytes',
        groupBy: 'pod',
        timeRange: timeRange,
      ),
    ]);

    final cpuByPod = results[0];
    final memByPod = results[1];

    // Collect unique pod names
    final pods = <String>{
      ...cpuByPod.map((s) => s.label),
      ...memByPod.map((s) => s.label),
    };

    // Normalize CPU: show as percentage of max across pods
    final maxCpu =
        cpuByPod.fold(0.0, (m, s) => s.value > m ? s.value : m);
    final maxMem =
        memByPod.fold(0.0, (m, s) => s.value > m ? s.value : m);

    final entries = <_ResourceEntry>[];
    for (final pod in pods) {
      final cpu = cpuByPod.where((s) => s.label == pod).firstOrNull;
      final mem = memByPod.where((s) => s.label == pod).firstOrNull;

      entries.add(_ResourceEntry(
        pod: pod,
        cpuFraction: maxCpu > 0 ? (cpu?.value ?? 0) / maxCpu : 0,
        cpuDisplay: _formatCpu(cpu?.value ?? 0),
        memFraction: maxMem > 0 ? (mem?.value ?? 0) / maxMem : 0,
        memDisplay: _formatBytes(mem?.value ?? 0),
      ));
    }

    // Sort by CPU descending, take top 5
    entries.sort((a, b) => b.cpuFraction.compareTo(a.cpuFraction));
    return entries.take(5).toList();
  }

  static String _formatCpu(double seconds) {
    if (seconds >= 3600) return '${(seconds / 3600).toStringAsFixed(1)}h';
    if (seconds >= 60) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${seconds.toStringAsFixed(1)}s';
  }

  static String _formatBytes(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)} GB';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)} MB';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)} KB';
    return '${value.toStringAsFixed(0)} B';
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
          Text('Cluster Resources',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'CPU and memory usage by pod',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<_ResourceEntry>>(
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
                  height: 120,
                  child: Center(
                    child: Text('Unable to load data',
                        style: Theme.of(context).textTheme.bodySmall),
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

  Widget _buildBars(BuildContext context, List<_ResourceEntry> entries) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('No data available',
              style: Theme.of(context).textTheme.bodySmall),
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
                entry.pod,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _ProgressBar(
                label: 'CPU',
                value: entry.cpuFraction,
                display: entry.cpuDisplay,
                color: AppColors.tertiary,
              ),
              const SizedBox(height: 6),
              _ProgressBar(
                label: 'Memory',
                value: entry.memFraction,
                display: entry.memDisplay,
                color: AppColors.success,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ResourceEntry {
  const _ResourceEntry({
    required this.pod,
    required this.cpuFraction,
    required this.cpuDisplay,
    required this.memFraction,
    required this.memDisplay,
  });

  final String pod;
  final double cpuFraction;
  final String cpuDisplay;
  final double memFraction;
  final String memDisplay;
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
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
