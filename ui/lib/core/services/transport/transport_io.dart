import 'dart:io' as io;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/io.dart' as connect_io;
import 'package:connectrpc/protobuf.dart' as connect_protobuf;
import 'package:connectrpc/protocol/connect.dart' as connect_protocol;

import '../api_config.dart';
import 'transport.dart';

CreateTransportFn createTransportFactory() {
  return (Uri baseUrl, List<connect.Interceptor> interceptors) {
    final httpClient = io.HttpClient()
      ..connectionTimeout = ApiConfig.connectionTimeout
      ..idleTimeout = ApiConfig.idleTimeout
      ..maxConnectionsPerHost = 4
      ..autoUncompress = true;

    return connect_protocol.Transport(
      baseUrl: baseUrl.toString(),
      codec: const connect_protobuf.ProtoCodec(),
      httpClient: connect_io.createHttpClient(httpClient),
      interceptors: interceptors,
    );
  };
}
