import 'package:flutter_test/flutter_test.dart';
import 'package:thesa/core/auth/runtime_provider.dart';

void main() {
  group('buildThesaAuthConfig audiences', () {
    test('declares the 11 service-bound audiences required by backends', () {
      final config = buildThesaAuthConfig();
      expect(config.audiences, isNotNull);
      expect(config.audiences, hasLength(11));
      expect(
        config.audiences,
        containsAllInOrder(const <String>[
          'service_tenancy',
          'service_device',
          'service_profile',
          'service_notification',
          'service_payment',
          'service_ledger',
          'service_setting',
          'service_file',
          'service_trustage',
          'service_thesa',
          'service_audit',
        ]),
      );
    });

    test('comma-joined form matches the runtime token-exchange payload', () {
      final config = buildThesaAuthConfig();
      expect(
        config.audiences!.join(','),
        'service_tenancy,service_device,service_profile,service_notification,'
        'service_payment,service_ledger,service_setting,'
        'service_file,service_trustage,service_thesa,service_audit',
      );
    });
  });
}
