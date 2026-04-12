import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openid_client/openid_client_io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_platform.dart';

AuthPlatform getAuthPlatform() => AuthPlatformIO();

class AuthPlatformIO implements AuthPlatform {
  static const int _authPort = 5173;
  static const Duration _authTimeout = Duration(minutes: 3);

  Client? _client;
  HttpServer? _callbackServer;

  @override
  Client? get client => _client;

  @override
  Future<void> initialize(String issuerUrl, String clientId) async {
    if (_client == null) {
      final issuer = await Issuer.discover(
        Uri.parse(issuerUrl),
      ).timeout(const Duration(seconds: 15));
      _client = Client(issuer, clientId);
    }
  }

  @override
  Future<TokenResponse?> authenticate(
    List<String> scopes, {
    List<String> audiences = const [],
  }) async {
    if (_client == null) throw StateError('Not initialized');

    await cancelAuthentication();

    final redirectUri = Uri.parse('http://localhost:$_authPort/auth/callback');

    final flow = Flow.authorizationCodeWithPKCE(
      _client!,
      additionalParameters: {
        if (audiences.isNotEmpty) 'audience': audiences.join(' '),
      },
    )
      ..scopes.addAll(scopes)
      ..redirectUri = redirectUri;

    final credential = await _authorizeDesktop(flow).timeout(
      _authTimeout,
      onTimeout: () {
        cancelAuthentication();
        throw TimeoutException('Authentication timed out');
      },
    );

    final tokenResponse = await credential.getTokenResponse().timeout(
      const Duration(seconds: 30),
    );

    if (tokenResponse.accessToken == null ||
        tokenResponse.accessToken!.isEmpty) {
      throw Exception('No access token in response');
    }

    await cancelAuthentication();
    return tokenResponse;
  }

  Future<Credential> _authorizeDesktop(Flow flow) async {
    final completer = Completer<Credential>();

    _callbackServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      flow.redirectUri.port,
    );

    _callbackServer!.listen((request) async {
      try {
        final error = request.uri.queryParameters['error'];
        if (error != null) {
          final desc =
              request.uri.queryParameters['error_description'] ?? error;
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Authentication error: $desc');
          await request.response.close();
          if (!completer.isCompleted) {
            completer.completeError(Exception('OAuth error: $desc'));
          }
          return;
        }

        final code = request.uri.queryParameters['code'];
        final state = request.uri.queryParameters['state'];

        if (code == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Missing authorization code');
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(_successHtml);
        await request.response.close();

        final credential = await flow.callback({
          'code': code,
          'state': ?state,
        });

        if (!completer.isCompleted) completer.complete(credential);
      } catch (e) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal error');
          await request.response.close();
        } catch (_) {}
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    final authUri = flow.authenticationUri;
    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) throw Exception('Could not launch authentication URL');

    return completer.future;
  }

  @override
  Future<void> cancelAuthentication() async {
    try {
      await _callbackServer?.close(force: true);
      _callbackServer = null;
    } catch (e) {
      debugPrint('Error closing auth server: $e');
    }
  }

  @override
  Future<TokenResponse?> getRedirectResult() async => null;

  static const String _successHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Authentication Complete</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex; justify-content: center; align-items: center;
      min-height: 100vh; margin: 0;
      background: linear-gradient(135deg, #0F172A 0%, #0284C7 100%);
      color: white;
    }
    .container { text-align: center; padding: 2rem;
      background: rgba(255,255,255,0.1); border-radius: 16px;
      backdrop-filter: blur(10px); }
    h1 { margin-bottom: 1rem; }
    p { opacity: 0.9; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Authentication Successful!</h1>
    <p>Returning to the admin console...</p>
    <p><small>You can close this window.</small></p>
  </div>
  <script>setTimeout(function() { window.close(); }, 1500);</script>
</body>
</html>
''';
}
