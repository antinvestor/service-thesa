import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search query shared between the header search bar and entity list pages.
///
/// When the user types in the header search bar, this provider updates.
/// Entity list pages watch this provider to trigger server-side search.
/// Cleared automatically on route changes via [globalSearchNotifierProvider].
final globalSearchQueryProvider =
    NotifierProvider<GlobalSearchNotifier, String>(GlobalSearchNotifier.new);

class GlobalSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;

  void clear() => state = '';
}
