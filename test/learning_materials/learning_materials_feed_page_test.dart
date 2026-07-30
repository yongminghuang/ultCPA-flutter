import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_feed_page.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_models.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_navigation.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  testWidgets('paid card becomes a pay-jump card and does not charge twice', (
    tester,
  ) async {
    var paymentCalls = 0;
    final jumps = <String>[];
    final item = LearningMaterialsItem.fromMap({
      'id': 8,
      'type': '支付卡片',
      'title': '资料题包',
      'commodityId': 'goods-8',
      'payJumpPage': '速成300题',
      'isShow': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LearningMaterialsFeedPage(
          request: _request(item),
          dataSource: _Source(),
          onPayment: (_, paidItem, channel) async {
            paymentCalls += 1;
            expect(paidItem.commodityId, 'goods-8');
            expect(channel, LearningMaterialsPaymentChannel.wechat);
            return true;
          },
          onBannerTap: (_, jumpPage) async => jumps.add(jumpPage),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('learning-material-pay-submit')),
    );
    await tester.pump();
    expect(paymentCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('learning-material-pay-submit')),
    );
    await tester.pump();
    expect(paymentCalls, 1);
    expect(jumps, ['速成300题']);
  });

  testWidgets('an initially hidden pay card routes without invoking payment', (
    tester,
  ) async {
    var paymentCalls = 0;
    String? jump;
    final item = LearningMaterialsItem.fromMap({
      'id': 9,
      'type': '支付卡片',
      'commodityId': 'goods-9',
      'payJumpPage': '技巧卡片',
      'isShow': false,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LearningMaterialsFeedPage(
          request: _request(item),
          dataSource: _Source(),
          onPayment: (_, _, _) async {
            paymentCalls += 1;
            return true;
          },
          onBannerTap: (_, value) async => jump = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('learning-material-pay-submit')),
    );
    await tester.pump();
    expect(paymentCalls, 0);
    expect(jump, '技巧卡片');
  });
}

LearningMaterialsFeedRequest _request(LearningMaterialsItem item) {
  return LearningMaterialsFeedRequest(
    module: const HomeModule(id: 1, name: '学习资料', page: '学习资料', tag: ''),
    shelves: [LearningMaterialsShelf(id: 2, name: '资料', children: const [])],
    initialTabIndex: 0,
    clickedIndex: 0,
    snapshotItems: [item],
    appSnapshot: const LearningMaterialsAppSnapshot(
      isLoggedIn: true,
      ossDomain: '',
      categoryLabel: '初级',
      isTestEnvironment: false,
    ),
  );
}

final class _Source implements LearningMaterialsDataSource {
  @override
  Future<LearningMaterialsPage> loadPage({
    required int moduleId,
    required int shelfId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    return LearningMaterialsPage(
      total: 0,
      pages: 1,
      size: pageSize,
      current: pageNumber,
      records: const [],
    );
  }

  @override
  Future<List<LearningMaterialsShelf>> loadShelfTabs({
    required int moduleId,
  }) async => const [];

  @override
  Future<LearningMaterialsAppSnapshot> readSnapshot() async {
    return const LearningMaterialsAppSnapshot(
      isLoggedIn: true,
      ossDomain: '',
      categoryLabel: '初级',
      isTestEnvironment: false,
    );
  }
}
