import 'package:antinvestor_ui_core/api/api_base.dart';
import 'package:antinvestor_ui_core/auth/role_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/auth_bridge.dart';
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
      ],
      child: const ThesaApp(),
    ),
  );
}
