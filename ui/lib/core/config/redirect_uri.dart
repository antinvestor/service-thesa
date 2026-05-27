import 'redirect_uri_stub.dart'
    if (dart.library.js_interop) 'redirect_uri_web.dart';

/// Resolves the OAuth redirect URI for the current platform.
///
/// On web, uses the browser's origin so login works on any host/port.
/// On desktop/mobile, returns [fallback] (the loopback URI for
/// flutter_appauth).
String resolveRedirectUri(String fallback) => resolveWebRedirectUri(fallback);
