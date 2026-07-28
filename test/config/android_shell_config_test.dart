import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts');
  final activity = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt',
  );
  final legacyBridge = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
  );
  final settingsBridge = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/SettingsBridge.kt',
  );
  final accountSafetyBridge = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/AccountSafetyBridge.kt',
  );
  final mineActionsBridge = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/MineActionsBridge.kt',
  );
  final vipPaymentBridge = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/VipPaymentBridge.kt',
  );
  final wxPayEntryActivity = File(
    'android/app/src/main/kotlin/com/xmzj/ult/agg/wxapi/'
    'WXPayEntryActivity.kt',
  );
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final preExamSixPaperPaths = File(
    'android/app/src/main/res/xml/pre_exam_six_paper_file_paths.xml',
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
    expect(source, contains('compileSdk = 35'));
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

  test('bridges the legacy App MMKV privacy flag', () {
    final gradleSource = gradle.readAsStringSync();
    final activitySource = activity.readAsStringSync();
    expect(gradleSource, contains('com.tencent:mmkv-static:1.2.8'));
    expect(activitySource, contains('MMKV.mmkvWithID("App")'));
    expect(activitySource, contains('"setAgreeRule"'));
    expect(activitySource, contains('"hasAcceptedPrivacy"'));
    expect(activitySource, contains('"acceptPrivacy"'));
  });

  test('exports the persisted mnemonic free count to Flutter', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();
    expect(
      bridge,
      contains(
        '"skillFormulaFreeCount" to appKv.decodeInt('
        '"skill_formula_free_question_count", 3)',
      ),
    );
  });

  test('exports the persisted practice free count to Flutter', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();
    expect(
      bridge,
      contains(
        '"skillQuestionFreeCount" to appKv.decodeInt('
        '"skill_question_free_count", 5)',
      ),
    );
  });

  test('bridges collect-book and Mine referral snapshot fields', () {
    final source = legacyBridge.readAsStringSync();

    expect(
      source,
      contains(
        'appKv.encode("collect_book_h5_url", text("collect_book_h5_url"))',
      ),
    );
    expect(source, contains('"collectBookH5Url"'));
    expect(source, contains('appKv.decodeString("collect_book_h5_url", "")'));
    expect(source, contains('"accessToken"'));
    expect(source, contains('dataKv.decodeString("key_sp_authorization", "")'));
    expect(source, contains('"userRole"'));
    expect(source, contains('dataKv.decodeString("key_sp_user_role", "")'));
    expect(source, contains('"commissionRate"'));
    expect(
      source,
      contains('dataKv.decodeString("key_sp_commission_rate", "")'),
    );
    expect(
      source,
      contains('"isTestEnvironment" to (BuildConfig.FLAVOR == "dev")'),
    );
    expect(source, contains('"persistMineReferralProfile"'));
    expect(source, contains('dataKv.encode("key_sp_user_role", userRole)'));
    expect(
      source,
      contains('dataKv.encode("key_sp_commission_rate", commissionRate)'),
    );
  });

  test('exports Android VIP purchase snapshot configuration', () {
    final source = legacyBridge.readAsStringSync();

    expect(source, contains('"categoryBodyJson"'));
    expect(source, contains('"accounting_category_body_json"'));
    expect(source, contains('"showWxPay"'));
    expect(source, contains('appKv.decodeBool("showWxPay", true)'));
    expect(source, contains('"defaultPayType"'));
    expect(source, contains('preferences.getInt('));
    expect(source, contains('"module_loginandpay_default_pay"'));
    expect(source, contains('"userBenefitsJson"'));
    expect(source, contains('dataKv.decodeString('));
    expect(source, contains('"key_mmkv_user_benefits_json"'));
  });

  test(
    'exports chapter preview count and Android-compatible progress keys',
    () {
      final bridge = File(
        'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
      ).readAsStringSync();
      expect(
        bridge,
        contains(
          '"chapterQuestionFreeCount" to appKv.decodeInt('
          '"chapter_question_free_count", 2)',
        ),
      );
      expect(bridge, contains('"getChapterPracticeExpandedCatalog"'));
      expect(bridge, contains('"setChapterPracticeExpandedCatalog"'));
      expect(bridge, contains('"getChapterPracticeQuestionPosition"'));
      expect(bridge, contains('"setChapterPracticeQuestionPosition"'));
      expect(
        bridge,
        contains(
          '\${legacyUserId()}_\${currentCategory()}_\${moduleId}'
          '_chapter_practice_list_expanded_catalog',
        ),
      );
      expect(
        bridge,
        contains(
          '\${legacyUserId()}_\${currentCategory()}_\${moduleId}_'
          '\${catalogIndex}_\${chapterIndex}_learnQPos',
        ),
      );
    },
  );

  test('bridges Android-compatible flat practice question positions', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();

    expect(bridge, contains('"getFlatPracticeQuestionPosition"'));
    expect(bridge, contains('"setFlatPracticeQuestionPosition"'));
    expect(
      bridge,
      contains(
        '\${legacyUserId()}_\${currentCategory()}_\${shelfId}'
        '_flatLearnQPos',
      ),
    );
  });

  test('bridges legacy teacher-course index and seek progress keys', () {
    final bridge = legacyBridge.readAsStringSync();

    expect(bridge, contains('"readTeacherCourseIndex"'));
    expect(bridge, contains('"writeTeacherCourseIndex"'));
    expect(bridge, contains('"readTeacherCoursePosition"'));
    expect(bridge, contains('"writeTeacherCoursePosition"'));
    expect(bridge, contains('"teacher_course_play_index_\$subject"'));
    expect(bridge, contains('"seekbarnow\$mediaId"'));
  });

  test('bridges Android-compatible daily skill JSON stores', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();

    expect(bridge, contains('"readDailySkillProgressJson"'));
    expect(bridge, contains('"writeDailySkillProgressJson"'));
    expect(bridge, contains('"readDailySkillCheckInJson"'));
    expect(bridge, contains('"writeDailySkillCheckInJson"'));
    expect(
      bridge,
      contains(
        '"daily_skill_progress_\${legacyDailySkillUserId()}_'
        '\${currentCategory()}"',
      ),
    );
    expect(
      bridge,
      contains(
        '"daily_skill_checkin_\${legacyDailySkillUserId()}_'
        '\${currentCategory()}"',
      ),
    );
    expect(bridge, contains('legacyUserId().ifBlank { "0" }'));
  });

  test('confines pre-exam six-paper downloads and shares cache files', () {
    final bridge = legacyBridge.readAsStringSync();

    expect(bridge, contains('"createPreExamSixPaperDownloadPath"'));
    expect(bridge, contains('"sharePreExamSixPaperFile"'));
    expect(bridge, contains('context.externalCacheDir ?: context.cacheDir'));
    expect(bridge, contains('leaf.name == fileName'));
    expect(bridge, contains('canonicalFile'));
    expect(bridge, contains('file.parentFile == directory'));
    expect(bridge, contains('file.exists() && file.isFile'));
    expect(bridge, contains('file.toPath().startsWith(root.toPath())'));
    expect(bridge, contains('"\${context.packageName}.fileprovider"'));
    expect(bridge, contains('Intent.ACTION_SEND'));
    expect(bridge, contains('Intent.FLAG_GRANT_READ_URI_PERMISSION'));
  });

  test('declares a read-only FileProvider for both cache locations', () {
    final manifestSource = manifest.readAsStringSync();

    expect(
      manifestSource,
      contains('android:name="androidx.core.content.FileProvider"'),
    );
    expect(
      manifestSource,
      contains('android:authorities="\${applicationId}.fileprovider"'),
    );
    expect(manifestSource, contains('android:exported="false"'));
    expect(manifestSource, contains('android:grantUriPermissions="true"'));
    expect(
      manifestSource,
      contains('android:resource="@xml/pre_exam_six_paper_file_paths"'),
    );

    expect(preExamSixPaperPaths.existsSync(), isTrue);
    final pathsSource = preExamSixPaperPaths.readAsStringSync();
    expect(pathsSource, contains('<cache-path'));
    expect(pathsSource, contains('<external-cache-path'));
    expect(pathsSource, contains('path="pre_exam_six_paper/"'));
  });

  test('builds signed headers and encrypted hardware login natively', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();
    expect(bridge, contains('"appCategoryNameMappingJson"'));
    expect(bridge, contains('"app_category_name_mapping"'));
    expect(bridge, contains('"buildRequestHeaders"'));
    expect(bridge, contains('"buildDeviceLoginBody"'));
    expect(bridge, contains('SHA256withRSA'));
    expect(bridge, contains('AES/GCM/NoPadding'));
    expect(bridge, contains('RSA/ECB/PKCS1Padding'));
    expect(bridge, contains('"X-sign"'));
    expect(bridge, contains('"X-Device-ID"'));
    expect(bridge, contains('BuildConfig.FLAVOR == "dev"'));
    expect(bridge, contains('maxPlaintextBlock'));
  });

  test('persists the Android-compatible phone login profile', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt',
    ).readAsStringSync();
    expect(bridge, contains('"persistPhoneSession"'));
    expect(bridge, contains('"key_sp_mobile"'));
    expect(bridge, contains('"key_sp_islogin"'));
    expect(bridge, contains('"last_login_dx"'));
    expect(bridge, contains('.putInt("isTemp", tempStatus)'));
  });

  test('bridges Android-compatible settings and platform actions', () {
    expect(settingsBridge.existsSync(), isTrue);
    final source = settingsBridge.readAsStringSync();
    final activitySource = activity.readAsStringSync();

    expect(source, contains('com.xmzj.ult.agg/settings'));
    expect(source, contains('MMKV.mmkvWithID("User")'));
    expect(source, contains('"NotificationEnabled"'));
    expect(source, contains('MMKV.mmkvWithID("ad")'));
    expect(source, contains('"setIndividuation"'));
    for (final method in <String>[
      'readSettings',
      'setNotificationEnabled',
      'setPersonalizedRecommendations',
      'clearCaches',
      'openStoreRating',
      'openExternalUrl',
    ]) {
      expect(source, contains('"$method"'));
    }
    expect(source, contains('File(context.cacheDir, "ACache")'));
    expect(source, contains('WebView(context)'));
    expect(source, contains('WebStorage.getInstance().deleteAllData()'));
    expect(source, contains('market://details?id='));
    expect(source, contains('https://play.google.com/store/apps/details?id='));
    expect(source, contains('scheme == "http" || scheme == "https"'));
    expect(
      activitySource,
      contains('SettingsBridge(this).register(flutterEngine)'),
    );
  });

  test('bridges account safety and clears the deactivated legacy session', () {
    expect(accountSafetyBridge.existsSync(), isTrue);
    final source = accountSafetyBridge.readAsStringSync();
    final activitySource = activity.readAsStringSync();

    expect(source, contains('com.xmzj.ult.agg/account_safety'));
    expect(source, contains('MMKV.mmkvWithID("mmkvLazy")'));
    expect(source, contains('MMKV.mmkvWithID("User")'));
    expect(source, contains('"readAccountSafety"'));
    expect(source, contains('"clearDeactivatedSession"'));
    for (final key in <String>[
      'key_sp_authorization',
      'key_sp_mobile',
      'key_sp_nickname',
      'key_sp_facepath',
      'key_sp_islogin',
      'key_sp_is_vip',
      'key_mmkv_user_benefits_json',
      'key_mmkv_static_ad_vip_close',
      'key_mmkv_static_login_history_info',
      'key_sp_last_login_type',
    ]) {
      expect(source, contains('"$key"'));
    }
    expect(source, contains('userKv.encode("LogOut", true)'));
    expect(source, contains('.putString("userIdString", "")'));
    expect(source, contains('.putInt("isTemp", 1)'));
    expect(source, contains('.commit()'));
    expect(
      activitySource,
      contains('AccountSafetyBridge(this).register(flutterEngine)'),
    );
  });

  test('bridges the read-only profile and hardened normal sign out', () {
    expect(accountSafetyBridge.existsSync(), isTrue);
    final source = accountSafetyBridge.readAsStringSync();

    expect(source, contains('"readAccountProfile"'));
    expect(source, contains('"clearSignedOutSession"'));
    for (final field in <String>[
      '"isLoggedIn"',
      '"userId"',
      '"nickname"',
      '"avatar"',
    ]) {
      expect(source, contains(field));
    }
    expect(source, contains('dataKv.decodeBool("key_sp_islogin", false)'));
    expect(
      source,
      contains('preferences.getString("userIdString", "").orEmpty()'),
    );
    expect(
      source,
      contains('dataKv.decodeString("key_sp_nickname", "").orEmpty()'),
    );
    expect(
      source,
      contains('dataKv.decodeString("key_sp_facepath", "").orEmpty()'),
    );
    expect(source, contains('private fun clearSignedOutSession()'));
    expect(source, contains('clearLegacyAccountSession()'));
  });

  test('bridges Mine customer service to the exact WeChat mini program', () {
    final gradleSource = gradle.readAsStringSync();
    final manifestSource = manifest.readAsStringSync();
    final activitySource = activity.readAsStringSync();

    expect(mineActionsBridge.existsSync(), isTrue);
    if (!mineActionsBridge.existsSync()) return;
    final source = mineActionsBridge.readAsStringSync();

    expect(source, contains('com.xmzj.ult.agg/mine_actions'));
    expect(source, contains('"openCustomerServiceMiniProgram"'));
    expect(source, contains('call.argument<String>("url")'));
    expect(source, contains('require(h5Url.isNotEmpty())'));
    expect(source, contains('"wx8d51616821867104"'));
    expect(source, contains('userName = "gh_61681409b61c"'));
    expect(source, contains('pages/mine/customer-qr-page?url='));
    expect(source, contains('Uri.encode(h5Url)'));
    expect(source, contains('BuildConfig.FLAVOR == "dev"'));
    expect(source, contains('MINIPROGRAM_TYPE_PREVIEW'));
    expect(source, contains('MINIPTOGRAM_TYPE_RELEASE'));
    expect(source, contains('api.isWXAppInstalled'));
    expect(source, contains('"wechat_not_installed"'));
    expect(source, contains('api.sendReq(request)'));
    expect(source, contains('"wechat_launch_failed"'));
    expect(
      activitySource,
      contains('MineActionsBridge(this).register(flutterEngine)'),
    );
    expect(
      gradleSource,
      contains('com.tencent.mm.opensdk:wechat-sdk-android:6.8.30'),
    );
    expect(
      manifestSource,
      contains('<package android:name="com.tencent.mm" />'),
    );
  });

  test('bridges one in-flight native WeChat or Alipay VIP payment', () {
    final gradleSource = gradle.readAsStringSync();
    final activitySource = activity.readAsStringSync();
    final manifestSource = manifest.readAsStringSync();

    expect(
      gradleSource,
      contains('com.tencent.mm.opensdk:wechat-sdk-android:6.8.30'),
    );
    expect(
      gradleSource,
      contains('com.alipay.sdk:alipaysdk-android:15.8.42@aar'),
    );
    expect(vipPaymentBridge.existsSync(), isTrue);
    expect(wxPayEntryActivity.existsSync(), isTrue);
    if (!vipPaymentBridge.existsSync() || !wxPayEntryActivity.existsSync()) {
      return;
    }

    final bridge = vipPaymentBridge.readAsStringSync();
    final callback = wxPayEntryActivity.readAsStringSync();
    expect(
      activitySource,
      contains('VipPaymentBridge(this).register(flutterEngine)'),
    );
    expect(bridge, contains('com.xmzj.ult.agg/vip_payment'));
    expect(bridge, contains('wx8d51616821867104'));
    for (final method in <String>[
      'isWechatInstalled',
      'payWechat',
      'payAlipay',
    ]) {
      expect(bridge, contains('"$method"'));
    }
    expect(bridge, contains('api.isWXAppInstalled'));
    expect(bridge, contains('WXAPIFactory.createWXAPI'));
    for (final field in <String>[
      'appId',
      'partnerId',
      'prepayId',
      'nonceStr',
      'timeStamp',
      'packageValue',
      'sign',
    ]) {
      expect(bridge, contains('request.$field'));
    }
    expect(bridge, contains('pendingWechatResult'));
    expect(bridge, contains('alipayInFlight'));
    expect(bridge, contains('Executors.newSingleThreadExecutor()'));
    expect(bridge, contains('PayTask(activity)'));
    expect(bridge, contains('payV2(orderInfo.trim(), true)'));
    for (final status in <String>['9000', '6001', '4000']) {
      expect(bridge, contains('"$status"'));
    }

    expect(callback, contains('package com.xmzj.ult.agg.wxapi'));
    expect(callback, contains('IWXAPIEventHandler'));
    expect(callback, contains('api.handleIntent'));
    expect(callback, contains('VipPaymentBridge.completeWechatPayment'));
    expect(callback, contains('BaseResp.ErrCode.ERR_OK'));
    expect(callback, contains('BaseResp.ErrCode.ERR_USER_CANCEL'));
    expect(
      manifestSource,
      contains('android:name=".wxapi.WXPayEntryActivity"'),
    );
    expect(manifestSource, contains('android:exported="true"'));
    expect(manifestSource, contains('android:launchMode="singleTop"'));
    expect(
      manifestSource,
      contains('<package android:name="com.tencent.mm" />'),
    );
  });

  test('confines Mine app updates and exports the exact build channel', () {
    final bridge = legacyBridge.readAsStringSync();
    final source = mineActionsBridge.readAsStringSync();
    final manifestSource = manifest.readAsStringSync();
    final pathsSource = preExamSixPaperPaths.readAsStringSync();

    expect(bridge, contains('"appChannel" to BuildConfig.ULTCPA_CHANNEL'));
    expect(bridge, contains('"persistAppUpdateCheckTimestamp"'));
    expect(bridge, contains('call.argument<Number>("millis")'));
    expect(bridge, contains('require(millis > 0L)'));
    expect(
      bridge,
      contains('"lastProactiveVersionCheckAt" to appKv.decodeLong'),
    );
    expect(
      bridge,
      contains('appKv.encode(LAST_PROACTIVE_VERSION_CHECK_AT, millis)'),
    );
    expect(
      bridge,
      contains(
        'LAST_PROACTIVE_VERSION_CHECK_AT = '
        '"key_mmkv_last_proactive_version_check_at"',
      ),
    );
    expect(source, contains('"createAppUpdateDownloadPath"'));
    expect(source, contains('"installAppUpdateApk"'));
    expect(source, contains('"openAppUpdateUrl"'));
    expect(source, contains('"openApplicationMarket"'));
    expect(source, contains('getExternalFilesDir(APP_UPDATE_DIRECTORY)'));
    expect(source, contains('canonicalFile'));
    expect(source, contains('file.parentFile == directory'));
    expect(source, contains('file.exists() && file.isFile'));
    expect(source, contains('file.extension.equals("apk", ignoreCase = true)'));
    expect(source, contains('FileProvider.getUriForFile'));
    expect(source, contains('Intent.FLAG_GRANT_READ_URI_PERMISSION'));
    expect(source, contains('"market://details?id="'));
    expect(source, contains('"http://a.app.qq.com/o/simple.jsp?pkgname="'));
    expect(
      manifestSource,
      contains('android.permission.REQUEST_INSTALL_PACKAGES'),
    );
    expect(pathsSource, contains('<external-files-path'));
    expect(pathsSource, contains('name="app_update_external"'));
    expect(pathsSource, contains('path="update/"'));
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
