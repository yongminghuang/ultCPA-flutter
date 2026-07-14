abstract final class AppIdentity {
  static const applicationId = 'com.xmzj.ult.agg';
  static const versionName = '1.2.5';
  static const versionCode = 26071018;
  static const minSdk = 21;

  static const devChannels = <String>['dev', 'dev_prod', 'douyin'];

  static const marketChannels = <String>[
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
  ];

  static const promotionChannels = <String>['douyin', 'kuaishou', 'baidu'];

  static String channelLabel(String channel) => switch (channel) {
    'dev_prod' => 'dev',
    'xiaomi_64' => 'mi',
    _ => channel,
  };
}
