import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/method_channel_request_context.dart';
import 'package:ultcpa_flutter/src/practice/practice_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelRequestContext.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads signed Android request headers', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'buildRequestHeaders');
          return {'X-sign': 'signed', 'X-Device-ID': 'v2:encrypted'};
        });

    final headers = await MethodChannelRequestContext().headers();

    expect(headers['X-sign'], 'signed');
    expect(headers['X-Device-ID'], 'v2:encrypted');
  });

  test('reads the encrypted hardware login body', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'buildDeviceLoginBody');
          return {'params': 'rsa-ciphertext', 'timestamp': '123'};
        });

    final body = await MethodChannelRequestContext().deviceLoginBody();

    expect(body, {'params': 'rsa-ciphertext', 'timestamp': '123'});
  });

  test('persists the returned session in legacy Android stores', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'persistSession');
          expect(call.arguments, {
            'accessToken': 'access-token',
            'userId': '2038529229062426626',
          });
          return null;
        });

    await MethodChannelRequestContext().persistSession(
      accessToken: 'access-token',
      userId: '2038529229062426626',
    );
  });

  test('reads the API environment selected by the Android flavor', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getApiBaseUrl');
          return 'https://ult-test.xmzhujing.com';
        });

    expect(
      await MethodChannelRequestContext().apiBaseUrl(),
      'https://ult-test.xmzhujing.com',
    );
  });

  test('persists the complete legacy phone-login profile', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'persistPhoneSession');
          expect(call.arguments, {
            'accessToken': 'phone-token',
            'user': {
              'id': '2038529229062426626',
              'phone': '13800138000',
              'nickName': '考友',
            },
          });
          return null;
        });

    await MethodChannelRequestContext().persistPhoneSession(
      accessToken: 'phone-token',
      user: {
        'id': '2038529229062426626',
        'phone': '13800138000',
        'nickName': '考友',
      },
    );
  });

  test(
    'persists startup dictionary values without changing their text',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'persistStaticConfiguration');
            expect(call.arguments, {
              'values': {
                'exam_time': '{"social-work":[]}',
                'invite_fission_activity': '1',
              },
            });
            return null;
          });

      await MethodChannelRequestContext().persistStaticConfiguration({
        'exam_time': '{"social-work":[]}',
        'invite_fission_activity': '1',
      });
    },
  );

  test('persists refreshed Mine referral fields in legacy MMKV', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'persistMineReferralProfile');
          expect(call.arguments, {
            'userRole': 'creator,teacher',
            'commissionRate': '0.25',
          });
          return null;
        });

    await MethodChannelRequestContext().persistMineReferralProfile(
      userRole: 'creator,teacher',
      commissionRate: '0.25',
    );
  });

  test('reads a precision-safe legacy app snapshot', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readAppSnapshot');
          return {
            'category': 'social-work',
            'userId': '2038529229062426626',
            'selectedMarketId': 1023,
            'lastProactiveVersionCheckAt': 1784246400000,
            'categoryBodyJson': '{"social-work":[]}',
            'showWxPay': false,
            'defaultPayType': 2,
            'userBenefitsJson': '[]',
          };
        });

    final snapshot = await MethodChannelRequestContext().readAppSnapshot();

    expect(snapshot['userId'], '2038529229062426626');
    expect(snapshot['selectedMarketId'], 1023);
    expect(snapshot['lastProactiveVersionCheckAt'], 1784246400000);
    expect(snapshot['categoryBodyJson'], '{"social-work":[]}');
    expect(snapshot['showWxPay'], isFalse);
    expect(snapshot['defaultPayType'], 2);
    expect(snapshot['userBenefitsJson'], '[]');
  });

  test('persists the shared app-update throttle timestamp', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'persistAppUpdateCheckTimestamp');
          expect(call.arguments, {'millis': 1784246400000});
          return null;
        });

    await MethodChannelRequestContext().persistAppUpdateCheckTimestamp(
      1784246400000,
    );
  });

  test(
    'persists the selected category and subject in legacy App MMKV',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'persistCategorySelection');
            expect(call.arguments, {
              'categoryBodyJson': '{"social-work":[]}',
              'category': 'social-work',
              'selectedCategory': {
                'id': 1016,
                'level': '初级社工',
                'children': <Object>[],
              },
              'selectedCategoryKey': 'social-work_1016',
              'marketId': 1023,
              'subject': '社工实务',
            });
            return null;
          });

      await MethodChannelRequestContext().persistCategorySelection(
        categoryBodyJson: '{"social-work":[]}',
        category: 'social-work',
        selectedCategory: {'id': 1016, 'level': '初级社工', 'children': <Object>[]},
        selectedCategoryKey: 'social-work_1016',
        marketId: 1023,
        subject: '社工实务',
      );
    },
  );

  test('reads and writes the legacy wrong-removal threshold', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'getWrongRemovalThreshold' ? 3 : null;
        });
    final context = MethodChannelRequestContext();

    expect(await context.loadWrongRemovalThreshold(), 3);
    await context.saveWrongRemovalThreshold(-1);

    expect(calls.map((call) => call.method), [
      'getWrongRemovalThreshold',
      'setWrongRemovalThreshold',
    ]);
    expect(calls.last.arguments, {'threshold': -1});
  });

  test(
    'records a correct error-review answer by its legacy count id',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'recordWrongQuestionCorrect');
            expect(call.arguments, {'questionId': '314'});
            return true;
          });

      expect(
        await MethodChannelRequestContext().recordWrongQuestionCorrect('314'),
        isTrue,
      );
    },
  );

  test('reads and writes Android-compatible practice settings', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getPracticeSettings') {
            return {
              'autoNext': false,
              'playCorrectSound': true,
              'explainWrongAutomatically': false,
              'fontSize': 2,
              'themeMode': 1,
            };
          }
          return null;
        });
    final context = MethodChannelRequestContext();

    final settings = await context.loadPracticeSettings();
    expect(settings.autoNext, isFalse);
    expect(settings.playCorrectSound, isTrue);
    expect(settings.explainWrongAutomatically, isFalse);
    expect(settings.fontSize, PracticeFontSize.extraLarge);
    expect(settings.themeMode, PracticeThemeMode.eyeCare);

    await context.savePracticeSettings(
      settings.copyWith(
        autoNext: true,
        fontSize: PracticeFontSize.small,
        themeMode: PracticeThemeMode.night,
      ),
    );

    expect(calls.map((call) => call.method), [
      'getPracticeSettings',
      'setPracticeSettings',
    ]);
    expect(calls.last.arguments, {
      'autoNext': true,
      'playCorrectSound': true,
      'explainWrongAutomatically': false,
      'fontSize': -1,
      'themeMode': 2,
    });
  });
}
