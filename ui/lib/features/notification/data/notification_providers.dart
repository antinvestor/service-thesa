import 'package:antinvestor_api_notification/antinvestor_api_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_repository.dart';

/// All notifications.
final notificationsProvider =
    FutureProvider<List<Notification>>((ref) async {
  final repo = await ref.watch(notificationRepositoryProvider.future);
  return repo.search();
});

/// All templates.
final templatesProvider =
    FutureProvider<List<Template>>((ref) async {
  final repo = await ref.watch(notificationRepositoryProvider.future);
  return repo.searchTemplates();
});

/// Templates filtered by language.
final templatesByLanguageProvider =
    FutureProvider.family<List<Template>, String>((ref, lang) async {
  final repo = await ref.watch(notificationRepositoryProvider.future);
  return repo.searchTemplates(languageCode: lang);
});
