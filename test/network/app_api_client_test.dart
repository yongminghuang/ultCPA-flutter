import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';

void main() {
  test(
    'sends signed GET and POST requests and returns the response body',
    () async {
      final adapter = _Adapter([
        {
          'code': 200,
          'body': <String, Object?>{'value': 1},
        },
        {
          'code': 2001,
          'body': <Object?>['course'],
        },
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioAppApiClient(
        dio: dio,
        apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
        headers: () async => {'X-sign': 'signed'},
      );

      final first = await client.getBody(
        '/knowledge/market/appCategory',
        queryParameters: {'marketType': '模块管理'},
      );
      final second = await client.postBody('/app/tempMedia/query', {
        'subject': '社工实务',
        'courseType': '大招密押',
        'level': '初级社工',
        'showOnHome': '0',
      });

      expect(first, {'value': 1});
      expect(second, ['course']);
      expect(adapter.requests[0].uri.path, '/knowledge/market/appCategory');
      expect(adapter.requests[0].uri.queryParameters['marketType'], '模块管理');
      expect(adapter.requests[0].headers['X-sign'], 'signed');
      expect(adapter.requests[1].method, 'POST');
      expect(adapter.requests[1].data, {
        'subject': '社工实务',
        'courseType': '大招密押',
        'level': '初级社工',
        'showOnHome': '0',
      });
    },
  );

  test('throws the server message for an unsuccessful envelope', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter([
        {'code': 500, 'msg': '分类加载失败', 'body': null},
      ]);
    final client = DioAppApiClient(
      dio: dio,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await expectLater(
      client.getBody('/knowledge/market/appCategory'),
      throwsA(
        isA<AppApiException>().having(
          (error) => error.message,
          'message',
          '分类加载失败',
        ),
      ),
    );
  });
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);

  final List<Map<String, dynamic>> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responses.removeAt(0)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
