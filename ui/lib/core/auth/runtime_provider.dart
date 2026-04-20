import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';

import '../services/api_config.dart';

/// Auth-runtime configuration for the thesa admin console.
///
/// Values mirror the legacy [ApiConfig] OAuth2 settings and the existing
/// desktop loopback used by the retired openid_client flow
/// (`http://localhost:5173/auth/callback`). The redirect path is kept
/// identical so an already-registered Hydra client continues to accept
/// the new runtime's authorize requests unchanged.
///
/// `apiBaseUrl` holds the shared API origin; per-service endpoints
/// (tenancy, profile, device, payment, …) remain in [ApiConfig] and are
/// wired through `runtime.fetch` by [RuntimeTransport]. The runtime
/// v0.3.1+ detects absolute URLs and skips its own `apiBaseUrl`
/// concatenation, so per-service routing survives end-to-end.
///
/// Audiences are the 9-element list required by the backend services
/// thesa talks to: tenancy, device, profile, notification, payment,
/// ledger, setting, thesa, file.
const String kThesaRedirectUri = 'http://localhost:5173/auth/callback';

const AuthConfig kThesaAuthConfig = AuthConfig(
  clientId: ApiConfig.oauth2ClientId,
  idpBaseUrl: ApiConfig.oauth2IssuerUrl,
  apiBaseUrl: ApiConfig.apiBaseUrl,
  redirectScheme: 'com.antinvestor.thesa',
  redirectUri: kThesaRedirectUri,
  scopes: ['openid', 'profile', 'offline_access'],
  audiences: [
    'service_tenancy',
    'service_device',
    'service_profile',
    'service_notification',
    'service_payment',
    'service_ledger',
    'service_setting',
    'service_thesa',
    'service_file',
  ],
);

/// Constructs a fresh [AuthRuntime] for the thesa admin console.
///
/// Call once at app start and override `authRuntimeProvider` with the
/// resulting instance so every consumer shares the same runtime.
AuthRuntime buildThesaRuntime() => createAuthRuntime(kThesaAuthConfig);
