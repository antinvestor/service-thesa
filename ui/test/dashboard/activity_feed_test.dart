import 'package:antinvestor_api_audit/antinvestor_api_audit.dart';
import 'package:antinvestor_ui_audit/antinvestor_ui_audit.dart'
    show auditEntriesProvider;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:thesa/features/dashboard/widgets/activity_feed.dart';

AuditEntryObject _entry({
  String action = 'create',
  String resourceType = 'tenant',
  String resourceId = 'd8gueekpf2tfslum7lmg',
  String service = 'service_tenancy',
}) {
  return AuditEntryObject(
    action: action,
    resourceType: resourceType,
    resourceId: resourceId,
    service: service,
    profileId: 'd75qclkpf2t1uum8ij3g',
    createdAt: Timestamp(
      seconds: Int64(
        DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
      ),
    ),
  );
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    // Disable Riverpod's automatic retry so a failing provider settles on
    // AsyncError instead of looping back to loading during the test.
    retry: (retryCount, error) => null,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ActivityFeed())),
    ),
  );
}

void main() {
  testWidgets('renders audit entries from the audit service', (tester) async {
    await tester.pumpWidget(
      _wrap([
        auditEntriesProvider.overrideWith(
          (ref, params) async => [
            _entry(),
            _entry(
              action: 'update',
              resourceType: 'partition',
              service: 'service_profile',
            ),
          ],
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Recent Activities'), findsOneWidget);
    expect(find.text('Create tenant'), findsOneWidget);
    expect(find.text('Update partition'), findsOneWidget);
    expect(find.text('tenancy'), findsOneWidget);
    expect(find.text('profile'), findsOneWidget);
    expect(find.text('5m ago'), findsNWidgets(2));
  });

  testWidgets('empty audit trail renders the empty state', (tester) async {
    await tester.pumpWidget(
      _wrap([
        auditEntriesProvider.overrideWith((ref, params) async => []),
      ]),
    );
    await tester.pump();

    expect(find.text('No recent activity'), findsOneWidget);
  });

  testWidgets('audit service failure renders the error state', (tester) async {
    await tester.pumpWidget(
      _wrap([
        auditEntriesProvider.overrideWith(
          (ref, params) async => throw Exception('boom'),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not load activity'), findsOneWidget);
  });
}
