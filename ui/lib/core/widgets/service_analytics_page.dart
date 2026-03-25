import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'page_header.dart';
import 'responsive_layout.dart';

/// Data model for a KPI card on the service analytics page.
class ServiceKpi {
  const ServiceKpi({
    required this.label,
    required this.value,
    this.change,
    this.changePositive = true,
    this.icon,
  });

  final String label;
  final String value;
  final String? change;
  final bool changePositive;
  final IconData? icon;
}

/// Data model for a recent event entry.
class ServiceEvent {
  const ServiceEvent({
    required this.title,
    required this.timeAgo,
    this.icon,
    this.severity = EventSeverity.info,
  });

  final String title;
  final String timeAgo;
  final IconData? icon;
  final EventSeverity severity;
}

enum EventSeverity { info, warning, error, success }

/// A reusable service analytics dashboard page.
///
/// Matches the "Partition Service Dashboard" Stitch design:
/// - KPI cards row at top
/// - Main chart area + recent events side panel
/// - Optional bottom section (e.g., top performers table)
///
/// Services provide their data via constructor parameters.
class ServiceAnalyticsPage extends StatelessWidget {
  const ServiceAnalyticsPage({
    super.key,
    required this.title,
    required this.breadcrumbs,
    required this.kpis,
    this.chartWidget,
    this.chartTitle,
    this.chartSubtitle,
    this.events = const [],
    this.bottomSection,
    this.actions,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<ServiceKpi> kpis;
  final Widget? chartWidget;
  final String? chartTitle;
  final String? chartSubtitle;
  final List<ServiceEvent> events;
  final Widget? bottomSection;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final screenSize = screenSizeOf(context);
    final isDesktop = screenSize == ScreenSize.desktop;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            breadcrumbs: breadcrumbs,
            actions: actions ?? [],
          ),
          const SizedBox(height: 20),
          // KPI cards
          _buildKpiRow(context, isDesktop),
          const SizedBox(height: 20),
          // Chart + Events
          if (isDesktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildChartCard(context)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildEventsCard(context)),
                ],
              ),
            )
          else ...[
            _buildChartCard(context),
            const SizedBox(height: 20),
            _buildEventsCard(context),
          ],
          // Bottom section
          if (bottomSection != null) ...[
            const SizedBox(height: 20),
            bottomSection!,
          ],
        ],
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      final children = <Widget>[];
      for (var i = 0; i < kpis.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 16));
        children.add(Expanded(child: _KpiCard(kpi: kpis[i])));
      }
      return Row(children: children);
    }
    return Column(
      children: kpis
          .map((kpi) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KpiCard(kpi: kpi),
              ))
          .toList(),
    );
  }

  Widget _buildChartCard(BuildContext context) {
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
          if (chartTitle != null)
            Text(chartTitle!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          if (chartSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(chartSubtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
          if (chartTitle != null || chartSubtitle != null)
            const SizedBox(height: 16),
          if (chartWidget != null)
            SizedBox(height: 240, child: chartWidget!)
          else
            const SizedBox(
              height: 240,
              child: Center(
                child: Text('Chart placeholder',
                    style: TextStyle(color: AppColors.onSurfaceMuted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsCard(BuildContext context) {
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
          Text('Recent Events',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No recent events',
                    style: TextStyle(color: AppColors.onSurfaceMuted)),
              ),
            )
          else
            ...events.map((e) => _EventTile(event: e)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {},
            child: const Text('View All Audit Logs'),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Card ────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final ServiceKpi kpi;

  @override
  Widget build(BuildContext context) {
    final changeColor =
        kpi.changePositive ? AppColors.success : AppColors.error;

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
          Row(
            children: [
              if (kpi.icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(kpi.icon, size: 18, color: AppColors.tertiary),
                ),
              const Spacer(),
              if (kpi.change != null)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kpi.change!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(kpi.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Event Tile ──────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final ServiceEvent event;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (event.severity) {
      EventSeverity.info => (AppColors.info, Icons.info_outline),
      EventSeverity.warning => (AppColors.warning, Icons.warning_amber),
      EventSeverity.error => (AppColors.error, Icons.error_outline),
      EventSeverity.success => (AppColors.success, Icons.check_circle_outline),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon ?? icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(event.timeAgo,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
