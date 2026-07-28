import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_safety/account_deactivation_gateway.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';

void main() {
  test('posts the exact signed Android deactivation request', () async {
    final adapter = _Adapter([
      {'code': 200, 'body': true},
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = DioAccountDeactivationGateway(
      dio: dio,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com/',
      headers: () async => {'X-sign': 'signed', 'Authorization': 'old-token'},
    );

    await gateway.deactivate();

    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/app/user/deactivate');
    expect(request.data, '');
    expect(request.headers['X-sign'], 'signed');
    expect(request.headers['Authorization'], 'old-token');
    expect(request.contentType, Headers.jsonContentType);
  });

  test('accepts both Android success envelope codes', () async {
    final adapter = _Adapter([
      {'code': 200, 'body': true},
      {'code': '2001', 'body': null},
    ]);
    final gateway = DioAccountDeactivationGateway(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await gateway.deactivate();
    await gateway.deactivate();

    expect(adapter.requests, hasLength(2));
  });

  test('throws the server message without weakening a failure', () async {
    final gateway = DioAccountDeactivationGateway(
      dio: Dio()
        ..httpClientAdapter = _Adapter([
          {'code': 409, 'msg': '账号注销失败，请稍后重试', 'body': null},
        ]),
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await expectLater(
      gateway.deactivate(),
      throwsA(
        isA<AppApiException>()
            .having((error) => error.code, 'code', 409)
            .having((error) => error.message, 'message', '账号注销失败，请稍后重试'),
      ),
    );
  });

  test('rejects a non-object response envelope', () async {
    final gateway = DioAccountDeactivationGateway(
      dio: Dio()..httpClientAdapter = _RawAdapter('[]'),
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await expectLater(gateway.deactivate(), throwsFormatException);
  });
}

final class _Adapter extends _RawAdapter {
  _Adapter(List<Map<String, dynamic>> responses)
    : _responses = responses,
      super('');

  final List<Map<String, dynamic>> _responses;

  @override
  String takeResponse() => jsonEncode(_responses.removeAt(0));
}

class _RawAdapter implements HttpClientAdapter {
  _RawAdapter(this._response);

  final String _response;
  final List<RequestOptions> requests = [];

  String takeResponse() => _response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      takeResponse(),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
