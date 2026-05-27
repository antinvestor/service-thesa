/// On web, derive the redirect URI from the browser's current origin
/// so login works regardless of which host/port serves the app.
String resolveWebRedirectUri(String fallback) {
  final base = Uri.base;
  return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}/auth/callback';
}
