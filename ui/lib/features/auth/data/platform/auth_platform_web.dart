import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:openid_client/openid_client.dart';
import 'package:web/web.dart' as web;

import 'auth_platform.dart';

AuthPlatform getAuthPlatform() => AuthPlatformWeb();

class AuthPlatformWeb implements AuthPlatform {
  static const String _stateKey = 'thesa_auth:state';
  static const String _codeVerifierKey = 'thesa_auth:code_verifier';
  static const String _timestampKey = 'thesa_auth:timestamp';
  static const Duration _stateExpiry = Duration(minutes: 10);

  Client? _client;

  @override
  Client? get client => _client;

  @override
  Future<void> initialize(String issuerUrl, String clientId) async {
    if (_client == null) {
      final issuer = await Issuer.discover(Uri.parse(issuerUrl));
      _client = Client(issuer, clientId);
    }
  }

  @override
  Future<TokenResponse?> authenticate(
    List<String> scopes, {
    List<String> audiences = const [],
  }) async {
    if (_client == null) throw StateError('Not initialized');

    _cleanupStaleState();

    final currentUri = Uri.parse(web.window.location.href);
    final redirectUri = Uri(
      scheme: currentUri.scheme,
      host: currentUri.host,
      port: currentUri.port,
      path: '/auth/callback',
    );

    final codeVerifier = _generateCodeVerifier();
    final flow = Flow.authorizationCodeWithPKCE(
      _client!,
      codeVerifier: codeVerifier,
      additionalParameters: {
        if (audiences.isNotEmpty) 'audience': audiences.join(' '),
      },
    )
      ..scopes.addAll(scopes)
      ..redirectUri = redirectUri;

    web.window.localStorage.setItem(_stateKey, flow.state);
    web.window.localStorage.setItem(_codeVerifierKey, codeVerifier);
    web.window.localStorage.setItem(
      _timestampKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    web.window.location.href = flow.authenticationUri.toString();
    return null; // Page redirects
  }

  @override
  Future<TokenResponse?> getRedirectResult() async {
    if (_client == null) return null;

    final uri = Uri.parse(web.window.location.href);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      _clearAuthState();
      _cleanUrl(uri);
      throw Exception(
          'Authentication failed: ${uri.queryParameters['error_description'] ?? error}');
    }

    if (code == null || state == null) return null;

    final storedState = web.window.localStorage.getItem(_stateKey);
    final storedCodeVerifier =
        web.window.localStorage.getItem(_codeVerifierKey);
    final storedTimestamp = web.window.localStorage.getItem(_timestampKey);

    if (storedState != state || storedCodeVerifier == null) {
      _clearAuthState();
      _cleanUrl(uri);
      return null;
    }

    if (storedTimestamp != null) {
      final ts = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(storedTimestamp) ?? 0);
      if (DateTime.now().difference(ts) > _stateExpiry) {
        _clearAuthState();
        _cleanUrl(uri);
        return null;
      }
    }

    try {
      _cleanUrl(uri);

      final redirectUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      );

      final flow = Flow.authorizationCodeWithPKCE(
        _client!,
        state: storedState,
        codeVerifier: storedCodeVerifier,
      )..redirectUri = redirectUri;

      final credential = await flow
          .callback({'code': code, 'state': state})
          .timeout(const Duration(seconds: 30));

      final tokenResponse = await credential
          .getTokenResponse()
          .timeout(const Duration(seconds: 30));

      _clearAuthState();
      return tokenResponse;
    } catch (e) {
      _clearAuthState();
      rethrow;
    }
  }

  @override
  Future<void> cancelAuthentication() async => _clearAuthState();

  void _cleanUrl(Uri uri) {
    final cleanUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: '/',
    );
    web.window.history.replaceState(null, '', cleanUri.toString());
  }

  void _clearAuthState() {
    web.window.localStorage.removeItem(_stateKey);
    web.window.localStorage.removeItem(_codeVerifierKey);
    web.window.localStorage.removeItem(_timestampKey);
  }

  void _cleanupStaleState() {
    final ts = web.window.localStorage.getItem(_timestampKey);
    if (ts != null) {
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(ts) ?? 0);
      if (DateTime.now().difference(timestamp) > _stateExpiry) {
        _clearAuthState();
      }
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }
}
