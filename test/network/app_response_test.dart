import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_response.dart';

void main() {
  test('resolves a successful object response', () {
    final result = AppResponse.resolve<Map<String, Object?>>(
      '{"code":200,"msg":"ok","body":{"name":"会员"}}',
      (body) => Map<String, Object?>.from(body! as Map),
    );
    expect(result, isA<AppSuccess<Map<String, Object?>>>());
    final success = result as AppSuccess<Map<String, Object?>>;
    expect(success.value['name'], '会员');
  });

  test('treats the legacy login code 2001 as success', () {
    final result = AppResponse.resolve<String>(
      '{"code":2001,"body":"access-token"}',
      (body) => body! as String,
    );

    expect((result as AppSuccess<String>).value, 'access-token');
  });

  test('keeps a 16-plus digit SKU id exact in a raw body list', () {
    final result = AppResponse.resolveList<Map<String, Object?>>(
      '{"code":200,"body":[{"productSkuId":9007199254740993}]}',
      (item) => Map<String, Object?>.from(item as Map),
    );
    final value = (result as AppSuccess<List<Map<String, Object?>>>).value;
    expect(value.single['productSkuId'], 9007199254740993);
    expect(value.single['productSkuId'], isA<int>());
  });

  test('returns the server message for a business failure', () {
    final result = AppResponse.resolve<Object?>(
      '{"code":500,"msg":"下单失败","body":null}',
      (body) => body,
    );
    expect(result, isA<AppFailure<Object?>>());
    final failure = result as AppFailure<Object?>;
    expect(failure.kind, AppFailureKind.business);
    expect(failure.message, '下单失败');
  });

  test('returns parse failure for malformed JSON', () {
    final result = AppResponse.resolve<Object?>('{', (body) => body);
    final failure = result as AppFailure<Object?>;
    expect(failure.kind, AppFailureKind.parse);
  });
}
