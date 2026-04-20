import 'package:flutter_test/flutter_test.dart';
import 'package:thesa/core/auth/runtime_provider.dart';

/// Guards thesa's OAuth audience surface. The runtime passes
/// `audience=<comma-joined-list>` on the token-exchange form POST when
/// [AuthConfig.audiences] is non-empty (see
/// `service-authentication/ui/runtime/lib/src/protocol/token_exchange.dart`).
///
/// Hydra is configured to mint a single access token bearing all 9
/// resource audiences for thesa; a drift in either the list or the
/// join separator would quietly break every per-service RPC (the
/// backend resolves `aud` to decide which service-bound scopes are
/// honoured). Pin both here so accidental edits to
/// [kThesaAuthConfig] fail fast.
void main() {
  group('kThesaAuthConfig audiences', () {
    test('declares the 9 service-bound audiences required by backends', () {
      expect(kThesaAuthConfig.audiences, isNotNull);
      expect(kThesaAuthConfig.audiences, hasLength(9));
      expect(
        kThesaAuthConfig.audiences,
        containsAllInOrder(const <String>[
          'service_tenancy',
          'service_device',
          'service_profile',
          'service_notification',
          'service_payment',
          'service_ledger',
          'service_setting',
          'service_thesa',
          'service_file',
        ]),
      );
    });

    test(
      'comma-joined form matches the runtime token-exchange payload',
      () {
        // Mirrors the shape the runtime emits as the `audience` form field
        // during the PKCE code exchange: a single comma-separated string,
        // no trailing separator.
        expect(
          kThesaAuthConfig.audiences!.join(','),
          'service_tenancy,service_device,service_profile,service_notification,'
          'service_payment,service_ledger,service_setting,service_thesa,'
          'service_file',
        );
      },
    );
  });
}
