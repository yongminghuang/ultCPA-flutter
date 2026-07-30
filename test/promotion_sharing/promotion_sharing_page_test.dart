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

    expect(find.text('VIP推广赚钱'), findsOneWidget);
    expect(find.text('修改招生信息'), findsOneWidget);
    expect(find.text('更换推广图片'), findsOneWidget);
    expect(find.text('分享微信好友'), findsOneWidget);
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
    expect(find.text('修改招生信息'), findsOneWidget);
    expect(find.text('注:仅用于二维码海报的显示，不会修改你的资料'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('promotion-name-row')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('promotion-name-input')),
      '新老师',
    );
    await tester.tap(find.byKey(const ValueKey('promotion-profile-save')));
    await tester.pumpAndSettle();
    expect(gateway.savedProfile?.name, '新老师');
    expect(find.text('新老师'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('promotion-send-link')));
    await tester.pump();
    expect(gateway.sharedUrl, 'https://example.com/invite?inviteCode=user-8');
    expect(gateway.sharedTimeline, isFalse);
  });

  testWidgets('opens Android poster grid and persists the selected poster', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const posters = [
      PromotionPoster(
        id: 'poster-1',
        templateUrl: 'https://example.com/poster-1.png',
        sampleUrl: 'https://example.com/poster-1-small.png',
        showStatus: true,
      ),
      PromotionPoster(
        id: 'poster-2',
        templateUrl: 'https://example.com/poster-2.png',
        sampleUrl: 'https://example.com/poster-2-small.png',
        showStatus: true,
      ),
    ];
    final gateway = _Gateway()
      ..selectedPreference = const PromotionPosterPreference(
        posterId: 'poster-1',
        templateUrl: 'https://example.com/poster-1.png',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: PromotionSharingPage(
          inviteContent: 'invite-8',
          dataSource: _Source(posters: posters),
          shareGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('promotion-change-poster')));
    await tester.pumpAndSettle();

    expect(find.text('推广图片'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('promotion-poster-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('promotion-poster-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('promotion-poster-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('promotion-poster-1')));
    await tester.pumpAndSettle();

    expect(find.text('VIP推广赚钱'), findsOneWidget);
    expect(gateway.savedPoster?.id, 'poster-2');
  });
}

final class _Source implements PromotionSharingDataSource {
  _Source({this.posters = const []});

  final List<PromotionPoster> posters;

  @override
  Future<PromotionSharingSession> load(String inviteContent) async {
    return PromotionSharingSession(
      inviteUrl: 'https://example.com/invite?inviteCode=user-8',
      profile: const PromotionProfile(name: '老师', phone: '13800138000'),
      posters: posters,
    );
  }

  @override
  Future<List<PromotionPoster>> loadPosters() async => posters;
}

final class _Gateway implements PromotionShareGateway {
  PromotionProfile? savedProfile;
  PromotionPoster? savedPoster;
  PromotionPosterPreference? selectedPreference;
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
  Future<PromotionPosterPreference?> readSelectedPoster() async {
    return selectedPreference;
  }

  @override
  Future<void> saveImage(Uint8List pngBytes) async {}

  @override
  Future<void> saveProfile(PromotionProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<void> saveSelectedPoster(PromotionPoster poster) async {
    savedPoster = poster;
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
