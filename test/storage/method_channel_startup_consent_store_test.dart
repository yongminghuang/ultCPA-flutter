import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/startup/method_channel_startup_consent_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelStartupConsentStore.channelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads the Android App MMKV agreement flag', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'hasAcceptedPrivacy');
          return true;
        });

    final store = MethodChannelStartupConsentStore();

    expect(await store.hasAcceptedPrivacy(), isTrue);
  });

  test('writes acceptance through the Android legacy bridge', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'acceptPrivacy');
          called = true;
          return null;
        });

    await MethodChannelStartupConsentStore().acceptPrivacy();

    expect(called, isTrue);
  });
}
