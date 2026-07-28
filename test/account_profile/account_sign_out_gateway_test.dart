import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_sign_out_gateway.dart';

void main() {
  test('dispatches the exact signed Android logout request', () async {
    final adapter = _RecordingAdapter.immediate();
    final gateway = DioAccountSignOutGateway(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com/',
      headers: () async => {'X-sign': 'signed', 'Authorization': 'old-token'},
    );

    await gateway.dispatch();
    await _waitFor(() => adapter.requests.isNotEmpty);

    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/app/user/v1/logout');
    expect(request.data, '');
    expect(request.headers['X-sign'], 'signed');
    expect(request.headers['Authorization'], 'old-token');
    expect(request.contentType, Headers.jsonContentType);
  });

  test(
    'returns after dispatch without waiting for the server response',
    () async {
      final adapter = _RecordingAdapter.pending();
      final gateway = DioAccountSignOutGateway(
        dio: Dio()..httpClientAdapter = adapter,
        apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
        headers: () async => const {},
      );

      await gateway.dispatch().timeout(const Duration(milliseconds: 250));
      await _waitFor(() => adapter.requests.isNotEmpty);

      expect(adapter.responseCompleter!.isCompleted, isFalse);
      adapter.responseCompleter!.complete(
        ResponseBody.fromString('{"code":500}', 500),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('surfaces request-context failure before dispatch', () async {
    final adapter = _RecordingAdapter.immediate();
    final gateway = DioAccountSignOutGateway(
      dio: Dio()..httpClientAdapter = adapter,
      apiBaseUrl: () async => 'https://ult-test.xmzhujing.com',
      headers: () async => throw StateError('headers unavailable'),
    );

    await expectLater(gateway.dispatch(), throwsStateError);

    expect(adapter.requests, isEmpty);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition did not become true');
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter.immediate() : responseCompleter = null;

  _RecordingAdapter.pending() : responseCompleter = Completer<ResponseBody>();

  final Completer<ResponseBody>? responseCompleter;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final pending = responseCompleter;
    if (pending != null) return pending.future;
    return ResponseBody.fromString(
      '{"code":200}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
