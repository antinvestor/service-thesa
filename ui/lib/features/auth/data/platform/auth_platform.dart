import 'package:openid_client/openid_client.dart';

/// Abstract class for platform-specific authentication logic.
abstract class AuthPlatform {
  Future<void> initialize(String issuerUrl, String clientId);
  Future<TokenResponse?> authenticate(
    List<String> scopes, {
    List<String> audiences,
  });
  Future<TokenResponse?> getRedirectResult();
  Future<void> cancelAuthentication() async {}
  Client? get client;
}
