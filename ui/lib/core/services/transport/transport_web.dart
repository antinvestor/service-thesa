import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/protobuf.dart' as connect_protobuf;
import 'package:connectrpc/protocol/connect.dart' as connect_protocol;
import 'package:connectrpc/web.dart' as connect_web;

import 'transport.dart';

CreateTransportFn createTransportFactory() {
  return (Uri baseUrl, List<connect.Interceptor> interceptors) {
    return connect_protocol.Transport(
      baseUrl: baseUrl.toString(),
      codec: const connect_protobuf.ProtoCodec(),
      httpClient: connect_web.createHttpClient(),
      interceptors: interceptors,
    );
  };
}
