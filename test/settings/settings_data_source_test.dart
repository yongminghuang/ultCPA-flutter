import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/settings/settings_data_source.dart';
import 'package:ultcpa_flutter/src/settings/settings_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelSettingsDataSource.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the exact Android settings channel contract', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'readSettings') {
            return {
              'notificationEnabled': true,
              'personalizedRecommendations': false,
            };
          }
          return null;
        });
    final source = MethodChannelSettingsDataSource();

    final snapshot = await source.load();
    await source.setNotificationEnabled(false);
    await source.setPersonalizedRecommendations(true);
    await source.clearCaches();
    await source.openStoreRating();
    await source.openExternalUrl(Uri.parse('https://beian.miit.gov.cn'));

    expect(
      snapshot,
      const SettingsSnapshot(
        notificationEnabled: true,
        personalizedRecommendations: false,
      ),
    );
    expect(calls.map((call) => call.method), [
      'readSettings',
      'setNotificationEnabled',
      'setPersonalizedRecommendations',
      'clearCaches',
      'openStoreRating',
      'openExternalUrl',
    ]);
    expect(calls[1].arguments, {'enabled': false});
    expect(calls[2].arguments, {'enabled': true});
    expect(calls[3].arguments, isNull);
    expect(calls[4].arguments, isNull);
    expect(calls[5].arguments, {'url': 'https://beian.miit.gov.cn'});
  });

  test('rejects malformed native snapshots', () async {
    for (final value in <Object?>[
      null,
      const <String, Object?>{},
      const {'notificationEnabled': 1, 'personalizedRecommendations': true},
      const {'notificationEnabled': true, 'personalizedRecommendations': 'yes'},
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => value);

      await expectLater(
        MethodChannelSettingsDataSource().load(),
        throwsFormatException,
        reason: '$value',
      );
    }
  });

  test(
    'allows only http and https external URLs without platform I/O',
    () async {
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            callCount += 1;
            return null;
          });
      final source = MethodChannelSettingsDataSource();

      for (final raw in [
        'mailto:test@example.com',
        'javascript:alert(1)',
        'file:///tmp/private',
        'https:',
      ]) {
        await expectLater(
          source.openExternalUrl(Uri.parse(raw)),
          throwsArgumentError,
          reason: raw,
        );
      }
      expect(callCount, 0);
    },
  );
}
