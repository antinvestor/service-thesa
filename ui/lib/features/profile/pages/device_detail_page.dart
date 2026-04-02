import 'package:antinvestor_api_device/antinvestor_api_device.dart'
    show DeviceObject, DeviceLog;
import 'package:antinvestor_api_geolocation/antinvestor_api_geolocation.dart'
    show LocationPointObject, GeoEventObject, RouteAssignmentObject;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/device_repository.dart';
import '../data/geolocation_client.dart';

/// Provider to fetch a single device by ID.
final deviceDetailProvider =
    FutureProvider.family<DeviceObject?, String>((ref, deviceId) async {
  final repo = await ref.watch(deviceRepositoryProvider.future);
  final devices = await repo.getById([deviceId], extensive: true);
  return devices.isNotEmpty ? devices.first : null;
});

/// Provider for device logs.
final deviceLogsProvider =
    FutureProvider.family<List<DeviceLog>, String>((ref, deviceId) async {
  final repo = await ref.watch(deviceRepositoryProvider.future);
  return repo.listLogs(deviceId, count: 50);
});

/// Device detail page at a custom route.
/// Tabs: Overview | Activity Logs | Location Track | Geofence Events | Routes
class DeviceDetailPage extends ConsumerWidget {
  const DeviceDetailPage({
    super.key,
    required this.deviceId,
    required this.profileId,
  });

  final String deviceId;
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDevice = ref.watch(deviceDetailProvider(deviceId));

    return asyncDevice.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load device',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(deviceDetailProvider(deviceId)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (device) {
        if (device == null) {
          return const Center(child: Text('Device not found'));
        }
        return _DeviceDetailContent(
          device: device,
          deviceId: deviceId,
          profileId: profileId,
        );
      },
    );
  }
}

class _DeviceDetailContent extends StatelessWidget {
  const _DeviceDetailContent({
    required this.device,
    required this.deviceId,
    required this.profileId,
  });

  final DeviceObject device;
  final String deviceId;
  final String profileId;

  IconData get _icon {
    final ua = device.userAgent.toLowerCase();
    if (ua.contains('android')) return Icons.phone_android;
    if (ua.contains('iphone') || ua.contains('ios')) return Icons.phone_iphone;
    if (ua.contains('windows') || ua.contains('mac') || ua.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    final deviceName =
        device.name.isNotEmpty ? device.name : 'Device $deviceId';

    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: PageHeader(
              title: deviceName,
              breadcrumbs: [
                'Services',
                'Profile Service',
                'Profiles',
                'Profile',
                'Devices',
                deviceName,
              ],
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context
                      .go('/services/profile/profiles/$profileId'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Profile'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Icon(_icon, size: 20, color: AppColors.tertiary),
                const SizedBox(width: 8),
                _PresenceBadge(device.presence.name),
                const SizedBox(width: 12),
                Text('ID: $deviceId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurfaceMuted)),
                if (device.ip.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text('IP: ${device.ip}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Activity Logs'),
              Tab(text: 'Location Track'),
              Tab(text: 'Geofence Events'),
              Tab(text: 'Route Assignments'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(device: device),
                _LogsTab(deviceId: deviceId),
                _LocationTrackTab(profileId: profileId),
                _GeofenceEventsTab(profileId: profileId),
                _RouteAssignmentsTab(profileId: profileId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.device});

  final DeviceObject device;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(title: 'Device Information', rows: [
            ('Name', device.name),
            ('OS', device.os),
            ('User Agent', device.userAgent),
            ('IP Address', device.ip),
            ('Session ID', device.sessionId),
            ('Profile ID', device.profileId),
            ('Presence', device.presence.name),
            ('Last Seen', device.lastSeen),
          ]),
          if (device.hasLocale()) ...[
            const SizedBox(height: 16),
            _InfoCard(title: 'Locale', rows: [
              ('Language', device.locale.language.join(', ')),
              ('Timezone', device.locale.timezone),
              ('UTC Offset', device.locale.utcOffset),
              ('Currency', device.locale.currency),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Activity Logs Tab ────────────────────────────────────────────────────────

class _LogsTab extends ConsumerWidget {
  const _LogsTab({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(deviceLogsProvider(deviceId));

    return asyncLogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load logs',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(deviceLogsProvider(deviceId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No activity logs'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _LogEntry(log: log);
          },
        );
      },
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.log});

  final DeviceLog log;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: AppColors.tertiary),
                const SizedBox(width: 6),
                Text(log.lastSeen.isNotEmpty ? log.lastSeen : 'Unknown time',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (log.ip.isNotEmpty)
                  Text(log.ip,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.onSurfaceMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (log.os.isNotEmpty) _chip(context, 'OS', log.os),
                if (log.sessionId.isNotEmpty)
                  _chip(context, 'Session', log.sessionId),
                if (log.userAgent.isNotEmpty)
                  _chip(context, 'UA', log.userAgent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.onSurfaceMuted)),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ─── Location Track Tab ───────────────────────────────────────────────────────

class _LocationTrackTab extends ConsumerStatefulWidget {
  const _LocationTrackTab({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_LocationTrackTab> createState() => _LocationTrackTabState();
}

class _LocationTrackTabState extends ConsumerState<_LocationTrackTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 1));
  DateTime _to = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final params = (
      subjectId: widget.profileId,
      from: _from,
      to: _to,
    );
    final asyncTrack = ref.watch(trackForSubjectProvider(params));

    return Column(
      children: [
        // Date range selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _DateButton(
                label: 'From',
                date: _from,
                onChanged: (d) => setState(() => _from = d),
              ),
              const SizedBox(width: 8),
              _DateButton(
                label: 'To',
                date: _to,
                onChanged: (d) => setState(() => _to = d),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(trackForSubjectProvider(params)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: asyncTrack.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error: $error',
                  style: TextStyle(color: AppColors.error)),
            ),
            data: (points) {
              if (points.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No location data for this period'),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final pt = points[index];
                  final time = pt.hasTimestamp()
                      ? DateFormat.yMd().add_Hms().format(pt.timestamp.toDateTime())
                      : '';
                  final srcLabel = pt.source.name;
                  final isGps = srcLabel.contains('GPS');
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on,
                        size: 18,
                        color: isGps
                            ? AppColors.success
                            : AppColors.tertiary),
                    title: Text(
                        '${pt.latitude.toStringAsFixed(6)}, ${pt.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13)),
                    subtitle: Text(
                        '$time · $srcLabel · Accuracy: ${pt.accuracy.toStringAsFixed(0)}m'
                        '${pt.hasSpeed() ? " · Speed: ${pt.speed.toStringAsFixed(1)}m/s" : ""}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceMuted)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Geofence Events Tab ──────────────────────────────────────────────────────

class _GeofenceEventsTab extends ConsumerWidget {
  const _GeofenceEventsTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(geoEventsForSubjectProvider(profileId));

    return asyncEvents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load geofence events',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(geoEventsForSubjectProvider(profileId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fence_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No geofence events'),
                SizedBox(height: 4),
                Text('Events appear when a subject enters or exits a geofence area.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = events[index];
            final evtName = event.eventType.name;
            final icon = switch (evtName) {
              _ when evtName.contains('ENTER') => Icons.login,
              _ when evtName.contains('EXIT') => Icons.logout,
              _ when evtName.contains('DWELL') => Icons.hourglass_bottom,
              _ => Icons.location_on,
            };
            final label = switch (evtName) {
              _ when evtName.contains('ENTER') => 'Entered',
              _ when evtName.contains('EXIT') => 'Exited',
              _ when evtName.contains('DWELL') => 'Dwelling',
              _ => evtName,
            };
            final color = switch (evtName) {
              _ when evtName.contains('ENTER') => AppColors.success,
              _ when evtName.contains('EXIT') => AppColors.error,
              _ when evtName.contains('DWELL') => Colors.orange,
              _ => AppColors.onSurfaceMuted,
            };
            final time = event.hasTimestamp()
                ? DateFormat.yMd().add_Hms().format(event.timestamp.toDateTime())
                : '';
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              title: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color)),
              subtitle: Text(
                  'Area: ${event.areaId} · Confidence: ${(event.confidence * 100).toStringAsFixed(0)}%\n$time',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceMuted)),
            );
          },
        );
      },
    );
  }
}

// ─── Route Assignments Tab ────────────────────────────────────────────────────

class _RouteAssignmentsTab extends ConsumerWidget {
  const _RouteAssignmentsTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAssignments =
        ref.watch(routeAssignmentsForSubjectProvider(profileId));

    return asyncAssignments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load route assignments',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(routeAssignmentsForSubjectProvider(profileId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No route assignments'),
                SizedBox(height: 4),
                Text(
                    'Route assignments track deviation when a subject strays from a defined route.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final a = assignments[index];
            final validFrom = a.hasValidFrom()
                ? DateFormat.yMMMd().format(a.validFrom.toDateTime())
                : 'N/A';
            final validUntil = a.hasValidUntil()
                ? DateFormat.yMMMd().format(a.validUntil.toDateTime())
                : 'Ongoing';
            return ListTile(
              leading: Icon(Icons.route_outlined,
                  size: 20, color: AppColors.tertiary),
              title: Text('Route: ${a.routeId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      fontSize: 13)),
              subtitle: Text('$validFrom → $validUntil',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceMuted)),
            );
          },
        );
      },
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Text('$label: ${DateFormat.yMd().format(date)}'),
    );
  }
}

class _PresenceBadge extends StatelessWidget {
  const _PresenceBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ONLINE' => ('Online', Colors.green),
      'AWAY' => ('Away', Colors.orange),
      'BUSY' => ('Busy', Colors.red),
      _ => ('Offline', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              if (value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.onSurfaceMuted)),
                      ),
                      Expanded(
                        child: Text(value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
