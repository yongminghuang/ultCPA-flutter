import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/config/app_identity.dart';

void main() {
  test('preserves Android package and version identity', () {
    expect(AppIdentity.applicationId, 'com.xmzj.ult.agg');
    expect(AppIdentity.versionName, '1.2.5');
    expect(AppIdentity.versionCode, 26071018);
    expect(AppIdentity.minSdk, 21);
  });

  test('preserves unique configured channels and labels', () {
    expect(AppIdentity.devChannels, ['dev', 'dev_prod', 'douyin']);
    expect(AppIdentity.channelLabel('dev_prod'), 'dev');
    expect(AppIdentity.promotionChannels, ['douyin', 'kuaishou', 'baidu']);
    expect(
      AppIdentity.marketChannels.toSet().length,
      AppIdentity.marketChannels.length,
    );
    expect(AppIdentity.marketChannels, containsAll(<String>['qnm', 'huawei']));
  });
}
