import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_repository.dart';

/// Profiles search provider. Fetches all profiles (initial load).
final profilesProvider =
    FutureProvider.autoDispose<List<ProfileObject>>((ref) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.search();
});
