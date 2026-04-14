import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_repository.dart';

/// Profiles search provider. Accepts a query string for server-side search
/// by name, contact, or profile details. Pass empty string for initial load.
final profilesProvider =
    FutureProvider.family<List<ProfileObject>, String>((ref, query) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.search(query: query);
});
