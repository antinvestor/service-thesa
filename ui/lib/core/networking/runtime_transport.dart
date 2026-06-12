import 'dart:async';
import 'dart:typed_data';

import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/protobuf.dart' as connect_protobuf;
import 'package:connectrpc/protocol/connect.dart' as connect_protocol;

/// Connect RPC `Transport` that delegates every unary call through
/// `AuthRuntime.fetch`.
///
/// The runtime owns the access token and never surfaces it to callers;
/// this transport adapts Connect's `HttpClient` typedef onto
/// `runtime.fetch` so generated service clients and Connect protocol
/// framing (envelope, codec, error mapping) stay unchanged while auth +
/// transport headers come from the runtime.
///
/// ## Per-service domains preserved
///
/// Thesa's RPC clients live on distinct per-service base URLs — profile,
/// tenancy, device, payment, … — resolved by [ApiConfig]. Each Riverpod
/// transport provider constructs a dedicated [RuntimeTransport] pinned
/// to that service's base URL. For every RPC the transport builds
/// `${baseUrl}${path}` and hands the full absolute URL to
/// `runtime.fetch`; runtime v0.3.1+ detects absolute URLs (scheme
/// `http`/`https`) and skips its own `apiBaseUrl` concatenation, so the
/// per-service routing survives end-to-end.
///
/// ## Streaming
///
/// `runtime.fetch` is a unary HTTP call that buffers the full response
/// body. Server-streaming RPCs (e.g. `ListTenant`) still work through
/// it: the client sends a single enveloped request message and the
/// Connect protocol parser consumes every buffered response frame —
/// messages just arrive all at once instead of incrementally.
/// Client-streaming and bidi RPCs genuinely need incremental request
/// bodies and throw [UnimplementedError].
class RuntimeTransport implements connect.Transport {
  RuntimeTransport({
    required AuthRuntime runtime,
    required Uri baseUrl,
    List<connect.Interceptor>? interceptors,
    Duration? timeout,
  }) : _runtime = runtime,
       _baseUrl = baseUrl,
       _timeout = timeout,
       _delegate = connect_protocol.Transport(
         baseUrl: baseUrl.toString(),
         codec: const connect_protobuf.ProtoCodec(),
         httpClient: _buildHttpClient(runtime, baseUrl, timeout),
         interceptors: interceptors,
       );

  final AuthRuntime _runtime;
  // ignore: unused_field
  final Uri _baseUrl;
  // ignore: unused_field
  final Duration? _timeout;
  final connect.Transport _delegate;

  /// Exposed so consumers can verify the runtime they wired up. Kept
  /// internal to the package; not used by Connect itself.
  AuthRuntime get runtime => _runtime;

  @override
  Future<connect.UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    connect.Spec<I, O> spec,
    I input, [
    connect.CallOptions? options,
  ]) {
    return _delegate.unary(spec, input, options);
  }

  @override
  Future<connect.StreamResponse<I, O>> stream<
    I extends Object,
    O extends Object
  >(connect.Spec<I, O> spec, Stream<I> input, [connect.CallOptions? options]) {
    if (spec.streamType != connect.StreamType.server) {
      throw UnimplementedError(
        'RuntimeTransport does not support ${spec.streamType.name} streaming '
        'RPCs (procedure: ${spec.procedure}): runtime.fetch buffers the '
        'request body, so only unary and server-streaming calls work.',
      );
    }
    return _delegate.stream(spec, input, options);
  }

  /// Adapter from Connect's [connect.HttpClient] typedef onto
  /// [AuthRuntime.fetch].
  ///
  /// Connect builds the request URL as `baseUrl + spec.procedure`. We
  /// pass the resulting absolute URL straight to the runtime; runtime
  /// v0.3.1+ detects `http://` / `https://` prefixes and skips its own
  /// `apiBaseUrl` concatenation, preserving thesa's per-service
  /// domains. Headers, body bytes, and the abort signal flow through
  /// verbatim. The runtime adds `Authorization` (and `DPoP` when bound)
  /// on top.
  static connect.HttpClient _buildHttpClient(
    AuthRuntime runtime,
    Uri baseUrl,
    Duration? timeout,
  ) {
    return (connect.HttpRequest req) async {
      final body = await _collectBody(req.body);
      final headersMap = <String, String>{};
      for (final h in req.header.entries) {
        headersMap[h.name] = h.value;
      }
      final absoluteUrl = _absoluteUrl(baseUrl, req.url);

      Future<ApiResponse> call() => runtime.fetch(
        absoluteUrl,
        method: req.method,
        headers: headersMap.isEmpty ? null : headersMap,
        body: body,
        timeout: timeout,
      );

      final ApiResponse res;
      final signal = req.signal;
      if (signal == null) {
        res = await call();
      } else {
        final completer = Completer<ApiResponse>();
        unawaited(
          signal.future.then((err) {
            if (!completer.isCompleted) completer.completeError(err);
          }),
        );
        unawaited(
          call().then(
            (value) {
              if (!completer.isCompleted) completer.complete(value);
            },
            onError: (Object err, StackTrace st) {
              if (!completer.isCompleted) completer.completeError(err, st);
            },
          ),
        );
        res = await completer.future;
      }

      // The underlying HTTP client transparently decompresses gzip
      // responses but leaves `content-encoding: gzip` (and the original
      // `content-length`) on the headers. If we forward those, the Connect
      // protocol parser sees `content-encoding: gzip` and tries to
      // decompress the already-plain body, failing with "unsupported
      // response encoding gzip" — which broke every unary RPC whose
      // response was large enough for the server to gzip (tenant/partition
      // detail, etc.). Drop those headers, mirroring connectrpc's own io
      // transport. Web is unaffected (the browser strips them already).
      final gzipped = res.headers.entries.any((e) =>
          e.key.toLowerCase() == 'content-encoding' &&
          e.value.toLowerCase().contains('gzip'));
      final responseHeaders = connect.Headers();
      res.headers.forEach((name, value) {
        final lower = name.toLowerCase();
        if (gzipped &&
            (lower == 'content-encoding' || lower == 'content-length')) {
          return;
        }
        responseHeaders.add(name, value);
      });

      return connect.HttpResponse(
        res.status,
        responseHeaders,
        Stream<Uint8List>.value(res.body),
        connect.Headers(),
      );
    };
  }

  /// Rebuilds the request URL as absolute so `runtime.fetch` bypasses
  /// its own `apiBaseUrl` prepending. Connect already produces an
  /// absolute URL (`baseUrl + spec.procedure`) when it calls the
  /// httpClient; we resolve against [baseUrl] defensively to tolerate
  /// path-only inputs.
  static String _absoluteUrl(Uri baseUrl, String reqUrl) {
    final parsed = Uri.parse(reqUrl);
    if (parsed.hasScheme) return parsed.toString();
    return baseUrl.resolveUri(parsed).toString();
  }

  static Future<Uint8List> _collectBody(Stream<Uint8List>? body) async {
    if (body == null) return Uint8List(0);
    final chunks = <Uint8List>[];
    var total = 0;
    await for (final chunk in body) {
      chunks.add(chunk);
      total += chunk.length;
    }
    if (chunks.length == 1) return chunks.first;
    final out = Uint8List(total);
    var offset = 0;
    for (final c in chunks) {
      out.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    return out;
  }
}

/// Builds a Connect [TransportFactory] that routes every RPC through
/// `AuthRuntime.fetch` via [RuntimeTransport]. Consumed by the
/// antinvestor_api_common client factories (`newClient`, `newFooClient`)
/// which expect a `(Uri, List<Interceptor>) -> Transport` function.
connect.Transport Function(Uri, List<connect.Interceptor>)
createRuntimeTransportFactory(AuthRuntime runtime) {
  return (Uri baseUrl, List<connect.Interceptor> interceptors) {
    return RuntimeTransport(
      runtime: runtime,
      baseUrl: baseUrl,
      interceptors: interceptors,
    );
  };
}
