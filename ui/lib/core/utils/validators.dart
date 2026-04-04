/// Validates a redirect URI string.
/// Accepts https://, http:// (localhost only), and custom schemes (e.g. myapp://).
/// Returns null if valid, or an error message string.
String? validateRedirectUri(String uri) {
  uri = uri.trim();
  if (uri.isEmpty) return null; // empty is ok, will be filtered

  final parsed = Uri.tryParse(uri);
  if (parsed == null) return 'Invalid URI format';
  if (!parsed.hasScheme || parsed.scheme.isEmpty) {
    return 'Must have a scheme (e.g. https:// or myapp://)';
  }

  // For http, only allow localhost
  if (parsed.scheme == 'http' && parsed.host != 'localhost' && parsed.host != '127.0.0.1') {
    return 'HTTP is only allowed for localhost';
  }

  return null;
}

/// Validates a list of comma-separated redirect URIs.
/// Returns null if all valid, or the first error.
String? validateRedirectUris(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final uris = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
  for (final uri in uris) {
    final err = validateRedirectUri(uri);
    if (err != null) return '$err: "$uri"';
  }
  return null;
}

/// Validates grant types (comma-separated).
String? validateGrantTypes(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  const valid = {
    'authorization_code',
    'client_credentials',
    'refresh_token',
    'implicit',
  };

  final types = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
  for (final t in types) {
    if (!valid.contains(t)) {
      return 'Invalid grant type: "$t". Valid: ${valid.join(", ")}';
    }
  }
  return null;
}

/// Validates response types (comma-separated).
String? validateResponseTypes(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  const valid = {'code', 'token', 'id_token'};

  final types = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
  for (final t in types) {
    if (!valid.contains(t)) {
      return 'Invalid response type: "$t". Valid: ${valid.join(", ")}';
    }
  }
  return null;
}

/// Validates a client name.
String? validateClientName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Client name is required';
  if (value.trim().length < 2) return 'At least 2 characters';
  return null;
}

/// Validates OAuth2 scopes (space-separated).
String? validateScopes(String? value) {
  if (value == null || value.trim().isEmpty) return 'At least one scope is required';
  return null;
}

/// Splits a comma-separated string into a trimmed, non-empty list.
List<String>? splitCommaSeparated(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
