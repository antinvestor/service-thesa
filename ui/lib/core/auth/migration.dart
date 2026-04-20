import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clear legacy auth-stack tokens so the runtime forces a fresh sign-in
/// on the first launch after the migration. Runs once per install;
/// subsequent launches short-circuit on the persisted flag and are
/// effectively no-ops.
///
/// The pre-migration auth service stored its tokens under the keys
/// below in the default secure-storage namespace. The runtime uses its
/// own keys under a separate prefix, so leaving the stale entries in
/// place is harmless — but clearing them avoids surprises if a future
/// diagnostic tool enumerates the keychain.
Future<void> migrateLegacyAuthIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('auth_runtime_migrated') ?? false) return;
  const storage = FlutterSecureStorage();
  for (final key in const [
    'access_token',
    'refresh_token',
    'id_token',
    'token_expires_at',
  ]) {
    try {
      await storage.delete(key: key);
    } catch (_) {
      // Swallow: a failing delete (missing key, locked keychain on a
      // headless test runner) must not block app startup.
    }
  }
  await prefs.setBool('auth_runtime_migrated', true);
}
