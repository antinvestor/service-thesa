import 'dart:convert';
import 'dart:typed_data';

import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:antinvestor_ui_core/permissions/permission_registry.dart';

/// Runtime-backed permission checker that routes every call through
/// `AuthRuntime.fetch`. The runtime owns the access token and adds the
/// `Authorization` header transparently — callers never see the raw
/// token.
class RuntimePermissionBatchChecker {
  RuntimePermissionBatchChecker(this._runtime, this._baseUrl);

  final AuthRuntime _runtime;
  final String _baseUrl;

  /// Check all permissions for the current user via the runtime.
  Future<Set<String>> checkAll() async {
    final registry = PermissionRegistry.instance;
    final permsByNamespace = registry.permissionsByNamespace;

    if (permsByNamespace.isEmpty) {
      return const <String>{};
    }

    final body = utf8.encode(jsonEncode({
      'checks': permsByNamespace.entries
          .map((e) => {
                'namespace': e.key,
                'permissions': e.value.toList(),
              })
          .toList(),
    }));

    final response = await _runtime.fetch(
      '$_baseUrl/ui/capabilities/batch-check',
      method: 'POST',
      headers: const {'Content-Type': 'application/json'},
      body: Uint8List.fromList(body),
    );

    if (response.status != 200) {
      return _fallbackCheck();
    }

    final decoded = jsonDecode(utf8.decode(response.body))
        as Map<String, dynamic>;
    final granted = decoded['granted'] as List?;
    if (granted == null) return const <String>{};
    return granted.map((e) => e.toString()).toSet();
  }

  Future<Set<String>> _fallbackCheck() async {
    final response = await _runtime.fetch(
      '$_baseUrl/ui/capabilities',
    );
    if (response.status != 200) return const <String>{};
    final decoded = jsonDecode(utf8.decode(response.body))
        as Map<String, dynamic>;

    final user = decoded['user'] as Map<String, dynamic>?;
    if (user != null) {
      final permissions = user['permissions'] as List?;
      if (permissions != null) {
        return permissions.map((e) => e.toString()).toSet();
      }
    }

    final capabilities =
        decoded['capabilities'] as Map<String, dynamic>?;
    if (capabilities != null) {
      return capabilities.entries
          .where((e) {
            final v = e.value;
            if (v is Map) return v['enabled'] == true;
            if (v is bool) return v;
            return false;
          })
          .map((e) => e.key)
          .toSet();
    }

    return const <String>{};
  }
}
