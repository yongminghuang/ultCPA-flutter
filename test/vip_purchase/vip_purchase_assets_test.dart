import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const assetNames = <String>[
    'vip_open_accounting_layer_36.png',
    'vip_open_accounting_layer_25.png',
    'vip_open_accounting_asset_7cb1f20d.png',
    'vip_open_accounting_asset_c18dffb6.png',
    'vip_open_accounting_group_14.png',
    'vip_open_accounting_group_14_v2.png',
    'vip_open_accounting_layer_28.png',
    'ic_promotion_add_customer_service.png',
    'ic_default_avatar.png',
    'icon_vip_wx.png',
    'icon_vip_zfb.png',
    'ic_vip_privilege_doc.png',
    'ic_vip_privilege_practice.png',
    'ic_vip_privilege_lock.png',
    'ic_vip_privilege_real.png',
    'ic_vip_privilege_chapter.png',
    'ic_vip_privilege_card.png',
    'ic_vip_privilege_video.png',
    'ic_vip_privilege_folder.png',
    'ic_vip_privilege_expert.png',
    'icon_open_vip_success.png',
  ];

  test('declares the Android VIP purchase asset directory', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/images/vip_purchase/'),
    );
  });

  test('copies every authoritative Android bitmap with nonzero bytes', () {
    for (final name in assetNames) {
      final file = File('assets/images/vip_purchase/$name');
      expect(file.existsSync(), isTrue, reason: name);
      if (file.existsSync()) {
        expect(file.lengthSync(), greaterThan(0), reason: name);
      }
    }
  });
}
