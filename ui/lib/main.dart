import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notification/notification_service.dart';
import 'features/partition/partition_service.dart';
import 'features/payment/payment_service.dart';
import 'features/profile/profile_service.dart';
import 'features/settings/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register admin services before app starts.
  registerTenancyService();
  registerProfileService();
  registerNotificationService();
  registerPaymentService();
  registerSettingsService();

  runApp(const ProviderScope(child: ThesaApp()));
}
