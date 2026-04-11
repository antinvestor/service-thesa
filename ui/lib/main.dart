import 'package:antinvestor_ui_core/api/api_base.dart';
import 'package:antinvestor_ui_core/analytics/analytics_provider.dart';
import 'package:antinvestor_ui_core/auth/role_provider.dart';
import 'package:antinvestor_ui_core/permissions/permission_manifest.dart';
import 'package:antinvestor_ui_core/permissions/permission_provider.dart';
import 'package:antinvestor_ui_core/permissions/permission_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/services/analytics_client.dart';
import 'core/services/api_config.dart';
import 'core/services/auth_bridge.dart';
import 'core/services/permission_checker.dart';
import 'core/services/tenant_context.dart';
import 'features/audit/audit_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/billing/billing_service.dart';
import 'features/files/files_service.dart';
import 'features/geolocation/geolocation_service.dart';
import 'features/notification/notification_service.dart';
import 'features/partition/partition_service.dart';
import 'features/payment/payment_service.dart';
import 'features/profile/profile_service.dart';
import 'features/settings/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register admin services before app starts.
  // Existing services (thesa's own pages)
  registerTenancyService();
  registerProfileService();
  registerNotificationService();
  registerPaymentService();
  registerSettingsService();

  // New services from UI libraries
  registerFilesService();
  registerBillingService();
  registerGeolocationService();
  registerAuditService();

  // Register permission manifests from all service UI libraries.
  // These declare the proto-defined permissions each service needs,
  // enabling a single batch check at startup.
  _registerPermissionManifests();

  runApp(
    ProviderScope(
      overrides: [
        // Bridge thesa auth → ui_core AuthTokenProvider
        // Allows all service UI library providers to authenticate API calls.
        authTokenProviderProvider.overrideWith((ref) {
          final authRepo = ref.watch(authRepositoryProvider);
          return ThesaAuthTokenBridge(authRepo);
        }),
        // Bridge thesa JWT roles → ui_core string-based roles
        // Allows RoleGuard and role-based nav filtering to work.
        currentUserRolesProvider.overrideWith((ref) async {
          final ctx = await ref.watch(jwtTenantContextProvider.future);
          return ctx.roles.toSet();
        }),
        // Analytics data source backed by Thesa's analytics REST API.
        analyticsDataSourceProvider.overrideWith((ref) {
          return ThesaAnalyticsDataSource(
            http.Client(),
            ApiConfig.thesaBaseUrl,
          );
        }),
        // Batch permission check at startup.
        // Resolves all proto-defined permissions for the current user
        // via a single request to the thesa BFF.
        userPermissionsProvider.overrideWith((ref) async {
          final authRepo = ref.watch(authRepositoryProvider);
          final token = await authRepo.readToken('access_token');
          if (token == null || token.isEmpty) return const <String>{};

          final checker = PermissionBatchChecker(
            http.Client(),
            ApiConfig.thesaBaseUrl,
          );
          return checker.checkAll(token);
        }),
      ],
      child: const ThesaApp(),
    ),
  );
}

/// Register permission manifests for all service UI libraries.
/// The PermissionRegistry collects all permission keys so
/// the batch checker can resolve them in a single request.
void _registerPermissionManifests() {
  final registry = PermissionRegistry.instance;

  // Profile service
  registry.register(const PermissionManifest(
    namespace: 'service_profile',
    permissions: [
      PermissionEntry(key: 'profile_view', label: 'View Profiles', scope: PermissionScope.service),
      PermissionEntry(key: 'profile_create', label: 'Create Profiles', scope: PermissionScope.action),
      PermissionEntry(key: 'profile_update', label: 'Update Profiles', scope: PermissionScope.action),
      PermissionEntry(key: 'profile_merge', label: 'Merge Profiles', scope: PermissionScope.action),
      PermissionEntry(key: 'contact_manage', label: 'Manage Contacts', scope: PermissionScope.feature),
      PermissionEntry(key: 'roster_view', label: 'View Roster', scope: PermissionScope.feature),
      PermissionEntry(key: 'roster_manage', label: 'Manage Roster', scope: PermissionScope.action),
      PermissionEntry(key: 'address_manage', label: 'Manage Addresses', scope: PermissionScope.feature),
      PermissionEntry(key: 'relationship_view', label: 'View Relationships', scope: PermissionScope.feature),
      PermissionEntry(key: 'relationship_manage', label: 'Manage Relationships', scope: PermissionScope.action),
    ],
  ));

  // Device service
  registry.register(const PermissionManifest(
    namespace: 'service_device',
    permissions: [
      PermissionEntry(key: 'device_view', label: 'View Devices', scope: PermissionScope.service),
      PermissionEntry(key: 'device_create', label: 'Create Devices', scope: PermissionScope.action),
      PermissionEntry(key: 'device_update', label: 'Update Devices', scope: PermissionScope.action),
      PermissionEntry(key: 'device_remove', label: 'Remove Devices', scope: PermissionScope.action),
      PermissionEntry(key: 'device_key_manage', label: 'Manage Device Keys', scope: PermissionScope.feature),
      PermissionEntry(key: 'device_log_view', label: 'View Device Logs', scope: PermissionScope.feature),
    ],
  ));

  // Settings service
  registry.register(const PermissionManifest(
    namespace: 'service_setting',
    permissions: [
      PermissionEntry(key: 'setting_view', label: 'View Settings', scope: PermissionScope.service),
      PermissionEntry(key: 'setting_update', label: 'Update Settings', scope: PermissionScope.action),
    ],
  ));

  // Geolocation service
  registry.register(const PermissionManifest(
    namespace: 'service_geolocation',
    permissions: [
      PermissionEntry(key: 'area_view', label: 'View Areas', scope: PermissionScope.feature),
      PermissionEntry(key: 'area_manage', label: 'Manage Areas', scope: PermissionScope.action),
      PermissionEntry(key: 'route_view', label: 'View Routes', scope: PermissionScope.feature),
      PermissionEntry(key: 'route_manage', label: 'Manage Routes', scope: PermissionScope.action),
      PermissionEntry(key: 'location_view', label: 'View Locations', scope: PermissionScope.feature),
      PermissionEntry(key: 'event_view', label: 'View Geo Events', scope: PermissionScope.feature),
    ],
  ));

  // Payment service
  registry.register(const PermissionManifest(
    namespace: 'service_payment',
    permissions: [
      PermissionEntry(key: 'payment_search', label: 'Search Payments', scope: PermissionScope.service),
      PermissionEntry(key: 'payment_send', label: 'Send Payments', scope: PermissionScope.action),
      PermissionEntry(key: 'payment_receive', label: 'Receive Payments', scope: PermissionScope.action),
      PermissionEntry(key: 'payment_link_create', label: 'Create Payment Links', scope: PermissionScope.action),
      PermissionEntry(key: 'payment_reconcile', label: 'Reconcile Payments', scope: PermissionScope.action),
    ],
  ));

  // Ledger service
  registry.register(const PermissionManifest(
    namespace: 'service_ledger',
    permissions: [
      PermissionEntry(key: 'ledger_view', label: 'View Ledgers', scope: PermissionScope.service),
      PermissionEntry(key: 'ledger_create', label: 'Create Ledgers', scope: PermissionScope.action),
      PermissionEntry(key: 'account_view', label: 'View Accounts', scope: PermissionScope.feature),
      PermissionEntry(key: 'account_create', label: 'Create Accounts', scope: PermissionScope.action),
      PermissionEntry(key: 'transaction_view', label: 'View Transactions', scope: PermissionScope.feature),
      PermissionEntry(key: 'transaction_create', label: 'Create Transactions', scope: PermissionScope.action),
    ],
  ));

  // Billing service
  registry.register(const PermissionManifest(
    namespace: 'service_billing',
    permissions: [
      PermissionEntry(key: 'catalog_view', label: 'View Catalogs', scope: PermissionScope.feature),
      PermissionEntry(key: 'catalog_manage', label: 'Manage Catalogs', scope: PermissionScope.action),
      PermissionEntry(key: 'subscription_view', label: 'View Subscriptions', scope: PermissionScope.feature),
      PermissionEntry(key: 'subscription_manage', label: 'Manage Subscriptions', scope: PermissionScope.action),
      PermissionEntry(key: 'invoice_view', label: 'View Invoices', scope: PermissionScope.feature),
      PermissionEntry(key: 'invoice_manage', label: 'Manage Invoices', scope: PermissionScope.action),
      PermissionEntry(key: 'usage_view', label: 'View Usage Events', scope: PermissionScope.feature),
      PermissionEntry(key: 'billing_run_execute', label: 'Execute Billing Runs', scope: PermissionScope.action),
      PermissionEntry(key: 'credit_manage', label: 'Manage Credits', scope: PermissionScope.action),
      PermissionEntry(key: 'discount_view', label: 'View Discounts', scope: PermissionScope.feature),
      PermissionEntry(key: 'discount_manage', label: 'Manage Discounts', scope: PermissionScope.action),
    ],
  ));

  // Notification service
  registry.register(const PermissionManifest(
    namespace: 'service_notification',
    permissions: [
      PermissionEntry(key: 'notification_send', label: 'Send Notifications', scope: PermissionScope.action),
      PermissionEntry(key: 'notification_search', label: 'Search Notifications', scope: PermissionScope.service),
      PermissionEntry(key: 'notification_status_view', label: 'View Notification Status', scope: PermissionScope.feature),
      PermissionEntry(key: 'template_manage', label: 'Manage Templates', scope: PermissionScope.feature),
    ],
  ));

  // Files service
  registry.register(const PermissionManifest(
    namespace: 'service_files',
    permissions: [
      PermissionEntry(key: 'file_view', label: 'View Files', scope: PermissionScope.service),
      PermissionEntry(key: 'file_upload', label: 'Upload Files', scope: PermissionScope.action),
      PermissionEntry(key: 'file_delete', label: 'Delete Files', scope: PermissionScope.action),
      PermissionEntry(key: 'file_access_manage', label: 'Manage File Access', scope: PermissionScope.feature),
      PermissionEntry(key: 'file_version_manage', label: 'Manage File Versions', scope: PermissionScope.feature),
      PermissionEntry(key: 'file_retention_manage', label: 'Manage Retention Policies', scope: PermissionScope.feature),
    ],
  ));

  // Tenancy service
  registry.register(const PermissionManifest(
    namespace: 'service_tenancy',
    permissions: [
      PermissionEntry(key: 'tenancy_view', label: 'View Tenants', scope: PermissionScope.service),
      PermissionEntry(key: 'tenancy_create', label: 'Create Tenants', scope: PermissionScope.action),
      PermissionEntry(key: 'tenancy_update', label: 'Update Tenants', scope: PermissionScope.action),
      PermissionEntry(key: 'partition_view', label: 'View Partitions', scope: PermissionScope.feature),
      PermissionEntry(key: 'partition_create', label: 'Create Partitions', scope: PermissionScope.action),
    ],
  ));

  // Audit service
  registry.register(const PermissionManifest(
    namespace: 'service_audit',
    permissions: [
      PermissionEntry(key: 'audit_view', label: 'View Audit Log', scope: PermissionScope.service),
      PermissionEntry(key: 'audit_search', label: 'Search Audit Entries', scope: PermissionScope.feature),
      PermissionEntry(key: 'audit_export', label: 'Export Audit Data', scope: PermissionScope.action),
      PermissionEntry(key: 'audit_verify', label: 'Verify Integrity', scope: PermissionScope.action),
    ],
  ));
}
