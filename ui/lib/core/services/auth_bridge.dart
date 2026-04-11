import 'package:antinvestor_ui_core/auth/auth_token_provider.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_service.dart' as auth;

/// Bridges thesa's AuthRepository to ui_core's AuthTokenProvider interface.
///
/// This allows all service UI library providers (profile, payment, files, etc.)
/// to authenticate API calls using thesa's existing OAuth2 token management.
class ThesaAuthTokenBridge implements AuthTokenProvider {
  ThesaAuthTokenBridge(this._authRepo);
  final AuthRepository _authRepo;

  @override
  Future<String?> ensureValidAccessToken() async {
    final result = await _authRepo.ensureValidAccessTokenWithStatus();
    return result.token;
  }

  @override
  Future<String?> forceRefreshAccessToken() async {
    final result = await _authRepo.refreshTokenWithResult();
    if (result.result != auth.TokenRefreshResult.success) return null;
    return _authRepo.getAccessToken();
  }

  @override
  Future<void> logout() => _authRepo.logout();
}
