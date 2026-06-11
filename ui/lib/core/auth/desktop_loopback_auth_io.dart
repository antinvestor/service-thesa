import 'dart:io';

// The loopback server implementation is not re-exported through the
// package's conditional public surface, so reach into the src/ path.
// This file itself is only compiled on dart:io platforms.
// ignore: implementation_imports
import 'package:flutter_web_auth_2/src/server.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

/// Routes desktop OAuth through the system browser + localhost loopback
/// server instead of the embedded `desktop_webview_window` webview.
///
/// The embedded webview spawns a second Flutter engine inside the same
/// process for its title bar, which intermittently deadlocks on Linux
/// before the window maps — the auth window never appears and login hangs.
/// The loopback variant (`FlutterWebAuth2ServerPlugin`) avoids the second
/// engine entirely: it binds the redirect port, opens the system browser,
/// and captures the callback request.
///
/// Only takes effect on Linux/Windows when [redirectUri] is a localhost
/// loopback; other platforms keep their native ASWebAuthenticationSession /
/// Custom Tabs flows.
void configureDesktopLoopbackAuth(String redirectUri) {
  if (!Platform.isLinux && !Platform.isWindows) {
    return;
  }
  final uri = Uri.tryParse(redirectUri);
  if (uri == null ||
      uri.scheme != 'http' ||
      (uri.host != 'localhost' && uri.host != '127.0.0.1') ||
      !uri.hasPort) {
    return;
  }
  FlutterWebAuth2Platform.instance =
      _LoopbackServerAuth('http://${uri.host}:${uri.port}');
}

/// Wraps [FlutterWebAuth2ServerPlugin], substituting the full loopback
/// origin the server plugin expects. The auth runtime hands
/// `flutter_web_auth_2` only the redirect scheme (`http`), which the
/// server plugin rejects — it needs `http://localhost:{port}` to know
/// which port to bind.
class _LoopbackServerAuth extends FlutterWebAuth2Platform {
  _LoopbackServerAuth(this._callbackOrigin);

  final String _callbackOrigin;
  final FlutterWebAuth2ServerPlugin _server = FlutterWebAuth2ServerPlugin();

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) =>
      _server.authenticate(
        url: url,
        callbackUrlScheme: _callbackOrigin,
        options: options,
      );

  @override
  Future<void> clearAllDanglingCalls() => _server.clearAllDanglingCalls();
}
