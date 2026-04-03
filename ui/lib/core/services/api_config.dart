/// API endpoint and OAuth2 configuration for Antinvestor Admin Console.
///
/// Endpoints and credentials are configurable via `--dart-define`, e.g.:
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.antinvestor.com
/// ```
class ApiConfig {
  const ApiConfig._();

  // Service endpoints (configurable via --dart-define)
  static const String tenancyBaseUrl = String.fromEnvironment(
    'TENANCY_URL',
    defaultValue: 'https://api.stawi.org/tenancy',
  );

  static const String profileBaseUrl = String.fromEnvironment(
    'PROFILE_URL',
    defaultValue: 'https://api.stawi.org/profile',
  );

  static const String deviceBaseUrl = String.fromEnvironment(
    'DEVICE_URL',
    defaultValue: 'https://api.stawi.org/devices',
  );

  static const String geolocationBaseUrl = String.fromEnvironment(
    'GEOLOCATION_URL',
    defaultValue: 'https://api.stawi.org/geolocation',
  );

  static const String notificationBaseUrl = String.fromEnvironment(
    'NOTIFICATION_URL',
    defaultValue: 'https://api.stawi.org/notification',
  );

  static const String paymentBaseUrl = String.fromEnvironment(
    'PAYMENT_URL',
    defaultValue: 'https://api.stawi.org/payment',
  );

  static const String ledgerBaseUrl = String.fromEnvironment(
    'LEDGER_URL',
    defaultValue: 'https://api.stawi.org/ledger',
  );

  static const String settingsBaseUrl = String.fromEnvironment(
    'SETTINGS_URL',
    defaultValue: 'https://api.stawi.org/settings',
  );

  // OAuth2 configuration
  static const String oauth2IssuerUrl = String.fromEnvironment(
    'OAUTH2_ISSUER_URL',
    defaultValue: 'https://oauth2.stawi.org',
  );
  static const String oauth2ClientId = String.fromEnvironment(
    'OAUTH2_CLIENT_ID',
    defaultValue: 'd6qbqdkpf2t52mcunf3g',
  );

  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration idleTimeout = Duration(seconds: 120);
}
