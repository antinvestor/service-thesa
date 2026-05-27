/// On non-web platforms, fall back to the localhost loopback used by
/// flutter_appauth for desktop OAuth callbacks.
String resolveWebRedirectUri(String fallback) => fallback;
