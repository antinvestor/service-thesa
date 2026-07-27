/// API endpoint and OAuth2 configuration for Antinvestor Admin Console.
///
/// ## Endpoint resolution
///
/// Each service URL resolves in this priority order:
///   1. Explicit per-service env var (e.g. `PROFILE_URL=https://profile.custom.io`)
///   2. Shared base URL + service path  (e.g. `API_BASE_URL=https://api.example.com` → `.../profile`)
///   3. Built-in default               (`https://api.stawi.org/profile`)
///
/// This means you can:
/// - Set `API_BASE_URL` once to point all services at a single gateway.
/// - Override individual services that live on a different host.
///
/// ```sh
/// # All services behind one gateway:
/// flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// # Same, but notification lives elsewhere:
/// flutter run \
///   --dart-define=API_BASE_URL=https://api.example.com \
///   --dart-define=NOTIFICATION_URL=https://notify.internal.io
/// ```
class ApiConfig {
  const ApiConfig._();

  // ── Shared base URL ─────────────────────────────────────────────────────

  /// When set, provides the default base for all service endpoints.
  /// Individual `*_URL` vars take precedence over this.
  ///
  /// Also exposed publicly as [apiBaseUrl] for callers (e.g. the auth
  /// runtime config) that need the shared origin directly.
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.stawi.org',
  );

  /// Shared base URL for all Antinvestor services. Equivalent to the
  /// `API_BASE_URL` dart-define; falls back to `https://api.stawi.org`.
  static const String apiBaseUrl = _apiBaseUrl;

  // ── Per-service endpoint overrides ──────────────────────────────────────
  //
  // Each constant first checks for an explicit env var. If empty (not
  // supplied), it falls back to `_apiBaseUrl + /path`.

  static const String _tenancyExplicit = String.fromEnvironment('TENANCY_URL');
  static String get tenancyBaseUrl =>
      _tenancyExplicit.isNotEmpty ? _tenancyExplicit : '$_apiBaseUrl/tenancy';

  static const String _profileExplicit = String.fromEnvironment('PROFILE_URL');
  static String get profileBaseUrl =>
      _profileExplicit.isNotEmpty ? _profileExplicit : '$_apiBaseUrl/profile';

  static const String _deviceExplicit = String.fromEnvironment('DEVICE_URL');
  static String get deviceBaseUrl =>
      _deviceExplicit.isNotEmpty ? _deviceExplicit : '$_apiBaseUrl/devices';

  static const String _geolocationExplicit = String.fromEnvironment(
    'GEOLOCATION_URL',
  );
  static String get geolocationBaseUrl => _geolocationExplicit.isNotEmpty
      ? _geolocationExplicit
      : '$_apiBaseUrl/geolocation';

  static const String _notificationExplicit = String.fromEnvironment(
    'NOTIFICATION_URL',
  );
  static String get notificationBaseUrl => _notificationExplicit.isNotEmpty
      ? _notificationExplicit
      : '$_apiBaseUrl/notification';

  static const String _paymentExplicit = String.fromEnvironment('PAYMENT_URL');
  static String get paymentBaseUrl =>
      _paymentExplicit.isNotEmpty ? _paymentExplicit : '$_apiBaseUrl/payment';

  static const String _ledgerExplicit = String.fromEnvironment('LEDGER_URL');
  static String get ledgerBaseUrl =>
      _ledgerExplicit.isNotEmpty ? _ledgerExplicit : '$_apiBaseUrl/ledger';

  static const String _settingsExplicit = String.fromEnvironment(
    'SETTINGS_URL',
  );
  static String get settingsBaseUrl => _settingsExplicit.isNotEmpty
      ? _settingsExplicit
      : '$_apiBaseUrl/settings';

  static const String _billingExplicit = String.fromEnvironment('BILLING_URL');
  static String get billingBaseUrl =>
      _billingExplicit.isNotEmpty ? _billingExplicit : '$_apiBaseUrl/billing';

  static const String _filesExplicit = String.fromEnvironment('FILES_URL');
  static String get filesBaseUrl =>
      _filesExplicit.isNotEmpty ? _filesExplicit : '$_apiBaseUrl/files';

  static const String _auditExplicit = String.fromEnvironment('AUDIT_URL');
  static String get auditBaseUrl =>
      _auditExplicit.isNotEmpty ? _auditExplicit : '$_apiBaseUrl/audit';

  static const String _trustageExplicit = String.fromEnvironment(
    'TRUSTAGE_URL',
  );
  static String get trustageBaseUrl => _trustageExplicit.isNotEmpty
      ? _trustageExplicit
      : '$_apiBaseUrl/trustage';

  static const String _fortExplicit = String.fromEnvironment('FORT_URL');
  static String get fortBaseUrl =>
      _fortExplicit.isNotEmpty ? _fortExplicit : '$_apiBaseUrl/fort';

  static const String _thesaExplicit = String.fromEnvironment('THESA_URL');

  /// Thesa BFF base URL for analytics and other aggregation APIs.
  static String get thesaBaseUrl =>
      _thesaExplicit.isNotEmpty ? _thesaExplicit : '$_apiBaseUrl/thesa';

  // ── All endpoints (for iteration / diagnostics) ─────────────────────────

  /// Returns a map of service name → resolved endpoint URL.
  /// Useful for debugging and health checks.
  static Map<String, String> get allEndpoints => {
    'tenancy': tenancyBaseUrl,
    'profile': profileBaseUrl,
    'device': deviceBaseUrl,
    'geolocation': geolocationBaseUrl,
    'notification': notificationBaseUrl,
    'payment': paymentBaseUrl,
    'ledger': ledgerBaseUrl,
    'settings': settingsBaseUrl,
    'billing': billingBaseUrl,
    'files': filesBaseUrl,
    'audit': auditBaseUrl,
    'trustage': trustageBaseUrl,
    'fort': fortBaseUrl,
    'thesa': thesaBaseUrl,
  };

  // ── OAuth2 configuration ────────────────────────────────────────────────

  static const String oauth2IssuerUrl = String.fromEnvironment(
    'OAUTH2_ISSUER_URL',
    defaultValue: 'https://oauth2.stawi.org',
  );
  // Defaults to the STAGING "Thesa Studio Development" client so dev and
  // staging builds (e.g. the thesa0.web.app Firebase deploy) hit the staging
  // tenancy. Production builds override this via --dart-define=OAUTH2_CLIENT_ID
  // (see ui-build-prod in the Makefile).
  static const String oauth2ClientId = String.fromEnvironment(
    'OAUTH2_CLIENT_ID',
    defaultValue: 'd8gueekpf2tfslum7lpg',
  );

  // ── OAuth2 redirect URI ─────────────────────────────────────────────────

  /// Explicit redirect URI override. When set, takes precedence over
  /// automatic web-origin detection and the localhost fallback.
  static const String oauth2RedirectUri = String.fromEnvironment(
    'OAUTH2_REDIRECT_URI',
  );

  // ── Connection settings ─────────────────────────────────────────────────

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration idleTimeout = Duration(seconds: 120);
}
