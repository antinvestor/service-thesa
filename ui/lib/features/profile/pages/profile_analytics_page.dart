import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:antinvestor_ui_core/analytics/analytics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/services/thesa_analytics_data_source.dart';
import '../../../core/widgets/service_activity_widgets.dart';
import '../../../core/widgets/service_analytics_page.dart';
import '../data/profile_providers.dart';

/// Frame `{pkg}/completed_calls` metric emitted by the profile service.
const _profileCallsMetric = 'profile/completed_calls';

/// Profile service analytics.
///
/// Inventory KPIs (profile counts) come from the entity API; the trend
/// chart and the activity panel are live queries against the Thesa
/// analytics gate (tenant scoping injected server-side from the JWT).
class ProfileAnalyticsPage extends ConsumerWidget {
  const ProfileAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider(''));
    final analytics = ref.watch(adminAnalyticsProvider);

    final profiles = profilesAsync.whenOrNull(data: (d) => d) ?? [];
    final totalCount = profiles.length;
    final personCount = profiles
        .where((p) => p.type == ProfileType.PERSON)
        .length;
    final institutionCount = profiles
        .where((p) => p.type == ProfileType.INSTITUTION)
        .length;

    return ServiceAnalyticsPage(
      title: 'Profile Service',
      breadcrumbs: const ['Services', 'Profile Service', 'Analytics'],
      kpis: [
        ServiceKpi(
          label: 'Total Profiles',
          value: '$totalCount',
          icon: Icons.people_outlined,
        ),
        ServiceKpi(
          label: 'Person Profiles',
          value: '$personCount',
          icon: Icons.person_outlined,
        ),
        ServiceKpi(
          label: 'Institution Profiles',
          value: '$institutionCount',
          icon: Icons.business_outlined,
        ),
      ],
      chartTitle: 'Service Activity',
      chartSubtitle: 'Completed profile service calls over the last 30 days',
      chartWidget: AnalyticsTrendChart(
        label: 'Completed calls',
        granularity: TimeGranularity.day,
        loader: () => analytics.queryTimeSeries(
          metric: _profileCallsMetric,
          timeRange: AnalyticsTimeRange.last30Days(),
        ),
      ),
      sidePanel: ServiceActivityPanel(
        dataSource: analytics,
        metric: _profileCallsMetric,
      ),
    );
  }
}
