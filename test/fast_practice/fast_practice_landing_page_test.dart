import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_landing_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  test('registers every authoritative Android landing bitmap', () {
    const names = <String>[
      'img_fast300_hero_title.png',
      'ic_fast_300.png',
      'ic_fast_80.png',
      'img_fast300_bubble.png',
      'ic_fast300_vs.png',
      'ic_fast300_feature_book.png',
      'ic_fast300_feature_medal.png',
      'ic_fast300_feature_lightning.png',
    ];
    for (final name in names) {
      expect(
        File('assets/images/fast_practice/$name').existsSync(),
        isTrue,
        reason: name,
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/fast_practice/'),
    );
  });

  testWidgets('renders Android hero comparison features and fixed CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FastPracticeLandingPage(module: _module)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fast-practice-hero')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('省时拿高分，直击考点，快速通关！'), findsOneWidget);
    expect(find.text('2000题'), findsOneWidget);
    expect(find.text('300题'), findsOneWidget);
    expect(find.text('刷1题顶5题'), findsOneWidget);
    expect(find.text('只刷必考真题'), findsOneWidget);
    expect(find.text('短期稳拿分'), findsOneWidget);
    expect(find.byKey(const ValueKey('fast-practice-unlock')), findsOneWidget);
    expect(find.text('立即领取速成300题'), findsOneWidget);

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toSet();
    expect(
      assetNames,
      containsAll(<String>{
        'assets/images/fast_practice/img_fast300_hero_title.png',
        'assets/images/fast_practice/ic_fast_300.png',
        'assets/images/fast_practice/ic_fast300_feature_book.png',
        'assets/images/fast_practice/ic_fast300_feature_medal.png',
        'assets/images/fast_practice/ic_fast300_feature_lightning.png',
      }),
    );
  });

  testWidgets('default CTA reports payment migration without unlocking', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FastPracticeLandingPage(module: _module)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.pump();

    expect(find.text('速成300题需解锁，会员与支付功能仍在迁移中'), findsOneWidget);
  });

  testWidgets('injected unlock callback replaces the pending CTA action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FastPracticeLandingPage(
          module: _module,
          onUnlock: () => calls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.pump();

    expect(calls, 1);
    expect(find.text('速成300题需解锁，会员与支付功能仍在迁移中'), findsNothing);
  });
}

const _module = HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: 'hot');
