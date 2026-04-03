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

// ── Derived analytics providers ─────────────────────────────────────────────

/// Unique modules extracted from all settings.
final settingsModulesProvider =
    FutureProvider<List<SettingsModuleInfo>>((ref) async {
  final all = await ref.watch(allSettingsProvider.future);
  final moduleMap = <String, List<SettingObject>>{};
  for (final s in all) {
    final m = s.hasKey() && s.key.module.isNotEmpty
        ? s.key.module
        : '(default)';
    moduleMap.putIfAbsent(m, () => []).add(s);
  }
  final modules = moduleMap.entries.map((e) {
    final objects = <String>{};
    final langs = <String>{};
    for (final s in e.value) {
      if (s.hasKey()) {
        if (s.key.object.isNotEmpty) objects.add(s.key.object);
        if (s.key.lang.isNotEmpty) langs.add(s.key.lang);
      }
    }
    return SettingsModuleInfo(
      name: e.key,
      settingCount: e.value.length,
      objectTypes: objects.toList()..sort(),
      languages: langs.toList()..sort(),
      settings: e.value,
    );
  }).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return modules;
});

/// Summary statistics derived from all settings.
final settingsStatsProvider = FutureProvider<SettingsStats>((ref) async {
  final all = await ref.watch(allSettingsProvider.future);
  final modules = <String>{};
  final objects = <String>{};
  final languages = <String>{};
  for (final s in all) {
    if (s.hasKey()) {
      if (s.key.module.isNotEmpty) modules.add(s.key.module);
      if (s.key.object.isNotEmpty) objects.add(s.key.object);
      if (s.key.lang.isNotEmpty) languages.add(s.key.lang);
    }
  }
  return SettingsStats(
    totalSettings: all.length,
    moduleCount: modules.length,
    objectTypeCount: objects.length,
    languageCount: languages.length,
    modules: modules.toList()..sort(),
    objectTypes: objects.toList()..sort(),
    languages: languages.toList()..sort(),
  );
});

// ── Data models ─────────────────────────────────────────────────────────────

class SettingsModuleInfo {
  const SettingsModuleInfo({
    required this.name,
    required this.settingCount,
    required this.objectTypes,
    required this.languages,
    required this.settings,
  });

  final String name;
  final int settingCount;
  final List<String> objectTypes;
  final List<String> languages;
  final List<SettingObject> settings;
}

class SettingsStats {
  const SettingsStats({
    required this.totalSettings,
    required this.moduleCount,
    required this.objectTypeCount,
    required this.languageCount,
    required this.modules,
    required this.objectTypes,
    required this.languages,
  });

  final int totalSettings;
  final int moduleCount;
  final int objectTypeCount;
  final int languageCount;
  final List<String> modules;
  final List<String> objectTypes;
  final List<String> languages;
}
