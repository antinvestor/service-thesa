import 'package:connectrpc/connect.dart' as connect;

export 'transport_stub.dart'
    if (dart.library.io) 'transport_io.dart'
    if (dart.library.js_interop) 'transport_web.dart';

typedef CreateTransportFn = connect.Transport Function(
  Uri baseUrl,
  List<connect.Interceptor> interceptors,
);
