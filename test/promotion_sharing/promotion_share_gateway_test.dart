import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_share_gateway.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the native QR profile image and webpage channel contract',
    () async {
      const channel = MethodChannel(
        MethodChannelPromotionShareGateway.channelName,
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'readPromotionProfile' => {
                'name': '自定义姓名',
                'phone': '13900139000',
              },
              'createPromotionQrCode' => Uint8List.fromList([1, 2, 3]),
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final gateway = MethodChannelPromotionShareGateway(channel: channel);

      final profile = await gateway.readProfile(
        const PromotionProfile(name: '默认', phone: '13800138000'),
      );
      await gateway.saveProfile(profile);
      expect(await gateway.createQrCode('https://example.com'), [1, 2, 3]);
      await gateway.shareWechatImage(
        Uint8List.fromList([8, 9]),
        timeline: true,
      );
      await gateway.shareWechatWebpage(
        url: 'https://example.com/share',
        title: '标题',
        description: '摘要',
        timeline: false,
      );
      await gateway.saveImage(Uint8List.fromList([6, 7]));

      expect(profile.name, '自定义姓名');
      expect(calls.map((call) => call.method), [
        'readPromotionProfile',
        'savePromotionProfile',
        'createPromotionQrCode',
        'shareWechatImage',
        'shareWechatWebpage',
        'savePromotionImage',
      ]);
      expect((calls[3].arguments as Map<Object?, Object?>)['timeline'], isTrue);
      expect(
        (calls[4].arguments as Map<Object?, Object?>)['url'],
        'https://example.com/share',
      );
    },
  );
}
