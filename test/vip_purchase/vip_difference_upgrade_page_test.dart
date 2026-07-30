import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_difference_upgrade_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_difference_upgrade_page.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_difference_upgrade_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';

void main() {
  testWidgets('normal purchase fallback disables difference recursion', (
    tester,
  ) async {
    final pending = Completer<VipPurchaseResult?>();
    VipPurchaseRequest? fallbackRequest;
    final request = VipPurchaseRequest.source(source: VipPaymentSource.mine);
    final purchaseSource = _PurchaseSource();

    await tester.pumpWidget(
      MaterialApp(
        home: VipDifferenceUpgradePage(
          request: request,
          dataSource: _DifferenceSource(_differenceSession(request)),
          purchaseDataSource: purchaseSource,
          commodityOrderDataSource: purchaseSource,
          paymentGateway: _Gateway(),
          normalPurchaseLauncher: (_, value) {
            fallbackRequest = value;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fallbackRequest, isNotNull);
    expect(fallbackRequest!.allowDifferenceUpgrade, isFalse);
    expect(fallbackRequest!.normalPayPageSourceId, 1020);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(null);
    await tester.pump();
  });

  test('local difference calculation deducts every owned practice package', () {
    expect(
      calculateVipDifference(
        levelMemberPrice: 199,
        regularPrice: 29,
        speedPrice: 39,
        chapterPrice: 19,
        pastExamsPrice: 49,
        ownedBenefitTypes: const {
          'practice_skill',
          'practice_speed',
          'practice_chapter',
          'past_exams',
        },
      ),
      63,
    );
  });
}

VipDifferenceUpgradeSession _differenceSession(VipPurchaseRequest request) {
  return VipDifferenceUpgradeSession(
    purchaseSession: VipPurchaseSession(
      request: request,
      category: 'joy-ledger',
      level: '初级会计',
      subjects: const [VipSubject(id: 1, name: '会计实务')],
      initialSubjectIndex: 0,
      productTypes: const [VipProductType.skill],
      initialProductType: VipProductType.skill,
      isLoggedIn: true,
      showWechatPay: true,
      initialPaymentChannel: VipPaymentChannel.wechat,
      payPageSourceId: request.differencePayPageSourceId,
      nickname: '用户',
      avatarUrl: '',
      benefitLines: const [],
      isFullMember: true,
      hasPracticePackage: true,
    ),
    commodities: VipCommodityBundle(const [
      VipCommodity(
        commodityId: 'vip-all',
        name: '畅学卡',
        type: VipCommodityType.levelMember,
        price: 199,
        originalPrice: 199,
        description: '',
      ),
    ]),
    deduction: null,
    deductionRequestSucceeded: false,
  );
}

final class _DifferenceSource implements VipDifferenceUpgradeDataSource {
  const _DifferenceSource(this.session);
  final VipDifferenceUpgradeSession session;

  @override
  Future<VipDifferenceUpgradeSession> load(VipPurchaseRequest request) async {
    return session;
  }
}

final class _PurchaseSource
    implements VipPurchaseDataSource, VipCommodityOrderDataSource {
  @override
  Future<bool> confirmWechatPayment() async => true;

  @override
  Future<VipPaymentOrder> createCommodityOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required String commodityId,
  }) => throw UnimplementedError();

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) => throw UnimplementedError();

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) => throw UnimplementedError();

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) => throw UnimplementedError();
}

final class _Gateway implements VipPaymentGateway {
  @override
  Future<bool> isWechatInstalled() async => true;

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) {
    throw UnimplementedError();
  }

  @override
  Future<VipNativePaymentResult> payWechat(VipWechatCredential credential) {
    throw UnimplementedError();
  }
}
