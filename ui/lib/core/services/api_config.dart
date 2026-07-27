/// API endpoint and OAuth2 configuration for Antinvestor Admin Console.
///
/// ## Endpoint resolution
///
/// Each service URL resolves in this priority order:
///   1. Explicit per-service env var (e.g. `PROFILE_URL=https://profile.custom.io`)
///   2. Subdomain of the platform apex  (e.g. `API_BASE_URL=https://stawi.org` → `https://profile.stawi.org`)
///   3. Built-in default               (`https://profile.stawi.org`)
///
/// `API_BASE_URL` may be either the apex (`https://stawi.org`) or the legacy
/// gateway host (`https://api.stawi.org`); both resolve to service subdomains.
///
/// ```sh
/// # All services under stawi.org subdomains:
/// flutter run --dart-define=API_BASE_URL=https://stawi.org
///
/// # Same, but notification lives elsewhere:
/// flutter run \\
///   --dart-define=API_BASE_URL=https://stawi.org \\
///   --dart-define=NOTIFICATION_URL=https://notify.internal.io
/// ```
class ApiConfig {
  const ApiConfig._();

  // ── Shared base URL ─────────────────────────────────────────────────────

  /// Platform apex or legacy gateway host. Prefer `https://stawi.org`.
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stawi.org',
  );

  /// Shared base URL for callers that need the platform origin.
  static const String apiBaseUrl = _apiBaseUrl;

  /// Build `https://{service}.{apex}` from [apiBaseUrl].
  /// Strips a leading `api.` gateway label when present.
  static String serviceUrl(String service) {
    final uri = Uri.parse(_apiBaseUrl);
    var host = uri.host;
    if (host.startsWith('api.')) {
      host = host.substring(4);
    }
    if (host.isEmpty) {
      host = 'stawi.org';
    }
    return 'https://$service.$host';
  }

  // ── Per-service endpoint overrides ──────────────────────────────────────

  static const String _tenancyExplicit = String.fromEnvironment('TENANCY_URL');
  static String get tenancyBaseUrl =>
      _tenancyExplicit.isNotEmpty ? _tenancyExplicit : serviceUrl('tenancy');

  static const String _profileExplicit = String.fromEnvironment('PROFILE_URL');
  static String get profileBaseUrl =>
      _profileExplicit.isNotEmpty ? _profileExplicit : serviceUrl('profile');

  static const String _deviceExplicit = String.fromEnvironment('DEVICE_URL');
  static String get deviceBaseUrl =>
      _deviceExplicit.isNotEmpty ? _deviceExplicit : serviceUrl('devices');

  static const String _geolocationExplicit = String.fromEnvironment(
    'GEOLOCATION_URL',
  );
  static String get geolocationBaseUrl => _geolocationExplicit.isNotEmpty
      ? _geolocationExplicit
      : serviceUrl('geolocation');

  static const String _notificationExplicit = String.fromEnvironment(
    'NOTIFICATION_URL',
  );
  static String get notificationBaseUrl => _notificationExplicit.isNotEmpty
      ? _notificationExplicit
      : serviceUrl('notification');

  static const String _paymentExplicit = String.fromEnvironment('PAYMENT_URL');
  static String get paymentBaseUrl =>
      _paymentExplicit.isNotEmpty ? _paymentExplicit : serviceUrl('payment');

  static const String _ledgerExplicit = String.fromEnvironment('LEDGER_URL');
  static String get ledgerBaseUrl =>
      _ledgerExplicit.isNotEmpty ? _ledgerExplicit : serviceUrl('ledger');

  static const String _settingsExplicit = String.fromEnvironment(
    'SETTINGS_URL',
  );
  static String get settingsBaseUrl => _settingsExplicit.isNotEmpty
      ? _settingsExplicit
      : serviceUrl('settings');

  static const String _billingExplicit = String.fromEnvironment('BILLING_URL');
  static String get billingBaseUrl =>
      _billingExplicit.isNotEmpty ? _billingExplicit : serviceUrl('billing');

  static const String _filesExplicit = String.fromEnvironment('FILES_URL');
  static String get filesBaseUrl =>
      _filesExplicit.isNotEmpty ? _filesExplicit : serviceUrl('files');

  static const String _auditExplicit = String.fromEnvironment('AUDIT_URL');
  static String get auditBaseUrl =>
      _auditExplicit.isNotEmpty ? _auditExplicit : serviceUrl('audit');

  static const String _trustageExplicit = String.fromEnvironment(
    'TRUSTAGE_URL',
  );
  static String get trustageBaseUrl => _trustageExplicit.isNotEmpty
      ? _trustageExplicit
      : serviceUrl('trustage');

  static const String _fortExplicit = String.fromEnvironment('FORT_URL');
  static String get fortBaseUrl =>
      _fortExplicit.isNotEmpty ? _fortExplicit : serviceUrl('fort');

  static const String _thesaExplicit = String.fromEnvironment('THESA_URL');

  /// Thesa BFF base URL for analytics and other aggregation APIs.
  static String get thesaBaseUrl =>
      _thesaExplicit.isNotEmpty ? _thesaExplicit : serviceUrl('thesa');

  // ── All endpoints (for iteration / diagnostics) ─────────────────────────

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
  static const String oauth2ClientId = String.fromEnvironment(
    'OAUTH2_CLIENT_ID',
    defaultValue: 'd8gueekpf2tfslum7lpg',
  );

  static const String oauth2RedirectUri = String.fromEnvironment(
    'OAUTH2_REDIRECT_URI',
  );


  // ── Connection settings ─────────────────────────────────────────────────

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration idleTimeout = Duration(seconds: 120);
}
