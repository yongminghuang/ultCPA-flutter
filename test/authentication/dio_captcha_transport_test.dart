import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/authentication/dio_captcha_transport.dart';

void main() {
  test('posts JSON to the real test host with signed headers', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final transport = DioCaptchaTransport(
      dio: dio,
      baseUrl: 'https://ult-test.xmzhujing.com',
      headers: () async => {
        'X-sign': 'signed',
        'X-category': 'social-work',
        'Authorization': 'expired-token',
      },
    );

    final result = await transport.post('/app/captcha/aj/get', {
      'captchaType': 'blockPuzzle',
    });

    expect(
      adapter.request?.uri.toString(),
      'https://ult-test.xmzhujing.com/app/captcha/aj/get',
    );
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.headers['X-sign'], 'signed');
    expect(adapter.request?.headers['Authorization'], 'expired-token');
    expect(adapter.request?.data, {'captchaType': 'blockPuzzle'});
    expect(result['repCode'], '0000');
  });
}

final class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'repCode': '0000', 'repData': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
