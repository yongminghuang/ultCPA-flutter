import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelVipPaymentGateway.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('checks whether the Android WeChat app is installed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isWechatInstalled');
          expect(call.arguments, isNull);
          return true;
        });

    expect(await MethodChannelVipPaymentGateway().isWechatInstalled(), isTrue);
  });

  test('sends every WeChat credential field without renaming', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'payWechat');
          expect(call.arguments, {
            'appId': 'wx-app',
            'partnerId': 'partner',
            'prepayId': 'prepay',
            'nonceStr': 'nonce',
            'timeStamp': '123456',
            'packageValue': 'Sign=WXPay',
            'sign': 'signature',
          });
          return {'status': 'success'};
        });

    final result = await MethodChannelVipPaymentGateway().payWechat(
      const VipWechatCredential(
        appId: 'wx-app',
        partnerId: 'partner',
        prepayId: 'prepay',
        nonceStr: 'nonce',
        timeStamp: '123456',
        packageValue: 'Sign=WXPay',
        sign: 'signature',
      ),
    );

    expect(result.status, VipNativePaymentStatus.success);
    expect(result.message, isEmpty);
  });

  test('sends the Alipay order string without modification', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'payAlipay');
          expect(call.arguments, {'orderInfo': 'partner=2088&amount=19.9'});
          return {'status': 'cancelled'};
        });

    final result = await MethodChannelVipPaymentGateway().payAlipay(
      'partner=2088&amount=19.9',
    );

    expect(result.status, VipNativePaymentStatus.cancelled);
    expect(result.message, isEmpty);
  });

  test('maps all native statuses and preserves failure messages', () async {
    for (final entry in <(Object?, VipNativePaymentStatus, String)>[
      ({'status': 'success'}, VipNativePaymentStatus.success, ''),
      ({'status': 'cancelled'}, VipNativePaymentStatus.cancelled, ''),
      (
        {'status': 'failed', 'message': '支付失败4000'},
        VipNativePaymentStatus.failed,
        '支付失败4000',
      ),
      (
        {'status': 'unavailable', 'message': '您没有安装微信'},
        VipNativePaymentStatus.unavailable,
        '您没有安装微信',
      ),
      (null, VipNativePaymentStatus.failed, '支付失败'),
      ('success', VipNativePaymentStatus.failed, '支付失败'),
      ({'status': 'unknown'}, VipNativePaymentStatus.failed, '支付失败'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => entry.$1);

      final result = await MethodChannelVipPaymentGateway().payAlipay('order');

      expect(result.status, entry.$2, reason: '${entry.$1}');
      expect(result.message, entry.$3, reason: '${entry.$1}');
    }
  });

  test('maps PlatformException to a typed failed result', () async {
    for (final message in <String?>['原生支付忙碌中', null]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'vip_payment', message: message);
          });

      final result = await MethodChannelVipPaymentGateway().payAlipay('order');

      expect(result.status, VipNativePaymentStatus.failed);
      expect(result.message, message ?? '支付失败');
    }
  });

  test('returns false when the installed-app check fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'wechat_check');
        });

    expect(await MethodChannelVipPaymentGateway().isWechatInstalled(), isFalse);
  });
}
