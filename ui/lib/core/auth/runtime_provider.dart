import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/redirect_uri.dart';
import '../services/api_config.dart';
import 'desktop_loopback_auth_stub.dart'
    if (dart.library.io) 'desktop_loopback_auth_io.dart';

/// Localhost loopback used by flutter_appauth on desktop platforms.
const String _kDesktopLoopbackUri = 'http://localhost:5173/auth/callback';

/// Resolves the OAuth redirect URI at runtime.
///
/// Priority:
///   1. Explicit `OAUTH2_REDIRECT_URI` dart-define override.
///   2. On web: derived from `Uri.base` (the browser's current origin).
///   3. Fallback: localhost loopback for desktop OAuth callbacks.
String _resolveRedirectUri() {
  if (ApiConfig.oauth2RedirectUri.isNotEmpty) {
    return ApiConfig.oauth2RedirectUri;
  }
  return resolveRedirectUri(_kDesktopLoopbackUri);
}

/// Builds the auth-runtime configuration for the thesa admin console.
///
/// The redirect URI is resolved dynamically so login works on any
/// host/port — not just localhost:5173. See [_resolveRedirectUri].
@visibleForTesting
AuthConfig buildThesaAuthConfig() => AuthConfig(
  clientId: ApiConfig.oauth2ClientId,
  idpBaseUrl: ApiConfig.oauth2IssuerUrl,
  apiBaseUrl: ApiConfig.apiBaseUrl,
  redirectScheme: 'org.stawi.thesa',
  redirectUri: _resolveRedirectUri(),
  scopes: const ['openid', 'profile', 'offline_access'],
  audiences: const [
    'service_tenancy',
    'service_device',
    'service_profile',
    'service_notification',
    'service_payment',
    'service_ledger',
    'service_setting',
    'service_file',
    'service_trustage',
    // The Thesa BFF itself — its analytics endpoints verify tokens with
    // audience service_thesa.
    'service_thesa',
    // Audit trail service — backs the dashboard activity feed and the
    // audit log screens.
    'service_audit',
  ],
);

/// Constructs a fresh [AuthRuntime] for the thesa admin console.
///
/// Call once at app start and override `authRuntimeProvider` with the
/// resulting instance so every consumer shares the same runtime.
AuthRuntime buildThesaRuntime() {
  final AuthConfig config = buildThesaAuthConfig();
  // On Linux/Windows with a localhost redirect, drive the OAuth leg
  // through the system browser + loopback server instead of the embedded
  // webview (which intermittently deadlocks before its window appears).
  configureDesktopLoopbackAuth(config.redirectUri ?? '');
  return createAuthRuntime(config);
}
