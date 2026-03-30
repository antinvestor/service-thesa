import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/partition/partition_service.dart';
import 'features/profile/profile_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register admin services before app starts.
  registerTenancyService();
  registerProfileService();

  runApp(const ProviderScope(child: ThesaApp()));
}
