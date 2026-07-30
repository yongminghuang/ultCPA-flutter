import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_share_gateway.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_models.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_page.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_repository.dart';

void main() {
  testWidgets('renders poster actions, edits profile, and sends invite link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        home: PromotionSharingPage(
          inviteContent: 'invite-8',
          dataSource: _Source(),
          shareGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('推广分享'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('promotion-share-friend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('promotion-share-moments')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('promotion-save-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('promotion-send-link')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('promotion-edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('promotion-name-input')),
      '新老师',
    );
    await tester.enterText(
      find.byKey(const ValueKey('promotion-phone-input')),
      '13900139000',
    );
    await tester.tap(find.byKey(const ValueKey('promotion-profile-save')));
    await tester.pumpAndSettle();
    expect(gateway.savedProfile?.name, '新老师');
    expect(find.text('新老师'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('promotion-send-link')));
    await tester.pump();
    expect(gateway.sharedUrl, 'https://example.com/invite?inviteCode=user-8');
    expect(gateway.sharedTimeline, isFalse);
  });
}

final class _Source implements PromotionSharingDataSource {
  @override
  Future<PromotionSharingSession> load(String inviteContent) async {
    return PromotionSharingSession(
      inviteUrl: 'https://example.com/invite?inviteCode=user-8',
      profile: const PromotionProfile(name: '老师', phone: '13800138000'),
      posters: const [],
    );
  }
}

final class _Gateway implements PromotionShareGateway {
  PromotionProfile? savedProfile;
  String? sharedUrl;
  bool? sharedTimeline;

  @override
  Future<Uint8List> createQrCode(String content, {int size = 360}) async {
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<PromotionProfile> readProfile(PromotionProfile fallback) async {
    return fallback;
  }

  @override
  Future<void> saveImage(Uint8List pngBytes) async {}

  @override
  Future<void> saveProfile(PromotionProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<void> shareWechatImage(
    Uint8List pngBytes, {
    required bool timeline,
  }) async {}

  @override
  Future<void> shareWechatWebpage({
    required String url,
    required String title,
    required String description,
    required bool timeline,
  }) async {
    sharedUrl = url;
    sharedTimeline = timeline;
  }
}
