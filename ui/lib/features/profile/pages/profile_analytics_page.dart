import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/widgets/service_analytics_page.dart';
import '../data/profile_providers.dart';

class ProfileAnalyticsPage extends ConsumerWidget {
  const ProfileAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    final profiles = profilesAsync.whenOrNull(data: (d) => d) ?? [];
    final totalCount = profiles.length;
    final personCount =
        profiles.where((p) => p.type == ProfileType.PERSON).length;
    final institutionCount =
        profiles.where((p) => p.type == ProfileType.INSTITUTION).length;

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
      chartTitle: 'Profile Growth',
      chartSubtitle: 'Profile creation trends over time',
      events: const [
        ServiceEvent(
          title: 'New profile registered',
          timeAgo: '5 mins ago',
          severity: EventSeverity.success,
          icon: Icons.person_add_outlined,
        ),
        ServiceEvent(
          title: 'Contact verification completed',
          timeAgo: '20 mins ago',
          severity: EventSeverity.info,
          icon: Icons.verified_outlined,
        ),
        ServiceEvent(
          title: 'Profile merge executed',
          timeAgo: '1 hour ago',
          severity: EventSeverity.warning,
          icon: Icons.merge_outlined,
        ),
      ],
    );
  }
}
