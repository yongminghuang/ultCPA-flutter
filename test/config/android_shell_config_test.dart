import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts');
  final activity = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt',
  );
  final settings = File('android/settings.gradle.kts');
  final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties');
  final pubspec = File('pubspec.yaml');
  final runConfiguration = File('.idea/runConfigurations/main_dart.xml');
  final localProperties = File('android/local.properties');

  test('locks Android identity and SDK bounds', () {
    final source = gradle.readAsStringSync();
    expect(source, contains('namespace = "com.xmzj.ult.agg"'));
    expect(source, contains('applicationId = "com.xmzj.ult.agg"'));
    expect(source, contains('compileSdk = 34'));
    expect(source, contains('minSdk = 21'));
    expect(source, contains('targetSdk = 34'));
    expect(source, contains('versionCode = 26071018'));
    expect(source, contains('versionName = "1.2.5"'));
    expect(activity.readAsStringSync(), contains('package com.xmzj.ult.agg'));
  });

  test('locks the unique channel matrix and labels', () {
    final source = gradle.readAsStringSync();
    const channels = <String>[
      'dev',
      'dev_prod',
      'douyin',
      'honor',
      'oppo',
      'vivo',
      'mi',
      'qihoo',
      'baidu',
      'tencent',
      'aliapp',
      'lenovo',
      'huawei',
      'meizu',
      'qnm',
      'kuaishou',
    ];
    for (final channel in channels) {
      expect(source, contains('"$channel"'));
    }
    expect(source, contains('if (channelName == "dev_prod") "dev"'));
    expect(source, contains('ULTCPA_CHANNEL'));
  });

  test('requires external legacy release signing values', () {
    final source = gradle.readAsStringSync();
    for (final name in <String>[
      'ULTCPA_KEYSTORE_PATH',
      'ULTCPA_KEYSTORE_PASSWORD',
      'ULTCPA_KEY_ALIAS',
      'ULTCPA_KEY_PASSWORD',
    ]) {
      expect(source, contains(name));
    }
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('pins the Flutter 3.32 Android 21-compatible toolchain', () {
    expect(
      settings.readAsStringSync(),
      allOf(contains('version "8.7.3"'), contains('version "2.1.0"')),
    );
    expect(wrapper.readAsStringSync(), contains('gradle-8.12-all.zip'));
    expect(
      wrapper.readAsStringSync(),
      contains(
        '7ebdac923867a3cec0098302416d1e3c6c0c729fc4e2e05c10637a8af33a76c5',
      ),
    );
    expect(pubspec.readAsStringSync(), contains("sdk: '>=3.8.0 <4.0.0'"));
  });

  test('Android Studio runs only the dev flavor with Flutter 3.32.8', () {
    final runSource = runConfiguration.readAsStringSync();
    expect(runSource, contains('name="buildFlavor" value="dev"'));
    expect(
      localProperties.readAsStringSync(),
      contains(r'flutter.sdk=E:\\soft\\flutter\\flutter_3.32.8_sdk\\flutter'),
    );
  });
}
