import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/customer_service/customer_service_data_source.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';

void main() {
  test('requests the exact signed Android customer URL endpoint', () async {
    final api = _Api((path, queryParameters) async {
      expect(path, '/app/v2/getWxCustomerUrl');
      expect(queryParameters, isNull);
      return 'https://service.example/customer?a=1&b=2';
    });
    final source = AppApiCustomerServiceDataSource(api: api);

    final url = await source.loadUrl();

    expect(url, 'https://service.example/customer?a=1&b=2');
    expect(api.getCalls, 1);
    expect(api.postCalls, 0);
  });

  test('preserves null, empty, and whitespace string bodies', () async {
    for (final body in <Object?>[null, '', '   ']) {
      final source = AppApiCustomerServiceDataSource(
        api: _Api((_, _) async => body),
      );

      expect(await source.loadUrl(), body, reason: 'body=$body');
    }
  });

  test('rejects non-string customer URL bodies', () async {
    for (final body in <Object?>[
      1,
      true,
      const <Object?>[],
      const <String, Object?>{'url': 'https://invalid.example'},
    ]) {
      final source = AppApiCustomerServiceDataSource(
        api: _Api((_, _) async => body),
      );

      await expectLater(
        source.loadUrl(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '客服链接解析失败',
          ),
        ),
        reason: 'body=$body',
      );
    }
  });

  test('does not hide remote request failures', () async {
    final source = AppApiCustomerServiceDataSource(
      api: _Api((_, _) => throw const AppApiException('服务不可用', code: 503)),
    );

    await expectLater(
      source.loadUrl(),
      throwsA(
        isA<AppApiException>()
            .having((error) => error.code, 'code', 503)
            .having((error) => error.message, 'message', '服务不可用'),
      ),
    );
  });
}

typedef _GetHandler =
    FutureOr<Object?> Function(
      String path,
      Map<String, dynamic>? queryParameters,
    );

final class _Api implements AppApiClient {
  _Api(this.handler);

  final _GetHandler handler;
  int getCalls = 0;
  int postCalls = 0;

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls += 1;
    return handler(path, queryParameters);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    postCalls += 1;
    throw StateError('unexpected POST $path');
  }
}
