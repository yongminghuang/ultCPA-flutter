import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/customer_service/customer_service_data_source.dart';
import 'package:ultcpa_flutter/src/customer_service/customer_service_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    MethodChannelCustomerServiceGateway.channelName,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the exact Mine actions MethodChannel contract', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await MethodChannelCustomerServiceGateway().launch(
      'https://service.example/customer?a=1&b=2',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'openCustomerServiceMiniProgram');
    expect(calls.single.arguments, {
      'url': 'https://service.example/customer?a=1&b=2',
    });
  });

  test('launches a non-empty remote URL without rewriting it', () async {
    final gateway = _Gateway();
    final coordinator = CustomerServiceCoordinator(
      dataSource: _Source.value('  https://service.example/a b?x=1&y=2  '),
      gateway: gateway,
    );

    await coordinator.open();

    expect(gateway.urls, ['  https://service.example/a b?x=1&y=2  ']);
  });

  test('uses the fixed Android fallback for unusable remote results', () async {
    expect(
      customerServiceFallbackUrl,
      'https://work.weixin.qq.com/u/vcd963cf9c328b1b9f?src=wx&bb=a184893e4e',
    );
    final sources = <CustomerServiceDataSource>[
      _Source.value(null),
      _Source.value(''),
      _Source.error(StateError('offline')),
      _Source.error(const FormatException('客服链接解析失败')),
    ];

    for (final source in sources) {
      final gateway = _Gateway();
      await CustomerServiceCoordinator(
        dataSource: source,
        gateway: gateway,
      ).open();

      expect(gateway.urls, [customerServiceFallbackUrl], reason: '$source');
    }
  });

  test('does not hide a platform launch failure', () async {
    final coordinator = CustomerServiceCoordinator(
      dataSource: _Source.value('https://service.example/customer'),
      gateway: _Gateway(error: StateError('wechat unavailable')),
    );

    await expectLater(coordinator.open(), throwsStateError);
  });
}

final class _Source implements CustomerServiceDataSource {
  const _Source.value(this.value) : error = null;

  const _Source.error(this.error) : value = null;

  final String? value;
  final Object? error;

  @override
  Future<String?> loadUrl() async {
    if (error != null) throw error!;
    return value;
  }
}

final class _Gateway implements CustomerServiceMiniProgramGateway {
  _Gateway({this.error});

  final Object? error;
  final List<String> urls = [];

  @override
  Future<void> launch(String h5Url) async {
    urls.add(h5Url);
    if (error != null) throw error!;
  }
}
