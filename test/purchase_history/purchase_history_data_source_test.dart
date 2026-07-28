import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_data_source.dart';

void main() {
  test('gets the exact signed Android order-history request', () async {
    final adapter = _Adapter([
      {
        'code': 200,
        'body': [_order('newest', '2026-05-10 12:00:00')],
      },
    ]);
    final repository = DioPurchaseHistoryRepository(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com/',
      headers: () async => {'X-sign': 'signed', 'Authorization': 'old-token'},
    );

    final orders = await repository.loadOrders();

    expect(orders.single.orderId, 'newest');
    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/app/order/v1/getMyOrder');
    expect(request.queryParameters, isEmpty);
    expect(request.data, isNull);
    expect(request.headers['X-sign'], 'signed');
    expect(request.headers['Authorization'], 'old-token');
    expect(request.contentType, Headers.jsonContentType);
  });

  test('accepts only the three Android order success codes', () async {
    final adapter = _Adapter([
      {'code': 0, 'body': null},
      {'code': '200', 'body': []},
      {'code': 2001, 'body': []},
    ]);
    final repository = DioPurchaseHistoryRepository(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    expect(await repository.loadOrders(), isEmpty);
    expect(await repository.loadOrders(), isEmpty);
    expect(await repository.loadOrders(), isEmpty);
    expect(adapter.requests, hasLength(3));
  });

  test(
    'decodes a string array, filters nulls, and sorts newest first',
    () async {
      final adapter = _Adapter([
        {
          'code': 200,
          'body': jsonEncode([
            _order('older', '2026-05-09 12:00:00'),
            null,
            _order('newer', '2026-05-10 12:00:00'),
          ]),
        },
      ]);
      final repository = DioPurchaseHistoryRepository(
        dio: Dio()..httpClientAdapter = adapter,
        apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
        headers: () async => const {},
      );

      final orders = await repository.loadOrders();

      expect(orders.map((order) => order.orderId), ['newer', 'older']);
    },
  );

  test('throws the server message for an unsuccessful envelope', () async {
    final repository = DioPurchaseHistoryRepository(
      dio: Dio()
        ..httpClientAdapter = _Adapter([
          {'code': 409, 'msg': '订单查询失败', 'body': null},
        ]),
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await expectLater(
      repository.loadOrders(),
      throwsA(
        isA<AppApiException>()
            .having((error) => error.code, 'code', 409)
            .having((error) => error.message, 'message', '订单查询失败'),
      ),
    );
  });

  test('rejects malformed envelopes, arrays, and order entries', () async {
    final adapter = _RawAdapter([
      '[]',
      jsonEncode({
        'code': 200,
        'body': {'orderId': 'not-a-list'},
      }),
      jsonEncode({
        'code': 200,
        'body': [true],
      }),
    ]);
    final repository = DioPurchaseHistoryRepository(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => const {},
    );

    await expectLater(repository.loadOrders(), throwsFormatException);
    await expectLater(repository.loadOrders(), throwsFormatException);
    await expectLater(repository.loadOrders(), throwsFormatException);
  });
}

Map<String, Object?> _order(String id, String payTime) {
  return {
    'orderId': id,
    'commodityName': id,
    'orderAmount': 99.0,
    'payTime': payTime,
    'orderStatus': '支付成功',
    'benefitsExpireTime': '2026-08-10 12:00:00',
    'items': const [],
  };
}

final class _Adapter extends _RawAdapter {
  _Adapter(List<Map<String, dynamic>> responses)
    : super(responses.map(jsonEncode).toList());
}

class _RawAdapter implements HttpClientAdapter {
  _RawAdapter(this.responses);

  final List<String> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      responses.removeAt(0),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
