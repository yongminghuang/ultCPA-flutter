import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_models.dart';

void main() {
  test('returns latest only for an explicit false update flag', () {
    final result = parseAppUpdateCheckBody(const {
      'isUpdatePrompt': false,
    }, ossDomain: 'https://cdn.example.com');

    expect(result, isA<AppUpdateLatest>());
  });

  test('parses compatible scalar fields for an available forced update', () {
    final result = parseAppUpdateCheckBody(const {
      'isUpdatePrompt': '1',
      'isForceUpdates': 1,
      'version': 2.5,
      'updateDescription': 7,
      'url': '/release/ultCPA.APK?source=mine',
    }, ossDomain: 'https://cdn.example.com/root');

    final available = result as AppUpdateAvailable;
    expect(available.info.latestVersion, '2.5');
    expect(available.info.description, '7');
    expect(available.info.isForceUpdate, isTrue);
    expect(available.info.target, AppUpdateTarget.apkDownload);
    expect(
      available.info.downloadUrl,
      'https://cdn.example.com/root/release/ultCPA.APK?source=mine',
    );
  });

  test('rejects a missing or invalid update flag', () {
    for (final body in <Object?>[
      null,
      const <String, Object?>{},
      const {'isUpdatePrompt': 'sometimes'},
    ]) {
      expect(
        () => parseAppUpdateCheckBody(body, ossDomain: ''),
        throwsFormatException,
      );
    }
  });

  test('preserves Android update-target precedence', () {
    const cases = <(String, AppUpdateTarget)>[
      ('', AppUpdateTarget.applicationMarket),
      ('https://app.qq.com/detail/app.apk', AppUpdateTarget.externalUrl),
      ('https://fir.im/example', AppUpdateTarget.externalUrl),
      ('https://myapp.com/download', AppUpdateTarget.externalUrl),
      (
        'https://cdn.example.com/app.APK?from=mine',
        AppUpdateTarget.apkDownload,
      ),
      ('https://cdn.example.com/release', AppUpdateTarget.applicationMarket),
    ];

    for (final (url, target) in cases) {
      final info = AppUpdateInfo(
        latestVersion: '2.0.0',
        description: 'changes',
        isForceUpdate: false,
        rawUrl: url,
        ossDomain: '',
      );
      expect(info.target, target, reason: url);
    }
  });

  test('resolves APK URLs with Android OSS rules and fallback', () {
    expect(
      resolveAppUpdateDownloadUrl(
        'https://cdn.example.com/app.apk',
        ossDomain: 'https://ignored.example.com',
      ),
      'https://cdn.example.com/app.apk',
    );
    expect(
      resolveAppUpdateDownloadUrl(
        '/release/app.apk',
        ossDomain: 'https://cdn.example.com/root',
      ),
      'https://cdn.example.com/root/release/app.apk',
    );
    expect(
      resolveAppUpdateDownloadUrl('release/app.apk', ossDomain: ''),
      'https://file.xmzhujing.com/release/app.apk',
    );
  });
}
