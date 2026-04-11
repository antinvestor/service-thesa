import 'dart:convert';

import 'package:antinvestor_ui_core/permissions/permission_registry.dart';
import 'package:http/http.dart' as http;

/// Performs a batch permission check against the thesa BFF backend.
/// Collects all permission manifests from registered service UI libraries
/// and checks them all in a single request.
class PermissionBatchChecker {
  PermissionBatchChecker(this._httpClient, this._baseUrl);

  final http.Client _httpClient;
  final String _baseUrl;

  /// Check all permissions for the current user.
  /// Returns the set of permission keys the user has.
  Future<Set<String>> checkAll(String accessToken) async {
    final registry = PermissionRegistry.instance;
    final permsByNamespace = registry.permissionsByNamespace;

    if (permsByNamespace.isEmpty) {
      return const <String>{};
    }

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/ui/capabilities/batch-check'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'checks': permsByNamespace.entries
            .map((e) => {
                  'namespace': e.key,
                  'permissions': e.value.toList(),
                })
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      // Fall back to the existing capabilities endpoint and extract
      // permissions from the flat capabilities map.
      return _fallbackCheck(accessToken);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final granted = data['granted'] as List?;
    if (granted == null) return const <String>{};
    return granted.map((e) => e.toString()).toSet();
  }

  /// Fallback: use the existing GET /ui/capabilities endpoint.
  /// Extracts granted permissions from the capabilities map.
  Future<Set<String>> _fallbackCheck(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/ui/capabilities'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      return const <String>{};
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract from user.permissions array if available.
    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final permissions = user['permissions'] as List?;
      if (permissions != null) {
        return permissions.map((e) => e.toString()).toSet();
      }
    }

    // Extract from capabilities map (keys where enabled=true).
    final capabilities =
        data['capabilities'] as Map<String, dynamic>?;
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
