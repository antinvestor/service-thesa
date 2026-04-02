import 'package:antinvestor_api_settings/antinvestor_api_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_repository.dart';

/// All settings (initial load).
final allSettingsProvider =
    FutureProvider<List<SettingObject>>((ref) async {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  return repo.search();
});

/// Settings filtered to a specific module.
final settingsByModuleProvider =
    FutureProvider.family<List<SettingObject>, String>((ref, module) async {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  return repo.list(module: module);
});

/// Search results for a query.
final settingsSearchProvider =
    FutureProvider.family<List<SettingObject>, String>((ref, query) async {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  return repo.search(query: query);
});
